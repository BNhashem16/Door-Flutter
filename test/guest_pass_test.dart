import 'package:flutter_test/flutter_test.dart';
import 'package:Door/guest/guest_pass.dart';

void main() {
  GuestPass build({
    int? expiresAt,
    int maxUses = 1,
    int usedCount = 0,
    GuestPassStatus status = GuestPassStatus.active,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return GuestPass(
      token: 'abc23xyz45',
      label: 'أخويا',
      createdBy: 'owner1',
      createdByName: 'محمد',
      createdAt: now,
      expiresAt: expiresAt ?? now + const Duration(hours: 1).inMilliseconds,
      maxUses: maxUses,
      usedCount: usedCount,
      status: status,
    );
  }

  group('GuestPass map round-trip', () {
    test('toMap/fromMap preserves all fields', () {
      final pass = build(maxUses: 5, usedCount: 2);
      final restored = GuestPass.fromMap(pass.token, pass.toMap());

      expect(restored.token, pass.token);
      expect(restored.label, 'أخويا');
      expect(restored.createdBy, 'owner1');
      expect(restored.createdByName, 'محمد');
      expect(restored.createdAt, pass.createdAt);
      expect(restored.expiresAt, pass.expiresAt);
      expect(restored.maxUses, 5);
      expect(restored.usedCount, 2);
      expect(restored.status, GuestPassStatus.active);
    });

    test('id equals token', () {
      expect(build().id, 'abc23xyz45');
    });

    test('fromMap falls back to id when token field absent', () {
      final p = GuestPass.fromMap('tok99', const {
        'label': 'x',
        'createdBy': 'o',
        'expiresAt': 1,
        'status': 'active',
      });
      expect(p.token, 'tok99');
    });

    test('toMap encodes revoked status', () {
      expect(
        build(status: GuestPassStatus.revoked).toMap()['status'],
        'revoked',
      );
    });
  });

  group('derived state', () {
    final future = DateTime.now().millisecondsSinceEpoch + 3600000;
    final past = DateTime.now().millisecondsSinceEpoch - 1000;

    test('active, unexpired, unused → valid', () {
      expect(build(expiresAt: future).valid, isTrue);
    });

    test('expired window → not valid', () {
      final p = build(expiresAt: past);
      expect(p.expired, isTrue);
      expect(p.valid, isFalse);
    });

    test('used up → not valid', () {
      final p = build(expiresAt: future, maxUses: 1, usedCount: 1);
      expect(p.usedUp, isTrue);
      expect(p.valid, isFalse);
    });

    test('revoked → not valid', () {
      final p = build(expiresAt: future, status: GuestPassStatus.revoked);
      expect(p.revoked, isTrue);
      expect(p.valid, isFalse);
    });

    test('unlimited pass ignores usedCount', () {
      final p = build(expiresAt: future, maxUses: 0, usedCount: 50);
      expect(p.usedUp, isFalse);
      expect(p.valid, isTrue);
      expect(p.usesLeft, isNull);
    });

    test('usesLeft reports the remainder, never negative', () {
      expect(build(maxUses: 5, usedCount: 2).usesLeft, 3);
      expect(build(maxUses: 1, usedCount: 9).usesLeft, 0);
    });
  });
}
