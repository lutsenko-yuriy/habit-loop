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

  /// Feature toggle: enable the pact timeline screen entry point.
  ///
  /// When `false`, the "View timeline" button is hidden from pact detail screens.
  /// Override to `false` in the Firebase Remote Config console to disable the
  /// feature without a release.
  static const bool pactTimelineEnabled = true;

  /// Minimum consecutive same-outcome showup run length to produce a streak milestone.
  ///
  /// Runs below this threshold are collapsed into a mixed group milestone; runs at or
  /// above are shown as a streak milestone. Value must be ≥ 1. Override via RC
  /// to tune the grouping sensitivity. Remote Config key: `pact_timeline_milestone_grouping_threshold`.
  static const int pactTimelineMilestoneGroupingThreshold = 1;

  /// Number of days before now within which showups are always shown individually on the timeline.
  ///
  /// Remote Config key: `pact_timeline_no_grouping_tail_period_in_days`. Valid range: 7–21.
  static const int pactTimelineNoGroupingTailPeriodInDays = 7;

  /// Keys belonging to the feature-toggle category shown in a dedicated section
  /// of the debug RC overrides screen. All other keys fall under "A/B Tests".
  ///
  /// When adding a new key to [all], also add it here if it is a kill-switch
  /// toggle; omitting it silently places it in the A/B Tests section instead.
  static const Set<String> featureToggleKeys = {
    'language_selection_enabled',
    'network_sync_enabled',
    'pact_timeline_enabled',
    'showup_redemption_enabled',
  };

  /// Feature toggle: enable the showup redemption action on the showup detail screen.
  ///
  /// When `false`, the redemption action is hidden and auto-failed tail-zone showups
  /// cannot be redeemed. Override to `false` in the Firebase Remote Config console
  /// to disable the feature without a release.
  static const bool showupRedemptionEnabled = true;

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
    'pact_timeline_enabled': pactTimelineEnabled,
    'showup_redemption_enabled': showupRedemptionEnabled,
    'pact_timeline_milestone_grouping_threshold': pactTimelineMilestoneGroupingThreshold,
    'pact_timeline_no_grouping_tail_period_in_days': pactTimelineNoGroupingTailPeriodInDays,
  };

  /// Allowed string values for keys that accept only a fixed set of values.
  ///
  /// The debug override screen uses this to show a picker instead of a free-
  /// text field for enum-like keys. Keys absent from this map accept any value
  /// — the screen shows a plain text field instead.
  static const Map<String, List<String>> allowedValues = {
    'notification_text_variant': ['control', 'deadline', 'time_limit'],
    'post_deadline_notification_behavior': ['dismiss', 'encourage'],
    'exp_003_commitment_confirmation': ['button', 'checkbox', 'retype'],
    'debug_connectivity_state': ['perfect', 'unstable', 'absent'],
    'debug_backend': ['real', 'local'],
    'language_selection_enabled': ['true', 'false'],
    'network_sync_enabled': ['true', 'false'],
    'pact_timeline_enabled': ['true', 'false'],
    'showup_redemption_enabled': ['true', 'false'],
  };

  /// Bounded integer ranges for keys whose values must fall within a known
  /// [min, max] range (inclusive on both ends).
  ///
  /// The debug override screen uses this to display a slider instead of a
  /// free-text input for these keys. Keys absent from this map accept any
  /// value — the screen shows a plain text field.
  static const Map<String, ({int min, int max})> intRanges = {
    'max_active_pacts': (min: 1, max: 10),
    'debug_connectivity_stability_percent': (min: 0, max: 100),
    'sync_max_consecutive_failures': (min: 1, max: 20),
    'onboarding_auto_advance_seconds': (min: 0, max: 60),
    'pact_timeline_milestone_grouping_threshold': (min: 1, max: 50),
    'pact_timeline_no_grouping_tail_period_in_days': (min: 7, max: 21),
  };
}
