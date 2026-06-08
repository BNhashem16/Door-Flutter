import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's chosen app language and resolves the initial locale.
class LocaleStore {
  static const _key = 'app_locale';
  static const _supported = {'ar', 'en'};

  /// Returns the saved locale, or — on first launch — the device locale if it
  /// is Arabic or English, otherwise Arabic (the app's default).
  static Future<Locale> initial() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && _supported.contains(saved)) {
      return Locale(saved);
    }
    final device = PlatformDispatcher.instance.locale.languageCode;
    return Locale(device == 'en' ? 'en' : 'ar');
  }

  static Future<void> save(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, locale.languageCode);
  }
}
