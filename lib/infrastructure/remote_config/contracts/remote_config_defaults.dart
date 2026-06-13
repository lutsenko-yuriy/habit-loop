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

  /// Maximum number of consecutive Firestore failures in the half-open state
  /// before the [SyncCircuitBreaker] transitions to open (suspended) state.
  ///
  /// Increase this value in Firebase Remote Config to make the circuit breaker
  /// more tolerant of transient failures; decrease it to react faster to
  /// persistent outages. The value takes effect on the next app start because
  /// [SyncCircuitBreaker] reads it once at provider initialisation time.
  static const int syncMaxConsecutiveFailures = 5;

  /// Debug-only: connectivity mode used by [FaultInjectingFirestoreClient].
  ///
  /// Values: `'perfect'` (all requests succeed), `'absent'` (all requests throw,
  /// simulating no network), `'unstable'` (each request succeeds with probability
  /// [debugConnectivityStabilityPercent] / 100).
  ///
  /// Default is `'perfect'` — fault injection is disabled. This key is only
  /// read in debug/profile builds where [FaultInjectingFirestoreClient] is wired
  /// in. Override via the in-app Remote Config overrides screen to exercise the
  /// circuit breaker and partial-failure paths during QA.
  static const String debugConnectivityState = 'perfect';

  /// Debug-only: success probability (0–100) when [debugConnectivityState] is
  /// `'unstable'`.
  ///
  /// **Only active when `debug_connectivity_state` is `'unstable'`** — ignored
  /// in `'perfect'` and `'absent'` modes.
  ///
  /// - `100` — every request succeeds (same as `'perfect'` mode).
  /// - `0` — every request fails (same as `'absent'` mode).
  /// - `50` — approximately half of requests succeed, exercising partial-failure
  ///   and circuit-breaker retry paths.
  static const int debugConnectivityStabilityPercent = 100;

  /// Debug-only: which backend to use in debug/profile builds.
  ///
  /// Values: `'real'` (default — real Firebase Auth + real/FaultInjecting
  /// Firestore) or `'local'` ([LocalAuthService] + [FakeFirestoreClient] with
  /// no network dependencies).
  ///
  /// In `'local'` mode:
  /// - Auth starts anonymous; tapping "Sign in with Google" immediately
  ///   succeeds and emits a non-anonymous state (no real OAuth required).
  /// - Firestore operations target an in-memory [FakeFirestoreClient] so the
  ///   full sync/pull/merge flow can be exercised without a live Firebase
  ///   project.
  ///
  /// **Requires an app restart to take effect** — the service instances are
  /// wired at startup and cannot be swapped at runtime.
  ///
  /// **Debug/profile only.** This key is never read in release builds.
  static const String debugBackend = 'real';

  /// Feature toggle: show the language-selection UI on the dashboard.
  ///
  /// When `false`, the language-picker button is hidden from the dashboard
  /// nav bar / app bar. The underlying locale preference logic is unchanged;
  /// only the entry point is removed. Override to `false` in the Firebase
  /// Remote Config console to hide the feature without a release.
  static const bool languageSelectionEnabled = true;

  /// Feature toggle: enable Firestore network sync.
  ///
  /// When `false`, all [FirestoreSyncService] methods return immediately
  /// without contacting Firestore. Local writes are still persisted as dirty
  /// and will be replayed when the flag is re-enabled. Override to `false`
  /// in the Firebase Remote Config console to disable sync without a release.
  static const bool networkSyncEnabled = true;

  /// Optional short hint shown in the debug override dialog for keys whose
  /// numeric range has a concrete semantic meaning.
  ///
  /// Keys absent from this map (or mapped to `null`) show no hint. Use `\n`
  /// to break the hint into multiple lines when the content warrants it.
  static const Map<String, String?> valueHints = {
    'debug_connectivity_stability_percent': '0 = all fail · 50 ≈ half succeed · 100 = all succeed\n'
        '(only active when debug_connectivity_state = unstable)',
    'debug_backend': 'local = LocalAuthService + FakeFirestoreClient\n'
        '(requires app restart to take effect)',
  };

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
    'sync_max_consecutive_failures': syncMaxConsecutiveFailures,
    'debug_connectivity_state': debugConnectivityState,
    'debug_connectivity_stability_percent': debugConnectivityStabilityPercent,
    'debug_backend': debugBackend,
    'language_selection_enabled': languageSelectionEnabled,
    'network_sync_enabled': networkSyncEnabled,
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
    'sync_max_consecutive_failures': null,
    'debug_connectivity_state': ['perfect', 'unstable', 'absent'],
    'debug_connectivity_stability_percent': null,
    'debug_backend': ['real', 'local'],
    'language_selection_enabled': ['true', 'false'],
    'network_sync_enabled': ['true', 'false'],
  };

  /// Bounded integer ranges for keys whose values must fall within a known
  /// [min, max] range (inclusive on both ends).
  ///
  /// The debug override screen uses this to display a slider instead of a
  /// free-text input for these keys. Keys absent from this map (or mapped to
  /// `null`) accept any value — the screen shows a plain text field.
  ///
  /// Only keys with both a meaningful lower and upper bound are listed here;
  /// open-ended numeric keys (e.g. `max_active_pacts`) remain free-text.
  static const Map<String, ({int min, int max})?> intRanges = {
    'debug_connectivity_stability_percent': (min: 0, max: 100),
    'sync_max_consecutive_failures': (min: 1, max: 20),
    'onboarding_auto_advance_seconds': (min: 0, max: 60),
    'language_selection_enabled': null,
    'network_sync_enabled': null,
  };
}
