import 'package:habit_loop/infrastructure/onboarding/contracts/onboarding_preference_service.dart';

/// No-op [OnboardingPreferenceService] used as the default provider value.
///
/// Always reports onboarding as not passed ([isOnboardingPassed] = `false`).
/// [markOnboardingPassed] is a silent no-op.
///
/// Used automatically whenever [onboardingPreferenceServiceProvider] is not
/// overridden — i.e. in unit tests and any environment where SharedPreferences
/// is not available.
final class NoopOnboardingService implements OnboardingPreferenceService {
  const NoopOnboardingService();

  @override
  bool get isOnboardingPassed => false;

  @override
  Future<void> markOnboardingPassed() async {}
}
