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

  group('GuestSchedule', () {
    // Monday 2024-01-01 09:30 local — a fixed reference inside an 08:00–12:00
    // window on weekday 1 (Monday).
    final monday0930 = DateTime(2024, 1, 1, 9, 30);

    test('open inside weekday + window', () {
      const sch =
          GuestSchedule(weekdays: [1], startMinute: 480, endMinute: 720);
      expect(sch.isOpenAt(monday0930), isTrue);
    });

    test('closed when weekday not enabled', () {
      const sch =
          GuestSchedule(weekdays: [2, 3], startMinute: 480, endMinute: 720);
      expect(sch.isOpenAt(monday0930), isFalse);
    });

    test('closed outside the daily window', () {
      const sch =
          GuestSchedule(weekdays: [1], startMinute: 600, endMinute: 720);
      expect(sch.isOpenAt(monday0930), isFalse); // 09:30 < 10:00
    });

    test('window wrapping past midnight', () {
      const sch =
          GuestSchedule(weekdays: [1], startMinute: 1320, endMinute: 120);
      expect(sch.isOpenAt(DateTime(2024, 1, 1, 23, 30)), isTrue); // 23:30
      expect(sch.isOpenAt(DateTime(2024, 1, 1, 1, 0)), isTrue); // 01:00
      expect(sch.isOpenAt(monday0930), isFalse); // 09:30 outside
    });
  });

  group('recurring pass', () {
    final future = DateTime.now().millisecondsSinceEpoch + 86400000;

    GuestPass recurring({required bool openNow}) {
      final now = DateTime.now();
      final minutes = now.hour * 60 + now.minute;
      // Build a window that either contains or excludes the current minute,
      // on today's weekday, so `valid` flips on `openNow`.
      final schedule = openNow
          ? GuestSchedule(
              weekdays: [now.weekday],
              startMinute: (minutes - 30).clamp(0, 1439),
              endMinute: (minutes + 30).clamp(0, 1439),
            )
          : GuestSchedule(
              weekdays: [now.weekday == 7 ? 1 : now.weekday + 1],
              startMinute: 0,
              endMinute: 1,
            );
      return GuestPass(
        token: 'rec23abcd4',
        label: 'cleaner',
        createdBy: 'owner1',
        createdByName: 'محمد',
        createdAt: now.millisecondsSinceEpoch,
        expiresAt: future,
        maxUses: 0,
        usedCount: 0,
        status: GuestPassStatus.active,
        schedule: schedule,
      );
    }

    test('schedule round-trips through toMap/fromMap', () {
      final p = recurring(openNow: true);
      final restored = GuestPass.fromMap(p.token, p.toMap());
      expect(restored.recurring, isTrue);
      expect(restored.schedule!.weekdays, p.schedule!.weekdays);
      expect(restored.schedule!.startMinute, p.schedule!.startMinute);
      expect(restored.schedule!.endMinute, p.schedule!.endMinute);
    });

    test('valid only while the window is open; revocable regardless', () {
      final open = recurring(openNow: true);
      final closed = recurring(openNow: false);
      expect(open.valid, isTrue);
      expect(closed.valid, isFalse); // window shut → not redeemable now
      expect(closed.revocable, isTrue); // still owner-revocable
    });

    test('one-shot pass has no schedule and openNow is always true', () {
      final p = build(expiresAt: future);
      expect(p.recurring, isFalse);
      expect(p.openNow, isTrue);
      expect(p.toMap().containsKey('recurring'), isFalse);
    });
  });
}
