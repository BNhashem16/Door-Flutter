/// Guest-pass domain types.
///
/// Stored under `/guest_passes/{ownerUid}/{passId}` in the Realtime Database,
/// where `passId == token`. Hand-written `fromMap`/`toMap` (no code-gen, per
/// project conventions). `createdByName` and `label` are denormalized so the
/// admin view and gate logs stay readable after a profile edit.
library;

/// Lifecycle of a pass. Redemption (the `usedCount` bump) happens server-side
/// in the redeem Worker; the app flips the status:
/// - `active`  — redeemable (subject to expiry / uses / schedule).
/// - `paused`  — temporarily disabled by the owner. The link stops working but
///   can be re-enabled (→ `active`) at any time. Reversible.
/// - `revoked` — permanently killed by the owner. Kept for audit, not resumed.
enum GuestPassStatus { active, paused, revoked }

/// Weekly recurrence window for a recurring pass (e.g. a regular cleaner).
///
/// A recurring pass only opens the gate when the redemption falls on one of
/// [weekdays] AND inside the `[startMinute, endMinute]` daily window. The
/// authoritative check runs in the redeem Worker (Africa/Cairo local time);
/// the Dart [GuestPass.openNow] mirror is best-effort for the owner's UI.
///
/// [weekdays] use `DateTime.weekday` numbering: 1 = Monday … 7 = Sunday.
/// [startMinute]/[endMinute] are minutes-from-midnight (e.g. 08:00 ⇒ 480).
class GuestSchedule {
  const GuestSchedule({
    required this.weekdays,
    required this.startMinute,
    required this.endMinute,
  });

  final List<int> weekdays;
  final int startMinute;
  final int endMinute;

  /// True if [when] (local) lands on an enabled weekday inside the window.
  /// Supports windows that wrap past midnight (start > end).
  bool isOpenAt(DateTime when) {
    if (!weekdays.contains(when.weekday)) return false;
    final minutes = when.hour * 60 + when.minute;
    if (startMinute <= endMinute) {
      return minutes >= startMinute && minutes <= endMinute;
    }
    return minutes >= startMinute || minutes <= endMinute;
  }

  factory GuestSchedule.fromMap(Map<dynamic, dynamic> map) {
    final raw = map['weekdays'];
    final days = raw is List
        ? raw.whereType<int>().toList()
        : (raw is Map ? raw.values.whereType<int>().toList() : const <int>[]);
    return GuestSchedule(
      weekdays: (days..sort()),
      startMinute: (map['startMinute'] ?? 0) as int,
      endMinute: (map['endMinute'] ?? 0) as int,
    );
  }

  Map<String, Object?> toMap() => {
        'weekdays': weekdays,
        'startMinute': startMinute,
        'endMinute': endMinute,
      };
}

/// Immutable temporary visitor access grant.
class GuestPass {
  const GuestPass({
    required this.token,
    required this.label,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    required this.expiresAt,
    required this.maxUses,
    required this.usedCount,
    required this.status,
    this.schedule,
  });

  /// Epoch ms sentinel for a permanent (no-time-limit) pass: 2100-01-01 UTC.
  /// Stored as [expiresAt] so the existing `now > expiresAt` checks (app +
  /// Worker) naturally treat it as never expiring — no special-casing needed in
  /// the validity path, only in display ([noExpiry]).
  static const int neverExpires = 4102444800000;

  /// Weekly recurrence window. Non-null ⇒ this is a recurring pass and
  /// [expiresAt] marks the date the recurrence stops repeating.
  final GuestSchedule? schedule;

  bool get recurring => schedule != null;

  /// Redeem token. Also the RTDB key (`passId == token`).
  final String token;

  /// Resident-set name for the visitor (e.g. «أخويا»).
  final String label;

  /// Owner uid that issued the pass.
  final String createdBy;

  /// Denormalized issuer display name at creation time.
  final String createdByName;

  /// Epoch ms the pass was created.
  final int createdAt;

  /// Epoch ms after which the pass no longer opens the gate.
  final int expiresAt;

  /// Allowed opens within the window. `0` ⇒ unlimited.
  final int maxUses;

  /// Opens consumed so far (server-incremented).
  final int usedCount;

  final GuestPassStatus status;

  /// Pass id == token.
  String get id => token;

  // --- Derived state (not stored) ---

  /// A permanent pass — no time limit. Only pause / revoke / uses gate it.
  bool get noExpiry => expiresAt >= neverExpires;

  bool get expired => DateTime.now().millisecondsSinceEpoch > expiresAt;

  bool get usedUp => maxUses > 0 && usedCount >= maxUses;

  bool get revoked => status == GuestPassStatus.revoked;

  /// Temporarily disabled by the owner — link dead until resumed. Reversible.
  bool get paused => status == GuestPassStatus.paused;

  /// For a recurring pass: whether the schedule window is open right now
  /// (best-effort, local device time). Always true for a one-shot pass.
  bool get openNow => schedule?.isOpenAt(DateTime.now()) ?? true;

  /// Currently redeemable. Mirrors `passIsValid` in the redeem Worker. A
  /// recurring pass additionally requires the schedule window to be open now.
  bool get valid =>
      status == GuestPassStatus.active && !expired && !usedUp && openNow;

  /// Still live and worth revoking — active or paused, not expired, not used up.
  /// Ignores the recurring window so the owner can revoke between windows.
  bool get revocable =>
      (status == GuestPassStatus.active || status == GuestPassStatus.paused) &&
      !expired &&
      !usedUp;

  /// Owner can pause it now — currently active and still live.
  bool get pausable =>
      status == GuestPassStatus.active && !expired && !usedUp;

  /// Owner can resume it — currently paused and still live.
  bool get resumable =>
      status == GuestPassStatus.paused && !expired && !usedUp;

  /// Remaining opens, or `null` for an unlimited pass.
  int? get usesLeft =>
      maxUses <= 0 ? null : (maxUses - usedCount).clamp(0, maxUses);

  factory GuestPass.fromMap(String id, Map<dynamic, dynamic> map) {
    return GuestPass(
      token: (map['token'] ?? id) as String,
      label: (map['label'] ?? '') as String,
      createdBy: (map['createdBy'] ?? '') as String,
      createdByName: (map['createdByName'] ?? '') as String,
      createdAt: (map['createdAt'] ?? 0) as int,
      expiresAt: (map['expiresAt'] ?? 0) as int,
      maxUses: (map['maxUses'] ?? 0) as int,
      usedCount: (map['usedCount'] ?? 0) as int,
      status: switch (map['status']) {
        'revoked' => GuestPassStatus.revoked,
        'paused' => GuestPassStatus.paused,
        _ => GuestPassStatus.active,
      },
      schedule: map['recurring'] == true && map['schedule'] is Map
          ? GuestSchedule.fromMap(map['schedule'] as Map)
          : null,
    );
  }

  Map<String, Object?> toMap() => {
        'token': token,
        'label': label,
        'createdBy': createdBy,
        'createdByName': createdByName,
        'createdAt': createdAt,
        'expiresAt': expiresAt,
        'maxUses': maxUses,
        'usedCount': usedCount,
        'status': switch (status) {
          GuestPassStatus.revoked => 'revoked',
          GuestPassStatus.paused => 'paused',
          GuestPassStatus.active => 'active',
        },
        // Recurrence is only written when present, keeping one-shot rows lean
        // and the `guest_passes` `.validate` rule unaffected.
        if (schedule != null) ...{
          'recurring': true,
          'schedule': schedule!.toMap(),
        },
      };
}
