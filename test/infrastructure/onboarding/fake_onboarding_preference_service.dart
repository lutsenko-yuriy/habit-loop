import 'package:habit_loop/infrastructure/onboarding/contracts/onboarding_preference_service.dart';

/// In-memory [OnboardingPreferenceService] for tests.
///
/// Starts with [isOnboardingPassed] equal to [initialValue] (default `false`).
/// [markOnboardingPassed] flips [isOnboardingPassed] to `true` and increments
/// [markCalledCount] so tests can assert it was called exactly once.
final class FakeOnboardingPreferenceService implements OnboardingPreferenceService {
  bool _passed;
  bool _nameEntryShown;

  /// How many times [markOnboardingPassed] has been called.
  int markCalledCount = 0;

  /// How many times [markNameEntryShown] has been called.
  int markNameEntryShownCalledCount = 0;

  FakeOnboardingPreferenceService({bool initialValue = false, bool initialNameEntryShown = false})
      : _passed = initialValue,
        _nameEntryShown = initialNameEntryShown;

  @override
  bool get isOnboardingPassed => _passed;

  @override
  Future<void> markOnboardingPassed() async {
    markCalledCount++;
    _passed = true;
  }

  @override
  bool get isNameEntryShown => _nameEntryShown;

  @override
  Future<void> markNameEntryShown() async {
    markNameEntryShownCalledCount++;
    _nameEntryShown = true;
  }
}
