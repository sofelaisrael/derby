import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the user has completed onboarding.
class OnboardingStore {
  static const _keyComplete = 'onboarding_complete';

  Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyComplete) ?? false;
  }

  Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyComplete, true);
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyComplete);
  }
}
