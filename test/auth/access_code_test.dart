import 'package:flutter_test/flutter_test.dart';
import 'package:Door/auth/auth_service.dart';

void main() {
  group('generateAccessCode', () {
    test('produces 8 base32 [a-z2-7] chars', () {
      for (var i = 0; i < 50; i++) {
        final code = AuthService.generateAccessCode();
        expect(code, matches(RegExp(r'^[a-z2-7]{8}$')));
      }
    });

    test('is not constant across calls', () {
      final a = AuthService.generateAccessCode();
      final b = AuthService.generateAccessCode();
      expect(a == b, isFalse);
    });
  });

  group('parseAccessResult', () {
    test('ok=true → ok', () {
      expect(AuthService.parseAccessResult({'ok': true}), AccessRedeemResult.ok);
    });
    test('maps each error string', () {
      expect(AuthService.parseAccessResult({'error': 'expired'}),
          AccessRedeemResult.expired);
      expect(AuthService.parseAccessResult({'error': 'used'}),
          AccessRedeemResult.used);
      expect(AuthService.parseAccessResult({'error': 'not_pending'}),
          AccessRedeemResult.notPending);
      expect(AuthService.parseAccessResult({'error': 'invalid'}),
          AccessRedeemResult.invalid);
    });
    test('unknown error → invalid', () {
      expect(AuthService.parseAccessResult({'error': 'weird'}),
          AccessRedeemResult.invalid);
      expect(AuthService.parseAccessResult({}), AccessRedeemResult.invalid);
    });
  });
}
