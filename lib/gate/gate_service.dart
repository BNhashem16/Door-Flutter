import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

/// Live gate snapshot: open/closed plus the device's last heartbeat.
///
/// The physical controller writes [lastSeenMs] (epoch ms) to
/// `devices/D/lastSeen` every ~30s. A stale/absent value means the device is
/// unreachable even though the app is still connected to the database.
class GateStatus {
  const GateStatus({required this.open, required this.lastSeenMs});

  /// `true` = gate open (state == ON).
  final bool open;

  /// Epoch ms of the controller's most recent heartbeat, or null if it has
  /// never written one.
  final int? lastSeenMs;
}

/// Single source of truth for gate state read/toggle.
///
/// Two transports, one contract:
/// - In-app UI uses the **Realtime Database SDK** (`watchStatus` / `setOpen`)
///   so the screen stays continuously in sync with the database — no polling.
/// - The home-screen widget background callback runs headless (no
///   `Firebase.initializeApp`, no signed-in user) so it falls back to the
///   **REST** endpoint with the embedded device token (`fetchState` /
///   `toggle`).
class GateService {
  GateService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// RTDB instance host shared with [AuthService].
  static const String _databaseUrl = 'https://microiot.firebaseio.com';

  /// Path to the gate device node inside the Realtime Database.
  static const String _gatePath =
      'users/1BEy97EhEObAeP7U6s4CFM66IPr2/devices/D';

  /// Firebase RTDB REST endpoint for the gate device. Token is embedded
  /// (intentional config, used only by the headless widget callback).
  static const String _url =
      '$_databaseUrl/$_gatePath.json?auth=VSV5R6QkmXOT12rrR6fuawILTpJdM8GjUQhiyShM';

  static const Duration _timeout = Duration(seconds: 10);

  DatabaseReference _gateRef() => FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: _databaseUrl,
      ).ref(_gatePath);

  /// Maps a raw gate node value to open/closed. `true` = open (state == ON).
  static bool _isOpen(Object? data) =>
      data is Map && data['state'] != null && data['state'] == 'ON';

  /// Extracts the controller heartbeat (epoch ms) from the gate node, or null
  /// if absent / malformed. Tolerates int or num encodings.
  static int? _lastSeen(Object? data) {
    if (data is! Map) return null;
    final raw = data['lastSeen'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return null;
  }

  /// Live gate status (open state + device heartbeat) from the Realtime
  /// Database. Emits on every change so the UI mirrors the database instantly.
  /// Errors propagate so callers can show a disconnected state. Requires a
  /// signed-in user (security rules).
  Stream<GateStatus> watchStatus() {
    final ref = _gateRef();
    // Keep the node warm so it emits from cache immediately on next launch.
    unawaited(ref.keepSynced(true));
    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      return GateStatus(open: _isOpen(value), lastSeenMs: _lastSeen(value));
    });
  }

  /// Writes the gate state via the SDK and returns [open]. Throws on failure.
  Future<bool> setOpen(bool open) async {
    await _gateRef().update({
      'apikey': 'D',
      'changedby': 'ahmed hashem',
      'state': open ? 'ON' : 'OFF',
      'name': 'Door',
      'timestamp': ServerValue.timestamp,
      'type': 'Motor',
    });
    return open;
  }

  /// Reads current gate state. `true` = open (ON), `false` = closed (OFF).
  /// Throws on network / non-200 so callers can surface a disconnected state.
  Future<bool> fetchState() async {
    final response = await _client.get(Uri.parse(_url)).timeout(_timeout);
    if (response.statusCode != 200) {
      throw http.ClientException(
          'status ${response.statusCode}', Uri.parse(_url));
    }
    return _isOpen(jsonDecode(response.body));
  }

  /// Flips the gate. Sends the opposite of [currentOpen] and returns the
  /// new state on success. Throws on network / non-200.
  Future<bool> toggle({required bool currentOpen}) async {
    final newOpen = !currentOpen;
    final response = await _client
        .put(
          Uri.parse(_url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'apikey': 'D',
            'changedby': 'ahmed hashem',
            'state': newOpen ? 'ON' : 'OFF',
            'name': 'Door',
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'type': 'Motor',
          }),
        )
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw http.ClientException(
          'status ${response.statusCode}', Uri.parse(_url));
    }
    return newOpen;
  }

  /// Best-effort REST push of a gate access log for the headless widget path
  /// (no Firebase Auth/SDK available there). Writes to `/gate_logs/{uid}` with
  /// the embedded device token, which bypasses the security rules. Never throws
  /// — a failed log must not break the gate toggle.
  Future<void> logAction({
    required String uid,
    required String name,
    required bool open,
  }) async {
    if (uid.isEmpty) return;
    final url = '$_databaseUrl/gate_logs/$uid.json'
        '?auth=VSV5R6QkmXOT12rrR6fuawILTpJdM8GjUQhiyShM';
    try {
      await _client
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'action': open ? 'open' : 'close',
              'source': 'widget',
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            }),
          )
          .timeout(_timeout);
    } catch (_) {
      // Best-effort: swallow logging failures.
    }
  }

  void dispose() => _client.close();
}
