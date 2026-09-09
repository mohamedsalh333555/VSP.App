import 'package:shared_preferences/shared_preferences.dart';

/// Manages local persistence of user onboarding completion flag.
class AuthOnboardingCoordinator {
  const AuthOnboardingCoordinator._();

  /// Loads onboarding status from SharedPreferences.
  static Future<bool> loadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_completed_onboarding') ?? false;
  }

  /// Marks onboarding completed in local storage.
  static Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
  }
}
