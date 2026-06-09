/// Gate access log domain types.
///
/// Stored under `/gate_logs/{uid}/{logId}` in the Realtime Database. Hand-written
/// `fromMap`/`toMap` (no code-gen, per project conventions). The `name` is
/// denormalized so a log row still shows who acted even after the profile is
/// edited or deleted.
library;

/// What happened to the gate.
enum GateAction { open, close }

/// Where the action was triggered from.
enum GateSource { app, widget }

/// Immutable record of a single gate open/close action.
class GateLog {
  const GateLog({
    required this.id,
    required this.uid,
    required this.name,
    required this.action,
    required this.source,
    required this.timestamp,
  });

  /// RTDB push key.
  final String id;
  final String uid;

  /// Denormalized display name of the actor at the time of the action.
  final String name;
  final GateAction action;
  final GateSource source;

  /// Epoch milliseconds. Server-stamped on the in-app path, device clock on the
  /// headless widget path.
  final int timestamp;

  factory GateLog.fromMap(String id, String uid, Map<dynamic, dynamic> map) {
    return GateLog(
      id: id,
      uid: uid,
      name: (map['name'] ?? '') as String,
      action: map['action'] == 'open' ? GateAction.open : GateAction.close,
      source: map['source'] == 'widget' ? GateSource.widget : GateSource.app,
      timestamp: (map['timestamp'] ?? 0) as int,
    );
  }

  Map<String, Object?> toMap() => {
        'name': name,
        'action': action == GateAction.open ? 'open' : 'close',
        'source': source == GateSource.widget ? 'widget' : 'app',
        'timestamp': timestamp,
      };
}
