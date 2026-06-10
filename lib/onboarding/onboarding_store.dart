import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the first-launch walkthrough has been shown.
class OnboardingStore {
  static const _key = 'onboarding_seen';

  /// True once the user has finished or skipped onboarding.
  static Future<bool> seen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}
