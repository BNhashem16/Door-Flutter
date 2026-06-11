import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'app_notification.dart';

/// Realtime Database wrapper for the in-app notification center under
/// `/notifications/{uid}/{id}`.
///
/// A dedicated service in the **GateService**/**GuestService**/**SupportService**
/// spirit. Entries are *written* by the Cloudflare Worker (service-account);
/// the owner only reads them and flips `read` / clears. Owner-or-admin access
/// per `database.rules.json`.
class NotificationService {
  NotificationService({FirebaseDatabase? db})
      : _db = db ??
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: _databaseUrl,
            );

  final FirebaseDatabase _db;

  static const String _databaseUrl = 'https://microiot.firebaseio.com';

  DatabaseReference _ref(String uid) => _db.ref('notifications/$uid');

  /// Live list of a user's notifications, newest first.
  Stream<List<AppNotification>> watch(String uid) {
    return _ref(uid).onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return <AppNotification>[];
      return value.entries
          .where((e) => e.value is Map)
          .map((e) => AppNotification.fromMap(e.key as String, e.value as Map))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  /// Mark a single notification read.
  Future<void> markRead(String uid, String id) =>
      _ref(uid).child(id).update({'read': true});

  /// Mark every currently-unread notification read in one multi-path update.
  Future<void> markAllRead(String uid, List<AppNotification> current) {
    final updates = <String, Object?>{};
    for (final n in current) {
      if (!n.read) updates['${n.id}/read'] = true;
    }
    if (updates.isEmpty) return Future<void>.value();
    return _ref(uid).update(updates);
  }

  /// Delete all notifications for a user.
  Future<void> clearAll(String uid) => _ref(uid).remove();
}
