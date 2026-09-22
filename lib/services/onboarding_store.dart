import 'package:shared_preferences/shared_preferences.dart';

/// Persists whether the user has seen the first-launch onboarding screen
/// (welcome + notification permission prompt). Shown once per install.
class OnboardingStore {
  static const _keyHasSeen = 'onboardingHasSeen';

  static Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyHasSeen) ?? false;
  }

  static Future<void> setSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeen, true);
  }
}
