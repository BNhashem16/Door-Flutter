import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_store.dart';

/// Boundary over biometric auth + secure credential storage. Widgets talk to
/// this, never to the plugins directly (mirrors the AuthService convention).
class BiometricService {
  BiometricService({
    SecureStore store = const FlutterSecureStore(),
    LocalAuthentication? localAuth,
  })  : _store = store,
        _localAuth = localAuth ?? LocalAuthentication();

  final SecureStore _store;
  final LocalAuthentication _localAuth;

  /// How long the app may sit in the background before it re-locks on resume.
  static const lockTimeout = Duration(seconds: 60);

  static const _kEnabled = 'biometric_enabled';
  static const _kBackgroundedAt = 'biometric_backgrounded_at';
  static const _kEmail = 'biometric_email';
  static const _kPassword = 'biometric_password';

  // --- enabled flag (shared_preferences) ---

  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kEnabled) ?? false;
  }

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, value);
  }

  // --- background timeout logic ---

  /// Stamp the moment the app went to background. [now] is injectable for tests.
  Future<void> markBackgrounded([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _kBackgroundedAt,
      (now ?? DateTime.now()).millisecondsSinceEpoch,
    );
  }

  /// True if the app has been backgrounded longer than [lockTimeout].
  /// Returns false when there is no recorded background time.
  Future<bool> lockTimedOut([DateTime? now]) async {
    final prefs = await SharedPreferences.getInstance();
    final stamp = prefs.getInt(_kBackgroundedAt);
    if (stamp == null) return false;
    final elapsed = (now ?? DateTime.now()).millisecondsSinceEpoch - stamp;
    return elapsed > lockTimeout.inMilliseconds;
  }

  // --- credential round-trip (secure storage only) ---

  Future<void> saveCredentials(String email, String password) async {
    await _store.write(_kEmail, email);
    await _store.write(_kPassword, password);
  }

  Future<({String email, String password})?> readCredentials() async {
    final email = await _store.read(_kEmail);
    final password = await _store.read(_kPassword);
    if (email == null || password == null) return null;
    return (email: email, password: password);
  }

  Future<void> clearCredentials() async {
    await _store.delete(_kEmail);
    await _store.delete(_kPassword);
  }

  // --- biometric prompt pass-throughs (plugin boundary) ---

  /// Device has biometric hardware AND at least one fingerprint/face enrolled.
  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;
      return supported && canCheck;
    } on Exception {
      return false;
    }
  }

  /// Shows the OS biometric prompt. Returns true only on a successful scan.
  Future<bool> authenticate(String reason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on Exception {
      return false;
    }
  }
}
