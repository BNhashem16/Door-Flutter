import 'package:Door/notifications/app_notification.dart';
import 'package:Door/gate/ring_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppNotification.fromMap', () {
    test('reads fields and read flag', () {
      final n = AppNotification.fromMap('n1', {
        'type': 'broadcast',
        'title': 'صيانة',
        'body': 'غدًا',
        'createdAt': 1700000000000,
        'read': true,
      });
      expect(n.id, 'n1');
      expect(n.type, 'broadcast');
      expect(n.title, 'صيانة');
      expect(n.body, 'غدًا');
      expect(n.createdAt, 1700000000000);
      expect(n.read, true);
      expect(n.icon, Icons.campaign_rounded);
    });

    test('defaults: type=info, read=false, unknown type → bell icon', () {
      final n = AppNotification.fromMap('n2', {'title': 'x'});
      expect(n.type, 'info');
      expect(n.read, false);
      expect(n.body, '');
      expect(n.icon, Icons.notifications_rounded);
    });
  });

  group('RingRequest.fromMap', () {
    test('pending request', () {
      final r = RingRequest.fromMap({'status': 'pending', 'createdAt': 123});
      expect(r.isPending, true);
      expect(r.createdAt, 123);
    });

    test('opened request is not pending', () {
      final r = RingRequest.fromMap({'status': 'opened', 'createdAt': 1});
      expect(r.isPending, false);
    });
  });
}
