/// In-code default values for all Remote Config parameters.
///
/// This is the single source of truth for defaults. Both [FirebaseRemoteConfigService]
/// and [NoopRemoteConfigService] reference these values so the app behaves
/// identically when Remote Config is unreachable (offline / first launch).
///
/// Key naming convention: snake_case, matching the Firebase Remote Config
/// console and the analytics event parameter naming convention.
abstract final class RemoteConfigDefaults {
  /// Maximum number of active pacts a user may have simultaneously.
  ///
  /// Matches the current hardcoded threshold. Override in the Firebase Remote
  /// Config console to experiment with different limits without a release.
  static const int maxActivePacts = 3;

  /// EXP-001: Notification text urgency variant.
  ///
  /// Controls the copy used in reminder notifications before the showup window.
  /// Values: `'control'` (generic), `'deadline'` (shows close time),
  /// `'time_limit'` (shows time remaining). Default is `'control'`.
  static const String notificationTextVariant = 'control';

  /// EXP-002: Post-deadline notification behaviour on Android.
  ///
  /// Controls what happens after the showup window closes on Android.
  /// Values: `'dismiss'` (auto-dismiss original, no replacement) or
  /// `'encourage'` (schedule a replacement notification with encouraging copy).
  /// Default is `'dismiss'`. iOS always shows the encouraging replacement
  /// regardless of this flag.
  static const String postDeadlineNotificationBehavior = 'dismiss';

  /// Seconds each onboarding slide is displayed before auto-advancing to the next.
  ///
  /// Values below 5 are treated as 0 (no auto-advance). Set to 0 in the Firebase
  /// Remote Config console to disable auto-advance for all users.
  static const int onboardingAutoAdvanceSeconds = 10;

  /// EXP-003: Commitment confirmation dialog variant shown during pact creation.
  ///
  /// Controls the confirmation UI shown when the user taps "Create Pact" on the
  /// wizard summary screen. Values: `'button'` = control (single "I accept"
  /// button), `'checkbox'` = variant A (checkbox must be ticked), `'retype'` =
  /// variant B (user must type the habit name to enable the Create button).
  /// Default is `'button'` (control group).
  ///
  /// Use [exp003CommitmentConfirmationKey] as the Remote Config parameter name.
  static const String exp003CommitmentConfirmationKey = 'exp_003_commitment_confirmation';

  /// Default value for [exp003CommitmentConfirmationKey].
  static const String exp003CommitmentConfirmation = 'button';

  /// All default values keyed by their Remote Config parameter name.
  ///
  /// Pass this map to `FirebaseRemoteConfig.setDefaults()` during initialisation
  /// so the SDK knows the fallback value for every parameter before the first
  /// successful fetch.
  static const Map<String, dynamic> all = {
    'max_active_pacts': maxActivePacts,
    'notification_text_variant': notificationTextVariant,
    'post_deadline_notification_behavior': postDeadlineNotificationBehavior,
    'onboarding_auto_advance_seconds': onboardingAutoAdvanceSeconds,
    'exp_003_commitment_confirmation': exp003CommitmentConfirmation,
  };

  /// Allowed string values for keys that accept only a fixed set of values.
  ///
  /// The debug override screen uses this to show a picker instead of a free-
  /// text field for enum-like keys. Keys absent from this map (or mapped to
  /// `null`) accept any value — the screen shows a plain text field instead.
  static const Map<String, List<String>?> allowedValues = {
    'max_active_pacts': null,
    'notification_text_variant': ['control', 'deadline', 'time_limit'],
    'post_deadline_notification_behavior': ['dismiss', 'encourage'],
    'onboarding_auto_advance_seconds': null,
    'exp_003_commitment_confirmation': ['button', 'checkbox', 'retype'],
  };
}
