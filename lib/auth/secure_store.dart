import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Minimal key/value secure storage boundary. Lets [BiometricService] be unit
/// tested with an in-memory fake instead of the platform Keychain.
abstract interface class SecureStore {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
  Future<void> delete(String key);
}

/// Production implementation backed by the OS secure store
/// (Keychain on iOS, EncryptedSharedPreferences on Android).
class FlutterSecureStore implements SecureStore {
  const FlutterSecureStore([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
