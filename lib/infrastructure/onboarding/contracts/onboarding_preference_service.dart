/// Abstract interface for persisting the one-time onboarding-passed flag.
///
/// The flag is set once — when the user sees the dashboard screen for the
/// first time (meaning they have either created a pact or signed in with
/// Google). Reading the flag is synchronous because SharedPreferences holds
/// its values in memory after the first [SharedPreferences.getInstance] call.
///
/// This single synchronous read at startup lets [DashboardScreen] determine
/// whether to show the onboarding carousel or the dashboard on the very first
/// Flutter frame — eliminating the cold-start blink caused by the async
/// [hasActivePactsProvider] going through AsyncLoading.
///
/// **No-throw contract:** all implementations must swallow exceptions
/// internally. Call sites may call any method without wrapping in try/catch.
abstract interface class OnboardingPreferenceService {
  /// Returns `true` if the user has previously reached the dashboard screen.
  ///
  /// Reads synchronously from the in-memory SharedPreferences cache.
  /// Returns `false` when SharedPreferences is unavailable (noop) or the
  /// key has never been written (first launch / fresh install).
  bool get isOnboardingPassed;

  /// Marks onboarding as passed.
  ///
  /// Called once when [DashboardScreen] first renders the dashboard (not the
  /// onboarding carousel). Subsequent calls are no-ops — writing `true` over
  /// `true` is safe and idempotent.
  ///
  /// Never throws — implementations swallow failures silently.
  Future<void> markOnboardingPassed();
}
