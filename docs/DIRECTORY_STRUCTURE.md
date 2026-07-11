# Directory Structure

The full file/directory map of the codebase — a quick-glance companion to `docs/ARCHITECTURE.md`, which explains *why* each layer exists and *how* the pieces behave. This file only shows *where* things live.

> **Maintenance note:** this file duplicates information that also lives, in more detail, in `docs/ARCHITECTURE.md`'s prose sections. Keeping both in sync is manual — when a file moves or a new one is added, update the entry here too. HAB-159 (backlog) will investigate whether this split-file structure is worth keeping, or whether a generated/lighter-weight visual replaces it.

```
assets/
├── app_icon/
│   └── habit_loop_icon.png            # Source launcher icon generated from the Habit Loop palette
└── onboarding/
    ├── slide_0_habit_loop.svg          # Onboarding slide 0 illustration — circular arrows loop motif
    ├── slide_1_pact.svg                # Onboarding slide 1 illustration — document + handshake
    ├── slide_2_reminder.svg            # Onboarding slide 2 illustration — bell with pulse rings
    └── slide_3_progress.svg            # Onboarding slide 3 illustration — bar chart with trend line

lib/
├── main.dart                          # App entry point (runApp)
├── l10n/                              # ARB source files, generated/ output, and shared localisation utilities
│   ├── generated/                     # Output of `flutter gen-l10n` — do not edit by hand
│   └── date_formatters.dart           # formatLocaleDate(context, date) — single locale-aware yMd helper shared across all slices
├── theme/                             # Shared Habit Loop palette and Material/Cupertino theme data
├── domain/                            # Top-level shared domain — pure models and repository interfaces used by multiple features
│   ├── pact/
│   │   ├── pact.dart                  # Pact model — pure domain value object
│   │   ├── pact_status.dart           # PactStatus enum (active, stopped, completed)
│   │   ├── pact_stats.dart            # PactStats computed stats model
│   │   ├── pact_repository.dart       # PactRepository interface
│   │   ├── pact_sync_repository.dart  # PactSyncRepository interface — getDirtyPacts(), markPactSynced(), getPactSyncedAt(); implemented by SqlitePactRepository; consumed by WU4/WU5 sync service
│   │   ├── showup_schedule.dart       # ShowupSchedule model (daily, weekly, monthly)
│   │   └── schedule_type.dart         # ScheduleType enum
│   └── showup/
│       ├── showup.dart                # Showup model — pure domain value object
│       ├── showup_status.dart         # ShowupStatus enum (pending, done, failed)
│       ├── showup_repository.dart     # ShowupRepository interface
│       ├── showup_sync_repository.dart # ShowupSyncRepository interface — getDirtyShowups(), markShowupSynced(), getShowupSyncedAt(); implemented by SqliteShowupRepository; consumed by WU4/WU5 sync service
│       ├── showup_generator.dart      # ShowupGenerator — deterministic showup generation from a pact schedule
│       ├── showup_date_utils.dart     # ShowupDateUtils — date arithmetic helpers
│       └── save_showups_result.dart   # SaveShowupsResult — batch-save result type
├── infrastructure/                    # Cross-cutting infrastructure shared by all features
│   ├── injections/
│   │   ├── app_providers.dart         # Single canonical file declaring every app-wide Riverpod provider; all lib/ and test/ code imports providers from here
│   │   └── app_container.dart         # AppContainer — static class exposing List<Override> overrides(...); called by main.dart to wire all production instances into ProviderScope
│   ├── analytics/
│   │   ├── contracts/                 # AnalyticsEvent (abstract base), AnalyticsScreen, AnalyticsService interface
│   │   └── data/                      # FirebaseAnalyticsService, FirebaseAnalyticsClientAdapter, NoopAnalyticsService
│   ├── auth/
│   │   ├── contracts/
│   │   │   ├── auth_state.dart        # AuthState value type — userId, isAnonymous, isSignedIn
│   │   │   └── auth_service.dart      # AuthService abstract interface (no-throw on initialize/signOut; linkWithGoogle may throw FirebaseAuthException)
│   │   └── data/
│   │       ├── firebase_auth_service.dart         # FirebaseAuthService + FirebaseAuthClient interface (SDK isolation); signs in anonymously on initialize if no user
│   │       ├── firebase_auth_client_adapter.dart  # wraps FirebaseAuth + GoogleSignIn.instance (lazy init); only used in main.dart
│   │       ├── local_auth_service.dart            # LocalAuthService — debug/profile stateful fake; auto-signs-in as localUserId; wired when debug_backend = 'local'. See Auth prose in ARCHITECTURE.md.
│   │       └── noop_auth_service.dart             # default no-op (userId null, isAnonymous true)
│   ├── crashlytics/
│   │   ├── contracts/
│   │   │   └── crashlytics_service.dart            # abstract CrashlyticsService interface (no-throw contract)
│   │   └── data/
│   │       ├── firebase_crashlytics_service.dart       # real implementation (swallows exceptions)
│   │       ├── firebase_crashlytics_client_adapter.dart # wraps FirebaseCrashlytics SDK; only used in main.dart
│   │       └── noop_crashlytics_service.dart           # default no-op
│   ├── device/
│   │   ├── contracts/
│   │   │   └── device_id_service.dart # DeviceIdService interface — getOrCreateDeviceId() returns a stable per-install UUID
│   │   └── data/
│   │       ├── shared_preferences_device_id_service.dart  # UUID v4 generated on first call and persisted under 'habit_loop_device_id'
│   │       └── noop_device_id_service.dart               # returns sentinel '00000000-0000-0000-0000-000000000000'
│   ├── logging/
│   │   ├── contracts/
│   │   │   └── log_service.dart                    # abstract LogService interface (debug/info/warning/error/logLocal); PII rules documented
│   │   └── data/
│   │       ├── talker_log_service.dart                 # talker_flutter implementation; in-app overlay gated on kDebugMode
│   │       └── noop_log_service.dart                   # default no-op
│   ├── firestore/
│   │   ├── contracts/
│   │   │   └── firestore_client.dart  # FirestoreClient — abstract no-throw interface; flat /users/{uid}/... paths; Map<String, dynamic> only (no SDK types). See Firestore prose in ARCHITECTURE.md.
│   │   └── data/
│   │       ├── noop_firestore_client.dart  # NoopFirestoreClient — silent no-op; reads return empty lists
│   │       ├── fake_firestore_client.dart  # FakeFirestoreClient + FakeFirestoreSeedData — debug/profile in-memory client (seed/clear/snapshot) for QA pull/merge testing
│   │       └── fault_injecting_firestore_client.dart  # FaultInjectingFirestoreClient — debug/profile decorator injecting connectivity faults (perfect/absent/unstable) read from RemoteConfigService
│   ├── persistence/
│   │   ├── habit_loop_database.dart   # HabitLoopDatabase — owns the sqflite Database lifecycle, schema DDL (runMigrations v2), and upgrade path (runUpgradeMigrations); production singleton + @visibleForTesting openForTesting()
│   │   ├── schedule_codec.dart        # ScheduleCodec — encodes/decodes ShowupSchedule to/from JSON string (schedule TEXT column)
│   │   ├── pact_mapper.dart           # PactMapper — maps Pact domain objects to/from SQLite row maps
│   │   └── showup_mapper.dart         # ShowupMapper — maps Showup domain objects to/from SQLite row maps
│   ├── locale/
│   │   ├── contracts/
│   │   │   └── locale_preference_service.dart  # LocalePreferenceService interface — getSavedLocale(), saveLocale(Locale), clearLocale(); no-throw contract
│   │   └── data/
│   │       ├── shared_preferences_locale_service.dart  # SharedPreferencesLocaleService — persists locale as a language code string; validates against supportedLocales on read
│   │       └── noop_locale_preference_service.dart     # default no-op; getSavedLocale() returns null
│   ├── notifications/
│   │   ├── contracts/
│   │   │   └── notification_service.dart   # NotificationService — abstract no-throw interface (schedule/cancel reminders + deadline notifications, pending list, launch details)
│   │   └── data/
│   │       ├── flutter_local_notification_service.dart  # FlutterLocalNotificationService — production; DST-safe zonedSchedule(). See Notifications prose in ARCHITECTURE.md.
│   │       ├── noop_notification_service.dart           # NoopNotificationService — silent no-op used by unit tests
│   │       └── test_notification_helper.dart            # scheduleTestNotification() — debug/profile helper; tree-shaken from release builds
│   ├── onboarding/
│   │   ├── contracts/
│   │   │   └── onboarding_preference_service.dart  # OnboardingPreferenceService interface — isOnboardingPassed (bool, synchronous), markOnboardingPassed() (async, no-throw); write-once flag
│   │   └── data/
│   │       ├── shared_preferences_onboarding_service.dart  # SharedPreferencesOnboardingService — reads synchronously from in-memory SP cache; writes fire-and-forget; key 'habit_loop_onboarding_passed'
│   │       └── noop_onboarding_service.dart                # default no-op; isOnboardingPassed always false
│   ├── remote_config/
│   │   ├── contracts/
│   │   │   ├── remote_config_service.dart          # abstract RemoteConfigService interface (no-throw contract)
│   │   │   ├── remote_config_defaults.dart         # RemoteConfigDefaults — in-code fallback values; `all` map is the single source of truth for every known key
│   │   │   ├── remote_config_override_store.dart   # RemoteConfigOverrideStore interface — getOverride(key)→String?, setOverride, clearOverride, getAllOverrides; debug/profile only
│   │   │   └── feature_flags.dart                  # FeatureFlags value object — typed bool getters built from RemoteConfigService; featureFlagsProvider in app_providers.dart
│   │   └── data/
│   │       ├── firebase_remote_config_service.dart     # real implementation (swallows exceptions); also contains FirebaseRemoteConfigClient interface
│   │       ├── firebase_remote_config_client_adapter.dart # wraps FirebaseRemoteConfig SDK; only used in main.dart
│   │       ├── noop_remote_config_service.dart         # default no-op returning in-code defaults
│   │       ├── noop_remote_config_override_store.dart  # const no-op default for remoteConfigOverrideStoreProvider; getAllOverrides() returns {}
│   │       ├── shared_preferences_remote_config_override_store.dart  # stores overrides as strings under rc_override_<key>; debug/profile only; wired in main.dart via AppContainer
│   │       └── overridable_remote_config_service.dart  # wraps any RemoteConfigService + RemoteConfigOverrideStore; checks store first, delegates to inner on miss; honours no-throw contract; debug/profile only
│   └── sync/
│       ├── sync_circuit_breaker.dart  # SyncCircuitBreakerState (closed/halfOpen/open) + SyncCircuitBreaker StateNotifier; governs Firestore requests; RC-tunable threshold. See Sync prose in ARCHITECTURE.md.
│       ├── sync_service.dart          # SyncService — abstract no-throw interface (uploadPact, uploadShowup, flushDirtyRecords, triggerManualSync, pullRemoteChanges); called fire-and-forget
│       ├── noop_sync_service.dart     # NoopSyncService — const no-op default for syncServiceProvider
│       ├── sync_mapper.dart           # SyncMapper — domain ↔ Firestore Map<String, dynamic>; excludes SQLite-only columns; carries updated_at for merge
│       └── firestore_sync_service.dart  # FirestoreSyncService — production SyncService; CB-gated uploads + last-writer-wins pullRemoteChanges(). See Sync prose in ARCHITECTURE.md.
└── slices/
    ├── about/                         # About screen: app info, feedback link, licences
    │   ├── analytics/                 # AboutAnalyticsScreen, FeedbackTappedEvent
    │   └── ui/ (generic/ — about_screen.dart; ios/ — about_page_ios.dart; android/ — about_page_android.dart)
    ├── dashboard/                     # Home screen: calendar strip, showup list, pacts panel; onboarding carousel (zero-pact state)
    │   ├── analytics/                 # Dashboard, language-picker, sync-status, and onboarding screen/event classes (see docs/ANALYTICS_EVENTS.md for the full catalogue)
    │   └── ui/ (generic/ — language picker handler, sync status (SyncUiState, SyncStatusViewModel, sync_status_handler), onboarding (OnboardingSlide, OnboardingViewModel); ios/ + android/ — platform carousels and dashboard pages)
    ├── pact/                          # Pact creation wizard, pact detail screen, pact timeline screen
    │   ├── application/               # PactBuilder, PactCreationState, PactStatsService, PactTransactionService, PactTimelineConfig, PactTimelineGrouper, PactTimelineMilestone (sealed union), PactTimelineCache (standalone injectable), PactTimelineService, PactTimelinePage
    │   ├── data/                      # InMemoryPactRepository (tests), SqlitePactRepository (production, implements PactRepository + PactSyncRepository), NoopPactSyncRepository (default provider)
    │   ├── analytics/                 # PactCreatedEvent, PactStoppedEvent, PactTimelineAnalyticsScreen, PactTimelineLoadMoreEvent, PactTimelineMilestoneTappedEvent (pact_timeline_analytics_events.dart — HAB-116)
    │   └── ui/ (generic/ — PactTimelineScreen, PactTimelineViewModel, PactTimelineState, pact_timeline_formatters.dart; ios/ — pact_timeline_page_ios.dart; android/ — pact_timeline_page_android.dart)
    ├── showup/                        # Showup detail, generation service
    │   ├── application/               # ShowupGenerationService
    │   ├── data/                      # InMemoryShowupRepository (tests), SqliteShowupRepository (production, implements ShowupRepository + ShowupSyncRepository), NoopShowupSyncRepository (default provider)
    │   ├── analytics/                 # ShowupMarkedDoneEvent, ShowupMarkedFailedEvent, ShowupAutoFailedEvent
    │   └── ui/ (generic/, ios/, android/)
    ├── reminder/                      # Notification scheduling orchestration (no UI of its own)
    │   ├── application/               # ReminderSchedulingService (schedules/cancels reminders, reads EXP-001/EXP-002 flags), NotificationTextBuilder
    │   └── analytics/                 # reminder_analytics_events.dart (AppOpenedFromNotificationEvent, etc.)
    └── debug/                         # Debug/profile-only tooling — not present in release builds
        └── ui/ (generic/ — RemoteConfigOverridesViewModel, DebugSeedDataViewModel; ios/ + android/ — RC overrides pages with per-key editor + seed-data section)

test/
├── l10n/                              # Mirrors lib/l10n/
│   └── date_formatters_test.dart      # Widget tests for formatLocaleDate (en, fr, de)
├── theme/                             # Shared app theme/widget tests
├── domain/                            # Mirrors lib/domain/
│   ├── pact/                          # Pact, PactStats, ShowupSchedule tests
│   └── showup/                        # Showup, ShowupGenerator tests
├── infrastructure/                    # Mirrors lib/infrastructure/
│   ├── injections/
│   │   └── app_container_test.dart    # Smoke test: AppContainer.overrides(...) returns expected override count; all canonical providers resolve without throwing
│   ├── analytics/
│   │   ├── domain/
│   │   ├── data/
│   │   └── fake_analytics_service.dart    # Shared fake for tests that assert on analytics calls
│   ├── auth/
│   │   ├── data/
│   │   │   ├── firebase_auth_service_test.dart  # FirebaseAuthService: initialize, currentUserId, isAnonymous, linkWithGoogle, signOut, authStateChanges via _FakeFirebaseAuthClient
│   │   │   └── noop_auth_service_test.dart
│   │   └── fake_auth_service.dart     # Configurable fake for tests that need auth state
│   ├── crashlytics/
│   │   ├── data/
│   │   │   ├── firebase_crashlytics_service_test.dart
│   │   │   └── noop_crashlytics_service_test.dart
│   │   └── fake_crashlytics_service.dart  # Shared fake for test overrides
│   ├── device/
│   │   ├── data/
│   │   │   ├── shared_preferences_device_id_service_test.dart  # getOrCreateDeviceId: generates UUID, persists, returns same value on repeat calls
│   │   │   └── noop_device_id_service_test.dart
│   │   └── fake_device_id_service.dart    # Injectable fake returning a configurable device ID
│   ├── logging/
│   │   ├── data/
│   │   │   ├── talker_log_service_test.dart
│   │   │   └── noop_log_service_test.dart
│   │   └── fake_log_service.dart              # Shared fake for test overrides
│   ├── firestore/
│   │   └── data/
│   │       └── noop_firestore_client_test.dart  # NoopFirestoreClient: all operations no-throw; reads return empty lists
│   ├── persistence/
│   │   ├── habit_loop_database_test.dart  # schema creation, column/index checks; v1→v2 upgrade migration adds dirty/synced_at
│   │   ├── schedule_codec_test.dart       # ScheduleCodec encode/decode round-trips, type-guard FormatException cases
│   │   ├── pact_mapper_test.dart          # PactMapper toRow/fromRow/toUpdateRow/round-trip, including local-time regression tests
│   │   └── showup_mapper_test.dart        # ShowupMapper toRow/fromRow/round-trip, including local-time regression tests
│   ├── notifications/
│   │   ├── fake_notification_service.dart              # Shared fake recording all calls (scheduledReminders, scheduledDeadlines, cancelledShowupIds, cancelledPactIds)
│   │   └── data/
│   │       └── noop_notification_service_test.dart
│   ├── onboarding/
│   │   ├── fake_onboarding_preference_service.dart  # FakeOnboardingPreferenceService — configurable fake with markCalledCount counter
│   │   └── data/
│   │       ├── shared_preferences_onboarding_service_test.dart  # isOnboardingPassed: false when absent, true when pre-set; markOnboardingPassed: write + read round-trip, idempotent, no-throw
│   │       └── noop_onboarding_service_test.dart                # always false, markOnboardingPassed no-op, no-throw
│   ├── remote_config/
│   │   ├── data/
│   │   │   ├── firebase_remote_config_service_test.dart
│   │   │   └── noop_remote_config_service_test.dart
│   │   ├── fake_remote_config_service.dart         # Shared fake for test overrides
│   │   └── fake_remote_config_override_store.dart  # In-memory FakeRemoteConfigOverrideStore backed by Map<String, String>
│   └── sync/
│       ├── sync_circuit_breaker_test.dart  # SyncCircuitBreaker: state machine, failure counter, RC-tunable threshold, provider smoke tests
│       ├── sync_mapper_test.dart           # SyncMapper: pact and showup round-trips, status encoding, SQLite column exclusion
│       ├── noop_sync_service_test.dart     # NoopSyncService: all operations no-throw, returns normally
│       ├── firestore_sync_service_test.dart  # FirestoreSyncService: upload/skip/failure paths, CB state transitions, flushDirtyRecords cap, triggerManualSync, null-userId guard, pullRemoteChanges merge rules
│       └── fake_sync_service.dart          # Shared fake recording uploadedPactIds, uploadedShowupIds, flushCount, triggerManualSyncCount
└── slices/                            # Mirrors lib/slices/
    ├── dashboard/ (analytics/, ui/)
    ├── pact/
    │   ├── analytics/, ui/
    │   ├── application/
    │   │   ├── pact_stats_service_cache_test.dart # PactStatsService in-memory cache: lazy cache-on-miss, cache hit, write-through on persistShowupStatus, evict-only on stopPact, lazy fallback to pact.stats, onPactCompleted eviction
    │   │   └── pact_transaction_service_test.dart # PactTransactionService: savePactWithShowups atomicity + stopPactTransaction atomicity; sqflite_common_ffi in-memory db
    │   └── data/
    │       └── sqlite_pact_repository_test.dart   # SqlitePactRepository CRUD + PactSyncRepository (getDirtyPacts, markPactSynced) tests using sqflite_common_ffi in-memory db
    ├── showup/
    │   ├── analytics/, application/, ui/
    │   └── data/
    │       └── sqlite_showup_repository_test.dart # SqliteShowupRepository CRUD + date-boundary + ShowupSyncRepository (getDirtyShowups, markShowupSynced) tests using sqflite_common_ffi
    └── debug/
        └── ui/ (generic/ — remote_config_overrides_view_model_test.dart, debug_seed_data_view_model_test.dart; ios/ + android/ — RC overrides page widget tests)
```
