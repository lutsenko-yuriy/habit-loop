import 'package:habit_loop/infrastructure/onboarding/contracts/onboarding_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Production [OnboardingPreferenceService] backed by [SharedPreferences].
///
/// Stores the onboarding-passed flag as a boolean under [_key].
///
/// Reading ([isOnboardingPassed]) is synchronous — [SharedPreferences] holds
/// its values in memory after the first [SharedPreferences.getInstance] call,
/// so [getBool] is a pure in-memory lookup with no I/O.
///
/// Writing ([markOnboardingPassed]) is fire-and-forget async — the in-memory
/// value is updated immediately and persisted to disk in the background.
///
/// **No-throw contract:** all methods swallow exceptions internally so that a
/// SharedPreferences failure can never crash the app.
final class SharedPreferencesOnboardingService implements OnboardingPreferenceService {
  /// The [SharedPreferences] instance injected at construction time.
  ///
  /// Accepting a pre-constructed instance (rather than calling
  /// [SharedPreferences.getInstance] inside each method) makes the class
  /// testable with [SharedPreferences.setMockInitialValues] and reuses the
  /// already-loaded instance from `main.dart`.
  final SharedPreferences _prefs;

  /// The key used to store the onboarding-passed flag.
  static const String _key = 'habit_loop_onboarding_passed';

  const SharedPreferencesOnboardingService(this._prefs);

  @override
  bool get isOnboardingPassed => _prefs.getBool(_key) ?? false;

  @override
  Future<void> markOnboardingPassed() async {
    try {
      await _prefs.setBool(_key, true);
    } catch (_) {}
  }
}
