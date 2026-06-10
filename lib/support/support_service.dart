import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'support_ticket.dart';

/// Realtime Database wrapper for support tickets under
/// `/support_tickets/{ownerUid}/{ticketId}`.
///
/// A focused service in the **GateService**/**GuestService** spirit (a
/// dedicated wrapper, not `AuthService` bloat). A resident creates and watches
/// their own tickets; an admin watches every ticket and flips the status to
/// resolved. The security rules (`database.rules.json`) enforce owner-or-admin
/// access, mirroring the `gate_logs` node.
class SupportService {
  SupportService({FirebaseDatabase? db})
      : _db = db ??
            FirebaseDatabase.instanceFor(
              app: Firebase.app(),
              databaseURL: _databaseUrl,
            );

  final FirebaseDatabase _db;

  static const String _databaseUrl = 'https://microiot.firebaseio.com';

  DatabaseReference _ownerRef(String uid) => _db.ref('support_tickets/$uid');

  /// Resident: open a new ticket. Server-stamps the time.
  Future<void> submit({
    required String uid,
    required String name,
    required String email,
    required TicketCategory category,
    required String message,
  }) {
    return _ownerRef(uid).push().set({
      'name': name.trim(),
      'email': email.trim(),
      'category': switch (category) {
        TicketCategory.bug => 'bug',
        TicketCategory.suggestion => 'suggestion',
        TicketCategory.other => 'other',
      },
      'message': message.trim(),
      'createdAt': ServerValue.timestamp,
      'status': 'open',
    });
  }

  /// Admin: flip a ticket's status. Kept as an update so the row stays auditable.
  Future<void> setStatus(String uid, String ticketId, TicketStatus status) {
    return _ownerRef(uid).child(ticketId).update({
      'status': status == TicketStatus.resolved ? 'resolved' : 'open',
    });
  }

  /// Admin: live stream of every ticket across all users, newest first.
  Stream<List<SupportTicket>> watchAll() {
    return _db.ref('support_tickets').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return <SupportTicket>[];
      final tickets = <SupportTicket>[];
      for (final userEntry in value.entries) {
        final uid = userEntry.key as String;
        final userTickets = userEntry.value;
        if (userTickets is! Map) continue;
        for (final t in userTickets.entries) {
          if (t.value is Map) {
            tickets.add(
                SupportTicket.fromMap(t.key as String, uid, t.value as Map));
          }
        }
      }
      tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tickets;
    });
  }
}
