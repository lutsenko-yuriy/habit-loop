# Architecture

Vertical-slice architecture where each slice is a feature from @docs/PRODUCT_SPEC.md, with four layers per slice: domain, application, data, and UI.

Cross-cutting infrastructure (analytics, crashlytics, remote config) lives under `lib/infrastructure/`. Pure domain models and repository interfaces shared across features live under `lib/domain/`.

Product experiments (hypothesis, metrics, decisions) are tracked in `docs/experiments/` — see `docs/experiments/README.md` for the index and `docs/experiments/TEMPLATE.md` for the per-experiment format.

## Directory structure

```
assets/
└── app_icon/
    └── habit_loop_icon.png            # Source launcher icon generated from the Habit Loop palette

lib/
├── main.dart                          # App entry point (runApp)
├── l10n/                              # ARB source files, generated/ output, and shared localisation utilities
│   ├── generated/                     # Output of `flutter gen-l10n` — do not edit by hand
│   └── date_formatters.dart           # formatLocaleDate(context, date) — single locale-aware yMd helper shared across all slices
├── theme/                             # Shared Habit Loop palette and Material/Cupertino theme data
├── domain/                            # Top-level shared domain — pure models and repository interfaces used by multiple features
│   ├── pact/
│   │   ├── pact.dart                  # Pact model — includes dirty/syncedAt for Firestore sync tracking
│   │   ├── pact_status.dart           # PactStatus enum (active, stopped, completed)
│   │   ├── pact_stats.dart            # PactStats computed stats model
│   │   ├── pact_repository.dart       # PactRepository interface
│   │   ├── showup_schedule.dart       # ShowupSchedule model (daily, weekly, monthly)
│   │   └── schedule_type.dart         # ScheduleType enum
│   └── showup/
│       ├── showup.dart                # Showup model — includes dirty/syncedAt for Firestore sync tracking
│       ├── showup_status.dart         # ShowupStatus enum (pending, done, failed)
│       ├── showup_repository.dart     # ShowupRepository interface
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
│   │   │   └── firestore_client.dart  # FirestoreClient — abstract interface (no-throw contract): getPacts/getShowups/upsertPact/upsertShowup/deletePact/deleteShowup; flat /users/{uid}/pacts/{id} and /users/{uid}/showups/{id} paths; all data as Map<String, dynamic> (no SDK types in interface)
│   │   └── data/
│   │       └── noop_firestore_client.dart  # NoopFirestoreClient — silent no-op; reads return empty lists
│   ├── persistence/
│   │   ├── habit_loop_database.dart   # HabitLoopDatabase — owns the sqflite Database lifecycle, schema DDL (runMigrations v2), and upgrade path (runUpgradeMigrations); production singleton + @visibleForTesting openForTesting()
│   │   ├── schedule_codec.dart        # ScheduleCodec — encodes/decodes ShowupSchedule to/from JSON string (schedule TEXT column)
│   │   ├── pact_mapper.dart           # PactMapper — maps Pact domain objects to/from SQLite row maps
│   │   └── showup_mapper.dart         # ShowupMapper — maps Showup domain objects to/from SQLite row maps
│   ├── notifications/
│   │   ├── contracts/
│   │   │   └── notification_service.dart   # NotificationService — abstract interface (no-throw contract): initialize(), requestPermission(), scheduleShowupReminder(), scheduleDeadlineNotification(), cancelShowupReminder(), cancelAllRemindersForPact(), getPendingNotifications(), getAppLaunchDetails()
│   │   └── data/
│   │       ├── flutter_local_notification_service.dart  # FlutterLocalNotificationService — production implementation; DST-safe zonedSchedule() with TZDateTime; in-memory _pactNotificationIds registry for cancelAllRemindersForPact(); onDidReceiveNotificationResponse callback stored for WU4 to wire
│   │       ├── noop_notification_service.dart           # NoopNotificationService — silent no-op used by unit tests (which override notificationServiceProvider directly and never call main())
│   │       └── test_notification_helper.dart            # scheduleTestNotification(NotificationService) — debug/profile helper that schedules a fake 15-s notification via the service abstraction; tree-shaken from release builds
│   └── remote_config/
│       ├── contracts/
│       │   ├── remote_config_service.dart          # abstract RemoteConfigService interface (no-throw contract)
│       │   └── remote_config_defaults.dart         # RemoteConfigDefaults — in-code fallback values
│       └── data/
│           ├── firebase_remote_config_service.dart     # real implementation (swallows exceptions); also contains FirebaseRemoteConfigClient interface
│           ├── firebase_remote_config_client_adapter.dart # wraps FirebaseRemoteConfig SDK; only used in main.dart
│           └── noop_remote_config_service.dart         # default no-op returning in-code defaults
└── slices/
    ├── dashboard/                     # Home screen: calendar strip, showup list, pacts panel
    │   ├── analytics/                 # DashboardAnalyticsScreen, LanguagePickerAnalyticsScreen, LanguageChangeRequestedEvent, LanguageChangedEvent
    │   └── ui/ (generic/ — includes language_picker_handler.dart with shared applyLanguageSelection orchestration, ios/, android/)
    ├── pact/                          # Pact creation wizard + pact detail screen
    │   ├── application/               # PactBuilder, PactCreationState, PactStatsService, PactTransactionService
    │   ├── data/                      # InMemoryPactRepository (tests), SqlitePactRepository (production)
    │   ├── analytics/                 # PactCreatedEvent, PactStoppedEvent
    │   └── ui/ (generic/, ios/, android/)
    ├── showup/                        # Showup detail, generation service
    │   ├── application/               # ShowupGenerationService
    │   ├── data/                      # InMemoryShowupRepository (tests), SqliteShowupRepository (production)
    │   ├── analytics/                 # ShowupMarkedDoneEvent, ShowupMarkedFailedEvent, ShowupAutoFailedEvent
    │   └── ui/ (generic/, ios/, android/)
    └── reminder/                      # Notification scheduling (not yet implemented)
        ├── domain/
        ├── data/
        └── ui/ (generic/, ios/, android/)

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
│   └── remote_config/
│       ├── data/
│       │   ├── firebase_remote_config_service_test.dart
│       │   └── noop_remote_config_service_test.dart
│       └── fake_remote_config_service.dart  # Shared fake for test overrides
└── slices/                            # Mirrors lib/slices/
    ├── dashboard/ (analytics/, ui/)
    ├── pact/
    │   ├── analytics/, ui/
    │   ├── application/
    │   │   ├── pact_stats_service_cache_test.dart # PactStatsService in-memory cache: lazy cache-on-miss, cache hit, write-through on persistShowupStatus, evict-only on stopPact, lazy fallback to pact.stats, onPactCompleted eviction
    │   │   └── pact_transaction_service_test.dart # PactTransactionService: savePactWithShowups atomicity + stopPactTransaction atomicity; sqflite_common_ffi in-memory db
    │   └── data/
    │       └── sqlite_pact_repository_test.dart   # SqlitePactRepository CRUD tests using sqflite_common_ffi in-memory db
    └── showup/
        ├── analytics/, application/, ui/
        └── data/
            └── sqlite_showup_repository_test.dart # SqliteShowupRepository CRUD + date-boundary tests using sqflite_common_ffi
```

## Layers

### Domain (`lib/domain/`)
Pure business models and repository interfaces shared across features. No dependencies on data, UI, infrastructure, or application layers.
- Models: `Pact`, `PactStatus`, `Showup`, `ShowupStatus`, `ShowupSchedule`, `PactStats`, `ScheduleType`
- Repository interfaces: `PactRepository`, `ShowupRepository`
- Generators: `ShowupGenerator`, `ShowupDateUtils`
- Result types: `SaveShowupsResult`

### Application (`lib/slices/*/application/`)
Orchestration logic that coordinates domain objects and repository calls. Lives inside each slice vertical. May depend on `lib/domain/` and on other slices' application services when necessary (though cross-slice imports should be minimised).
- `PactBuilder` (`slices/pact/application/`) — holds the 7 pact-data fields assembled during the creation wizard, exposes validity predicates (`isDateRangeValid`, `isShowupDurationValid`, `isScheduleSet`, `isHabitNameValid`, `isComplete`), and materialises a `Pact` via `build(id, createdAt)`.
- `PactCreationState` (`slices/pact/application/`) — wizard-navigation state: holds `builder: PactBuilder`, `currentStep`, `commitmentAccepted`, `isSubmitting`, `submitError`. Re-exports `ScheduleType` for backwards compatibility.
- `PactStatsService` (`slices/pact/application/`) — owns pact stats calculation, persistence, and the stop-pact transaction. Holds a private `Map<String, PactStats> _statsCache` (runtime-only, never persisted) keyed by pact ID that lives for the app session. `currentStats(pact, showups: [])` is async and uses lazy cache-on-miss: on a cache hit it returns immediately without a DB round-trip; on a cache miss it loads showups from `ShowupRepository`, computes stats, writes to `_statsCache[pact.id]`, and returns — subsequent calls are cache hits. Passing a non-empty `showups` list bypasses the cache entirely and computes fresh stats from the provided list (does not write to cache). `persistShowupStatus()` does write-through (evict stale entry, then repopulate via `_syncStatsBestEffort` → `syncStats` → `persistStats`). `stopPact()` does evict-only after the transaction deletes showups. `onPactCompleted()` evicts the cache entry after a pact is auto-completed; called by `PactService.updatePact()` when the persisted pact has `PactStatus.completed`. `persistStats()` (called during pact creation and sync) always populates the cache with the freshly computed stats.
- `PactTransactionService` (`slices/pact/application/`) — owns the atomic write paths that span both `pacts` and `showups` tables. `savePactWithShowups(pact, showups)` inserts both in one SQLite transaction and sets `total_showups` to `showups.length`. `stopPactTransaction(updatedPact, pactId)` updates the pact row and deletes the pact's showups in one SQLite transaction. Both methods use `ConflictAlgorithm.fail` so any duplicate-ID error surfaces immediately rather than silently overwriting data. Provider declared in `lib/infrastructure/injections/app_providers.dart`. `pactServiceProvider` watches `pactStatsServiceProvider` (one-way dependency so `PactService.updatePact` can call `PactStatsService.onPactCompleted`); `pactStatsServiceProvider` must never watch `pactServiceProvider` — doing so would create a circular dependency in the Riverpod graph.
- `ShowupGenerationService` (`slices/showup/application/`) — orchestrates lazy windowed showup generation and deduplication.

### Data (`lib/slices/*/data/`)
Storage and persistence. Implements repository interfaces from `lib/domain/`.
- `SqlitePactRepository` (`slices/pact/data/`) — production SQLite implementation of `PactRepository`; takes an injected `Database` from `HabitLoopDatabase`; uses `PactMapper` for row conversion.
- `SqliteShowupRepository` (`slices/showup/data/`) — production SQLite implementation of `ShowupRepository`; takes an injected `Database`; uses `ShowupMapper` and `ShowupDateUtils` for date-range queries (all date filtering uses epoch milliseconds with local-time boundaries computed by `ShowupDateUtils.startOfDay`/`endOfDay`).
- `InMemoryPactRepository`, `InMemoryShowupRepository` — retained for use in tests that do not need a real database (all existing slice tests inject these).

### UI (`lib/slices/*/ui/`)
Platform-split presentation:
- `generic/` — view models (Riverpod notifiers), shared state classes (e.g. `DashboardState`, `PactDetailState`, `PactListState`, `ShowupDetailState`), and platform-agnostic helpers shared by both Cupertino and Material implementations (formatters, colour-role resolvers, and reusable widgets). Examples: `slices/pact/ui/generic/pact_creation_formatters.dart` (date/schedule/reminder labels), `slices/pact/ui/generic/summary_row.dart`, `slices/showup/ui/generic/showup_formatters.dart`, `slices/showup/ui/generic/showup_status_colors.dart` (Cupertino + Material palette factories mapping `ShowupStatus` to colours), `slices/showup/ui/generic/showup_status_dots.dart` (calendar-strip dot widget). Helpers that need a platform-idiom colour accept it as a parameter rather than branching on platform.
- `ios/` — Cupertino widgets
- `android/` — Material widgets

### Theme

`lib/theme/` contains the cross-platform Habit Loop visual foundation: the shared brand palette and the Material/Cupertino theme data applied from `HabitLoopApp`. Feature UI should consume the theme via `Theme.of(context)`, `CupertinoTheme.of(context)`, or the shared semantic colors when a reusable status color is needed. Launcher icon assets under `assets/app_icon/`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/`, and `android/app/src/main/res/mipmap-*/` use the same palette so the installed app icon matches the in-app design language.

### Infrastructure (`lib/infrastructure/`)

Cross-cutting services (analytics, crashlytics, logging, notifications, remote config) that are shared by the entire app. Each service follows the same internal structure: `contracts/` (abstract interface with a no-throw contract) and `data/` (production implementation + noop fallback). Provider declarations have been consolidated — see Injections below.

Each slice vertical may contain an `analytics/` subdirectory (e.g. `slices/pact/analytics/`, `slices/showup/analytics/`) with event classes extending `AnalyticsEvent`. This keeps event definitions co-located with the domain they describe.

**Injections:** `lib/infrastructure/injections/` is the single composition root. `app_providers.dart` declares every app-wide Riverpod provider (repositories, transaction service, application services, and all infrastructure service providers including `notificationServiceProvider`). `app_container.dart` exposes `AppContainer.overrides(...)`, a static factory that accepts already-constructed production instances and returns the `List<Override>` passed to `ProviderScope` in `main.dart`. `main.dart` retains all `kReleaseMode` branching and Firebase construction; `AppContainer` is mode-agnostic and purely maps instances to overrides. See `docs/INJECTIONS.md` for the full dependency graph.

**Analytics:** `lib/infrastructure/analytics/` contains the abstract base class (`AnalyticsEvent`, `AnalyticsScreen`), service interface (`AnalyticsService`), Firebase adapter, noop adapter, and Riverpod provider. It has no `ui/` directory because it contains no widgets.

**Auth:** `lib/infrastructure/auth/` provides anonymous Firebase Auth with optional Google account linking. `AuthService` interface has a no-throw contract on `initialize()` and `signOut()`; `linkWithGoogle()` may throw `FirebaseAuthException` (callers are expected to handle it). `FirebaseAuthClient` is an intermediate adapter interface that isolates all Firebase and Google Sign-In SDK types — test fakes implement it without importing the SDKs. `FirebaseAuthClientAdapter` wraps `FirebaseAuth` and `GoogleSignIn.instance` (v7.x singleton API) and is only instantiated in `main.dart`. `initialize()` calls `signInAnonymously()` if no current user is cached, ensuring every install has a Firebase UID from first launch; the call is fire-and-forget in `main.dart` so it does not block `runApp`. `authStateChangesProvider` is a `StreamProvider<AuthState>` that re-emits whenever the Firebase Auth state changes.

**Device ID:** `lib/infrastructure/device/` provides a stable per-install UUID. `SharedPreferencesDeviceIdService` generates a UUID v4 on first call, persists it under the `habit_loop_device_id` key, and returns the same value on all subsequent calls. The device ID is used to prefix new pact IDs (`{deviceId}-{uuid}`) for global uniqueness across devices, making multi-device sync conflict-free.

**Crashlytics:** `lib/infrastructure/crashlytics/` wraps crash reporting. Activation is gated on `kReleaseMode` in `main.dart`, so debug and test runs fall back to `NoopCrashlyticsService`. The `CrashlyticsService` interface has a strict no-throw contract: implementations must swallow any exceptions raised by the underlying SDK so that crash reporting failures can never crash the app themselves. The interface exposes `log()` for breadcrumbs and `setCustomKey()` for runtime context (active pact count, current screen, locale). The raw `FirebaseCrashlytics` SDK is referenced in `main.dart` in two ways: via `FirebaseCrashlyticsClientAdapter` for the Riverpod provider override, and directly in the `FlutterError.onError` / `PlatformDispatcher.instance.onError` global error handlers (which must be installed before `runApp`, before the Riverpod container exists). The rest of the app depends only on the abstract interface.

**Logging:** `lib/infrastructure/logging/` provides structured local logging via `talker_flutter`. The `LogService` interface exposes `debug()`, `info()`, `warning()`, `error()`, and `logLocal()` (for PII-safe local-only detail). `TalkerLogService` is active in debug and profile builds only; `NoopLogService` is the default in release and tests. The in-app log overlay is gated on `kDebugMode`. **PII rule:** never pass user-entered text (habit names, notes, stop reasons) to `CrashlyticsService` — only field lengths, IDs, counts, and enum values. Local `logLocal()` calls may include more detail since logs never leave the device.

**Firestore:** `lib/infrastructure/firestore/` wraps the Firestore remote storage layer. `FirestoreClient` is the abstract interface with a strict no-throw contract; all methods accept only plain `Map<String, dynamic>` data so no Firestore SDK types leak into the interface — test fakes implement it without importing `cloud_firestore`. The flat document schema mirrors the local SQLite structure: `/users/{userId}/pacts/{pactId}` and `/users/{userId}/showups/{showupId}`. `NoopFirestoreClient` is the default; the production `FirestoreClientAdapter` (wrapping the real SDK, only instantiated in `main.dart`) is planned for WU3. `firestoreClientProvider` follows the same optional-override pattern as other infrastructure providers. `Pact` and `Showup` domain models carry two sync-tracking fields: `dirty: bool` (default `true` — queued for sync) and `syncedAt: DateTime?` (null until the first successful Firestore write); both are persisted in SQLite schema v2 columns `dirty INTEGER NOT NULL DEFAULT 1` and `synced_at INTEGER`.

**Persistence:** `lib/infrastructure/persistence/` contains the database lifecycle manager and the codec/mapper utilities used by the SQLite repository implementations. `HabitLoopDatabase` owns the sqflite `Database` singleton for production use; exposes `HabitLoopDatabase.runMigrations` (creates the full current schema) and `HabitLoopDatabase.runUpgradeMigrations` (incremental v1→v2 upgrade) as public statics so tests can apply them to in-memory `databaseFactoryFfi` databases without going through the file-backed singleton; provides `@visibleForTesting openForTesting()` as a convenience wrapper. Current schema version: **2** (v2 added `dirty` and `synced_at` to both `pacts` and `showups`). `ScheduleCodec`, `PactMapper`, and `ShowupMapper` are `abstract final` classes with only `static` methods — they carry no sqflite dependency themselves (sqflite is introduced by the concrete repositories in `slices/*/data/`). `ScheduleCodec` encodes and decodes `ShowupSchedule` discriminated unions to and from a JSON string stored in the `schedule TEXT` column; its `decode` method applies a type guard before the `Map<String, dynamic>` cast so that syntactically valid but non-object JSON values produce a `FormatException` rather than an uncaught `TypeError`. `PactMapper` and `ShowupMapper` convert domain objects to column maps (for `INSERT`/`UPDATE`) and reconstruct them from row maps (for `SELECT`). All `DateTime` fields are stored as epoch milliseconds and reconstructed as **local-time** values — matching the local-time `DateTime` objects produced by `PactBuilder` and `ShowupGenerator` — so that timezones are handled correctly throughout the app.

**Notifications:** `lib/infrastructure/notifications/` wraps local notification scheduling via `flutter_local_notifications`. The `NotificationService` interface has a strict no-throw contract: all implementations must swallow exceptions internally so a notification failure can never crash the app. `FlutterLocalNotificationService` is the production implementation; it uses `zonedSchedule()` with `TZDateTime` (from the `timezone` package) for DST-safe scheduling, and `flutter_timezone` to resolve the device's current IANA timezone at runtime. Notification IDs are derived deterministically from `scheduledAt.millisecondsSinceEpoch ~/ 1000` (no mapping table needed). An in-memory `_pactNotificationIds` registry (pact ID to set of notification IDs) supports `cancelAllRemindersForPact()` without iterating the OS pending-notification list; on app restart the registry is empty and cancellation falls back to `getPendingNotifications()` filtered by the `pactId` field in each notification's payload JSON. The Android notification channel ID is `showup_reminders`. The `onDidReceiveNotificationResponse` callback is wired to `NotificationRouter.navigateToShowup` for deep-link routing; cold-start taps are deferred via `addPostFrameCallback` so the navigator is guaranteed to be mounted. `UNUserNotificationCenter.current().delegate = self` is set in `AppDelegate.swift` before `super.application(...)` because Flutter 3.x no longer sets it automatically. `FlutterLocalNotificationService` is used in **all build modes** (debug, profile, release) so notification navigation can be tested with plain `flutter run`; unit tests are unaffected because they never call `main()` and override `notificationServiceProvider` directly. The provider `notificationServiceProvider` defaults to `NoopNotificationService` and is overridden in `main.dart` via `AppContainer.overrides(...)`.

**Remote Config:** `lib/infrastructure/remote_config/` wraps feature flag resolution. The `RemoteConfigService` interface has a strict no-throw contract: all implementations must swallow exceptions internally so a Remote Config outage can never crash the app. `FirebaseRemoteConfigClient` (defined in `data/`) is an intermediate adapter interface whose methods return only plain Dart primitives -- no Firebase SDK types leak through it, so test fakes can implement it without importing `firebase_remote_config`. The raw `FirebaseRemoteConfig` SDK is confined to `FirebaseRemoteConfigClientAdapter`, which is only instantiated in `main.dart`. Activation is gated on `kReleaseMode`: debug and profile builds use `NoopRemoteConfigService`, which returns in-code defaults from `RemoteConfigDefaults`. In debug and profile builds `!kReleaseMode` controls the fetch interval to `Duration.zero` so QA can verify flag changes without the 12-hour production throttle.

## Dependencies

- [Riverpod](https://riverpod.dev/) — state management and dependency injection
- [sqflite](https://pub.dev/packages/sqflite) — local storage; `HabitLoopDatabase` manages the file-backed `Database` lifecycle; `SqlitePactRepository` and `SqliteShowupRepository` provide the production repository implementations
- [sqflite_common_ffi](https://pub.dev/packages/sqflite_common_ffi) (dev) — enables in-memory SQLite for unit tests running on macOS/Linux without a device; used in `habit_loop_database_test.dart`, `sqlite_pact_repository_test.dart`, and `sqlite_showup_repository_test.dart`
- [firebase_core](https://pub.dev/packages/firebase_core) — Firebase SDK bootstrap; `Firebase.initializeApp()` called in `main()` before `runApp`
- [firebase_auth](https://pub.dev/packages/firebase_auth) — anonymous sign-in and Google account linking; wrapped by `AuthService` in `lib/infrastructure/auth/` and wired via `authServiceProvider`. The raw `FirebaseAuth` SDK is confined to `FirebaseAuthClientAdapter`, which is only instantiated in `main.dart`
- [google_sign_in](https://pub.dev/packages/google_sign_in) — Google OAuth credential acquisition for account linking; used exclusively inside `FirebaseAuthClientAdapter` via the v7.x singleton `GoogleSignIn.instance`; lazily initialized on first `linkWithGoogleCredential()` call
- [firebase_analytics](https://pub.dev/packages/firebase_analytics) — analytics / event tracking; wrapped by `AnalyticsService` in `lib/infrastructure/analytics/` and wired via `analyticsServiceProvider`. The raw `FirebaseAnalytics` SDK is only touched in `main.dart` through `FirebaseAnalyticsClientAdapter`; the rest of the app depends on the `AnalyticsService` interface
- [firebase_crashlytics](https://pub.dev/packages/firebase_crashlytics) — crash reporting; wrapped by `CrashlyticsService` in `lib/infrastructure/crashlytics/` and provided via `crashlyticsServiceProvider`. `FlutterError.onError` and `PlatformDispatcher.instance.onError` are wired in `main.dart` under `kReleaseMode` only. The raw `FirebaseCrashlytics` SDK is referenced in `main.dart` via `FirebaseCrashlyticsClientAdapter` (for the provider override) and directly in the global error handlers (which run before `runApp`)
- [firebase_remote_config](https://pub.dev/packages/firebase_remote_config) — feature flags and remote configuration; wrapped by `RemoteConfigService` in `lib/infrastructure/remote_config/` and provided via `remoteConfigServiceProvider`. The raw `FirebaseRemoteConfig` SDK is confined to `FirebaseRemoteConfigClientAdapter`, which is only instantiated in `main.dart` under `kReleaseMode`. Debug and profile builds fall back to `NoopRemoteConfigService` returning in-code defaults
- [talker_flutter](https://pub.dev/packages/talker_flutter) — structured local logging and in-app log overlay; wrapped by `LogService` in `lib/infrastructure/logging/` and provided via `logServiceProvider`. Active in debug/profile builds only; release builds use `NoopLogService`
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) — local notification scheduling; wrapped by `NotificationService` in `lib/infrastructure/notifications/` and provided via `notificationServiceProvider`. `FlutterLocalNotificationService` is used in all build modes (debug, profile, release) so notification navigation can be tested with plain `flutter run`
- [timezone](https://pub.dev/packages/timezone) — required by `flutter_local_notifications` for `TZDateTime`-based `zonedSchedule()` calls; ensures DST-safe notification scheduling times
- [flutter_timezone](https://pub.dev/packages/flutter_timezone) — resolves the device's current IANA timezone name at runtime; called during `FlutterLocalNotificationService.initialize()` to set `tz.local`
- [uuid](https://pub.dev/packages/uuid) — RFC 4122 UUID v4 generation; used by `SharedPreferencesDeviceIdService` to create the stable per-install device ID
- `lib/firebase_options.dart` — platform-specific Firebase configuration generated by `flutterfire configure`
