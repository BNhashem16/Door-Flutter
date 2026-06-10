/// Immutable record of an admin action, stored under `/audit_logs/{entryId}`.
///
/// Written by [AuthService.recordAudit] whenever an admin approves, rejects,
/// edits, promotes, deletes a user, or resolves a support ticket. Admin-only
/// read/write per `database.rules.json`. Names are denormalized so the entry
/// still renders after the target user is deleted.
class AuditLog {
  const AuditLog({
    required this.id,
    required this.actorUid,
    required this.actorName,
    required this.action,
    required this.targetUid,
    required this.targetName,
    required this.timestamp,
  });

  final String id;
  final String actorUid;
  final String actorName;

  /// Stable action key (e.g. `approve`, `reject`, `edit_user`). Localized in the
  /// UI via [AppStrings] — never store user-facing text here.
  final String action;
  final String targetUid;
  final String targetName;
  final int timestamp;

  factory AuditLog.fromMap(String id, Map<dynamic, dynamic> map) {
    return AuditLog(
      id: id,
      actorUid: (map['actorUid'] ?? '') as String,
      actorName: (map['actorName'] ?? '') as String,
      action: (map['action'] ?? '') as String,
      targetUid: (map['targetUid'] ?? '') as String,
      targetName: (map['targetName'] ?? '') as String,
      timestamp: (map['timestamp'] ?? 0) as int,
    );
  }
}
