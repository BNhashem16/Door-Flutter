import 'package:flutter_test/flutter_test.dart';
import 'package:Door/support/support_ticket.dart';

void main() {
  group('SupportTicket map round-trip', () {
    test('toMap/fromMap preserves all fields', () {
      const ticket = SupportTicket(
        id: 't1',
        uid: 'owner1',
        name: 'محمد',
        email: 'm@example.com',
        category: TicketCategory.bug,
        message: 'البوابة لا تفتح',
        createdAt: 1700000000000,
        status: TicketStatus.open,
      );
      final restored =
          SupportTicket.fromMap(ticket.id, ticket.uid, ticket.toMap());

      expect(restored.name, 'محمد');
      expect(restored.email, 'm@example.com');
      expect(restored.category, TicketCategory.bug);
      expect(restored.message, 'البوابة لا تفتح');
      expect(restored.createdAt, 1700000000000);
      expect(restored.status, TicketStatus.open);
      expect(restored.isOpen, isTrue);
    });

    test('encodes each category and status', () {
      String cat(TicketCategory c) => SupportTicket(
            id: 'i',
            uid: 'u',
            name: 'n',
            email: 'e',
            category: c,
            message: 'm',
            createdAt: 1,
            status: TicketStatus.resolved,
          ).toMap()['category'] as String;

      expect(cat(TicketCategory.bug), 'bug');
      expect(cat(TicketCategory.suggestion), 'suggestion');
      expect(cat(TicketCategory.other), 'other');
    });

    test('fromMap defaults unknown category to other and missing status to open',
        () {
      final t = SupportTicket.fromMap('i', 'u', const {
        'message': 'hi',
        'createdAt': 5,
      });
      expect(t.category, TicketCategory.other);
      expect(t.status, TicketStatus.open);
    });

    test('resolved status round-trips', () {
      final t = SupportTicket.fromMap('i', 'u', const {
        'message': 'hi',
        'createdAt': 5,
        'status': 'resolved',
      });
      expect(t.status, TicketStatus.resolved);
      expect(t.isOpen, isFalse);
    });
  });
}
