import 'package:Door/admin/audit_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuditLog.fromMap', () {
    test('reads all fields', () {
      final log = AuditLog.fromMap('e1', {
        'actorUid': 'admin-1',
        'actorName': 'Ahmed',
        'action': 'approve',
        'targetUid': 'user-9',
        'targetName': 'Mohamed',
        'timestamp': 1700000000000,
      });

      expect(log.id, 'e1');
      expect(log.actorUid, 'admin-1');
      expect(log.actorName, 'Ahmed');
      expect(log.action, 'approve');
      expect(log.targetUid, 'user-9');
      expect(log.targetName, 'Mohamed');
      expect(log.timestamp, 1700000000000);
    });

    test('defaults missing fields to empty / zero', () {
      final log = AuditLog.fromMap('e2', {'action': 'delete_user'});

      expect(log.action, 'delete_user');
      expect(log.actorUid, '');
      expect(log.actorName, '');
      expect(log.targetUid, '');
      expect(log.targetName, '');
      expect(log.timestamp, 0);
    });
  });
}
