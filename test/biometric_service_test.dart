import 'package:Door/auth/biometric_service.dart';
import 'package:Door/auth/secure_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory SecureStore for tests.
class FakeSecureStore implements SecureStore {
  final Map<String, String> _data = {};
  @override
  Future<void> write(String key, String value) async => _data[key] = value;
  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> delete(String key) async => _data.remove(key);
}

BiometricService _build() => BiometricService(
      store: FakeSecureStore(),
      localAuth: LocalAuthentication(),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('enabled flag', () {
    test('defaults to false', () async {
      expect(await _build().isEnabled(), isFalse);
    });

    test('persists after setEnabled(true)', () async {
      final svc = _build();
      await svc.setEnabled(true);
      expect(await svc.isEnabled(), isTrue);
    });

    test('setEnabled(false) clears it', () async {
      final svc = _build();
      await svc.setEnabled(true);
      await svc.setEnabled(false);
      expect(await svc.isEnabled(), isFalse);
    });
  });

  group('lock timeout', () {
    test('not timed out when never backgrounded', () async {
      expect(await _build().lockTimedOut(), isFalse);
    });

    test('not timed out at 59s', () async {
      final svc = _build();
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      await svc.markBackgrounded(t0);
      final at59 = t0.add(const Duration(seconds: 59));
      expect(await svc.lockTimedOut(at59), isFalse);
    });

    test('timed out at 61s', () async {
      final svc = _build();
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      await svc.markBackgrounded(t0);
      final at61 = t0.add(const Duration(seconds: 61));
      expect(await svc.lockTimedOut(at61), isTrue);
    });
  });

  group('credentials', () {
    test('readCredentials is null before saving', () async {
      expect(await _build().readCredentials(), isNull);
    });

    test('round-trips email and password', () async {
      final svc = _build();
      await svc.saveCredentials('a@b.com', 'secret123');
      final creds = await svc.readCredentials();
      expect(creds?.email, 'a@b.com');
      expect(creds?.password, 'secret123');
    });

    test('clearCredentials removes them', () async {
      final svc = _build();
      await svc.saveCredentials('a@b.com', 'secret123');
      await svc.clearCredentials();
      expect(await svc.readCredentials(), isNull);
    });
  });
}
