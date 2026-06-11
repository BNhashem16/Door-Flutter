import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

/// A doorbell ring request at `/ring_request` (single latest node). Written by
/// the Cloudflare Worker when a visitor taps the gate QR's `/ring` page.
class RingRequest {
  const RingRequest({required this.status, required this.createdAt});

  final String status; // 'pending' | 'opened'
  final int createdAt;

  bool get isPending => status == 'pending';

  factory RingRequest.fromMap(Map<dynamic, dynamic> map) => RingRequest(
        status: (map['status'] ?? '') as String,
        createdAt: (map['createdAt'] ?? 0) as int,
      );
}

/// Realtime Database wrapper for the doorbell ring node. Approved residents
/// read it live and mark it `opened` after letting the visitor in.
class RingService {
  RingService({FirebaseDatabase? db})
      : _db = db ??
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: _databaseUrl,
            );

  final FirebaseDatabase _db;

  static const String _databaseUrl = 'https://microiot.firebaseio.com';

  DatabaseReference _ref() => _db.ref('ring_request');

  /// Live ring state (null when no request exists yet).
  Stream<RingRequest?> watch() {
    return _ref().onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return null;
      return RingRequest.fromMap(value);
    });
  }

  /// Mark the current ring handled (resident opened the gate for the visitor).
  Future<void> markOpened() => _ref().update({'status': 'opened'});
}
