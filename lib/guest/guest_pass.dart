/// Guest-pass domain types.
///
/// Stored under `/guest_passes/{ownerUid}/{passId}` in the Realtime Database,
/// where `passId == token`. Hand-written `fromMap`/`toMap` (no code-gen, per
/// project conventions). `createdByName` and `label` are denormalized so the
/// admin view and gate logs stay readable after a profile edit.
library;

/// Lifecycle of a pass. Redemption (the `usedCount` bump) happens server-side
/// in the `guestPass` Cloud Function; the app only flips `active` → `revoked`.
enum GuestPassStatus { active, revoked }

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
  });

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

  bool get expired => DateTime.now().millisecondsSinceEpoch > expiresAt;

  bool get usedUp => maxUses > 0 && usedCount >= maxUses;

  bool get revoked => status == GuestPassStatus.revoked;

  /// Currently redeemable. Mirrors `passIsValid` in the Cloud Function.
  bool get valid => status == GuestPassStatus.active && !expired && !usedUp;

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
      status: map['status'] == 'revoked'
          ? GuestPassStatus.revoked
          : GuestPassStatus.active,
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
        'status': status == GuestPassStatus.revoked ? 'revoked' : 'active',
      };
}
