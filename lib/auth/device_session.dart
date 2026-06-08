import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Provides a stable per-install device identifier, persisted locally.
/// Used to enforce single-device login per account.
abstract final class DeviceSession {
  static const String _key = 'device_id';
  static String? _cached;

  /// Returns the persistent device id, generating one on first call.
  static Future<String> id() async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var value = prefs.getString(_key);
    if (value == null || value.isEmpty) {
      value = _generate();
      await prefs.setString(_key, value);
    }
    _cached = value;
    return value;
  }

  static String _generate() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
