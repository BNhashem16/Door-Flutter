import 'package:flutter_test/flutter_test.dart';
import 'package:Door/guest/guest_redemption.dart';

void main() {
  group('GuestRedemption', () {
    test('fromMap reads at', () {
      final r = GuestRedemption.fromMap('push1', const {'at': 1700000000000});
      expect(r.id, 'push1');
      expect(r.at, 1700000000000);
    });

    test('fromMap defaults at to 0 when missing', () {
      final r = GuestRedemption.fromMap('push2', const {});
      expect(r.at, 0);
    });

    test('toMap round-trips at', () {
      const r = GuestRedemption(id: 'push3', at: 42);
      expect(r.toMap(), {'at': 42});
    });
  });
}
