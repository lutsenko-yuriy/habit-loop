# Architecture

Vertical-slice architecture where each slice is a feature from @docs/PRODUCT_SPEC.md, with four layers per slice: domain, application, data, and UI.

Cross-cutting infrastructure (analytics, crashlytics, remote config) lives under `lib/infrastructure/`. Pure domain models and repository interfaces shared across features live under `lib/domain/`.

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
│   │   ├── pact.dart                  # Pact model
│   │   ├── pact_status.dart           # PactStatus enum (active, stopped, completed)
│   │   ├── pact_stats.dart            # PactStats computed stats model
│   │   ├── pact_repository.dart       # PactRepository interface
│   │   ├── showup_schedule.dart       # ShowupSchedule model (daily, weekly, monthly)
│   │   └── schedule_type.dart         # ScheduleType enum
│   └── showup/
│       ├── showup.dart                # Showup model
│       ├── showup_status.dart         # ShowupStatus enum (pending, done, failed)
│       ├── showup_repository.dart     # ShowupRepository interface
│       ├── showup_generator.dart      # ShowupGenerator — deterministic showup generation from a pact schedule
│       ├── showup_date_utils.dart     # ShowupDateUtils — date arithmetic helpers
│       └── save_showups_result.dart   # SaveShowupsResult — batch-save result type
├── infrastructure/                    # Cross-cutting infrastructure shared by all features
│   ├── analytics/
│   │   ├── domain/                    # AnalyticsEvent (abstract base), AnalyticsScreen, AnalyticsService interface
│   │   ├── data/                      # FirebaseAnalyticsService, FirebaseAnalyticsClientAdapter, NoopAnalyticsService
│   │   └── providers/                 # analyticsServiceProvider (Riverpod)
│   ├── crashlytics/
│   │   ├── domain/
│   │   │   └── crashlytics_service.dart            # abstract CrashlyticsService interface (no-throw contract)
│   │   ├── data/
│   │   │   ├── firebase_crashlytics_service.dart       # real implementation (swallows exceptions)
│   │   │   ├── firebase_crashlytics_client_adapter.dart # wraps FirebaseCrashlytics SDK; only used in main.dart
│   │   │   └── noop_crashlytics_service.dart           # default no-op
│   │   └── providers/
│   │       └── crashlytics_providers.dart  # crashlyticsServiceProvider (Provider<CrashlyticsService>)
│   └── remote_config/
│       ├── domain/
│       │   ├── remote_config_service.dart          # abstract RemoteConfigService interface (no-throw contract)
│       │   └── remote_config_defaults.dart         # RemoteConfigDefaults — in-code fallback values
│       ├── data/
│       │   ├── firebase_remote_config_service.dart     # real implementation (swallows exceptions); also contains FirebaseRemoteConfigClient interface
│       │   ├── firebase_remote_config_client_adapter.dart # wraps FirebaseRemoteConfig SDK; only used in main.dart
│       │   └── noop_remote_config_service.dart         # default no-op returning in-code defaults
│       └── providers/
│           └── remote_config_providers.dart  # remoteConfigServiceProvider (Provider<RemoteConfigService>)
└── slices/
    ├── dashboard/                     # Home screen: calendar strip, showup list, pacts panel
    │   ├── analytics/                 # DashboardAnalyticsScreen
    │   └── ui/ (generic/, ios/, android/)
    ├── pact/                          # Pact creation wizard + pact detail screen
    │   ├── application/               # PactBuilder, PactCreationState, PactStatsService
    │   ├── data/                      # InMemoryPactRepository
    │   ├── analytics/                 # PactCreatedEvent, PactStoppedEvent
    │   └── ui/ (generic/, ios/, android/)
    ├── showup/                        # Showup detail, generation service
    │   ├── application/               # ShowupGenerationService
    │   ├── data/                      # InMemoryShowupRepository
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
│   ├── analytics/
│   │   ├── domain/
│   │   ├── data/
│   │   └── fake_analytics_service.dart    # Shared fake for tests that assert on analytics calls
│   ├── crashlytics/
│   │   ├── data/
│   │   │   ├── firebase_crashlytics_service_test.dart
│   │   │   └── noop_crashlytics_service_test.dart
│   │   └── fake_crashlytics_service.dart  # Shared fake for test overrides
│   └── remote_config/
│       ├── data/
│       │   ├── firebase_remote_config_service_test.dart
│       │   └── noop_remote_config_service_test.dart
│       └── fake_remote_config_service.dart  # Shared fake for test overrides
└── slices/                            # Mirrors lib/slices/
    ├── dashboard/ (analytics/, ui/)
    ├── pact/ (analytics/, application/, data/, ui/)
    └── showup/ (analytics/, application/, data/, ui/)
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
- `PactStatsService` (`slices/pact/application/`) — owns pact stats calculation, persistence, and the stop-pact transaction.
- `ShowupGenerationService` (`slices/showup/application/`) — orchestrates lazy windowed showup generation and deduplication.

### Data (`lib/slices/*/data/`)
Storage and persistence. Implements repository interfaces from `lib/domain/`.
- Currently: `InMemoryPactRepository`, `InMemoryShowupRepository` (sqflite implementations planned -- see @docs/BACKLOG.md)

### UI (`lib/slices/*/ui/`)
Platform-split presentation:
- `generic/` — view models (Riverpod notifiers), shared state classes (e.g. `DashboardState`, `PactDetailState`, `PactListState`, `ShowupDetailState`), and platform-agnostic helpers shared by both Cupertino and Material implementations (formatters, colour-role resolvers, and reusable widgets). Examples: `slices/pact/ui/generic/pact_creation_formatters.dart` (date/schedule/reminder labels), `slices/pact/ui/generic/summary_row.dart`, `slices/showup/ui/generic/showup_formatters.dart`, `slices/showup/ui/generic/showup_status_colors.dart` (Cupertino + Material palette factories mapping `ShowupStatus` to colours), `slices/showup/ui/generic/showup_status_dots.dart` (calendar-strip dot widget). Helpers that need a platform-idiom colour accept it as a parameter rather than branching on platform.
- `ios/` — Cupertino widgets
- `android/` — Material widgets

### Theme

`lib/theme/` contains the cross-platform Habit Loop visual foundation: the shared brand palette and the Material/Cupertino theme data applied from `HabitLoopApp`. Feature UI should consume the theme via `Theme.of(context)`, `CupertinoTheme.of(context)`, or the shared semantic colors when a reusable status color is needed. Launcher icon assets under `assets/app_icon/`, `ios/Runner/Assets.xcassets/AppIcon.appiconset/`, and `android/app/src/main/res/mipmap-*/` use the same palette so the installed app icon matches the in-app design language.

### Infrastructure (`lib/infrastructure/`)

Cross-cutting services (analytics, crashlytics, remote config) that are shared by the entire app. Each service follows the same internal structure: `domain/` (abstract interface with a no-throw contract), `data/` (Firebase-backed implementation + noop fallback), `providers/` (Riverpod provider defaulting to the noop).

Each slice vertical may contain an `analytics/` subdirectory (e.g. `slices/pact/analytics/`, `slices/showup/analytics/`) with event classes extending `AnalyticsEvent`. This keeps event definitions co-located with the domain they describe.

**Analytics:** `lib/infrastructure/analytics/` contains the abstract base class (`AnalyticsEvent`, `AnalyticsScreen`), service interface (`AnalyticsService`), Firebase adapter, noop adapter, and Riverpod provider. It has no `ui/` directory because it contains no widgets.

**Crashlytics:** `lib/infrastructure/crashlytics/` wraps crash reporting. Activation is gated on `kReleaseMode` in `main.dart`, so debug and test runs fall back to `NoopCrashlyticsService`. The `CrashlyticsService` interface has a strict no-throw contract: implementations must swallow any exceptions raised by the underlying SDK so that crash reporting failures can never crash the app themselves. The raw `FirebaseCrashlytics` SDK is referenced in `main.dart` in two ways: via `FirebaseCrashlyticsClientAdapter` for the Riverpod provider override, and directly in the `FlutterError.onError` / `PlatformDispatcher.instance.onError` global error handlers (which must be installed before `runApp`, before the Riverpod container exists). The rest of the app depends only on the abstract interface.

**Remote Config:** `lib/infrastructure/remote_config/` wraps feature flag resolution. The `RemoteConfigService` interface has a strict no-throw contract: all implementations must swallow exceptions internally so a Remote Config outage can never crash the app. `FirebaseRemoteConfigClient` (defined in `data/`) is an intermediate adapter interface whose methods return only plain Dart primitives -- no Firebase SDK types leak through it, so test fakes can implement it without importing `firebase_remote_config`. The raw `FirebaseRemoteConfig` SDK is confined to `FirebaseRemoteConfigClientAdapter`, which is only instantiated in `main.dart`. Activation is gated on `kReleaseMode`: debug and profile builds use `NoopRemoteConfigService`, which returns in-code defaults from `RemoteConfigDefaults`. In debug and profile builds `!kReleaseMode` controls the fetch interval to `Duration.zero` so QA can verify flag changes without the 12-hour production throttle.

## Dependencies

- [Riverpod](https://riverpod.dev/) — state management and dependency injection
- [sqflite](https://pub.dev/packages/sqflite) — local storage (dependency declared, real implementations pending)
- [firebase_core](https://pub.dev/packages/firebase_core) — Firebase SDK bootstrap; `Firebase.initializeApp()` called in `main()` before `runApp`
- [firebase_analytics](https://pub.dev/packages/firebase_analytics) — analytics / event tracking; wrapped by `AnalyticsService` in `lib/infrastructure/analytics/` and wired via `analyticsServiceProvider`. The raw `FirebaseAnalytics` SDK is only touched in `main.dart` through `FirebaseAnalyticsClientAdapter`; the rest of the app depends on the `AnalyticsService` interface
- [firebase_crashlytics](https://pub.dev/packages/firebase_crashlytics) — crash reporting; wrapped by `CrashlyticsService` in `lib/infrastructure/crashlytics/` and provided via `crashlyticsServiceProvider`. `FlutterError.onError` and `PlatformDispatcher.instance.onError` are wired in `main.dart` under `kReleaseMode` only. The raw `FirebaseCrashlytics` SDK is referenced in `main.dart` via `FirebaseCrashlyticsClientAdapter` (for the provider override) and directly in the global error handlers (which run before `runApp`)
- [firebase_remote_config](https://pub.dev/packages/firebase_remote_config) — feature flags and remote configuration; wrapped by `RemoteConfigService` in `lib/infrastructure/remote_config/` and provided via `remoteConfigServiceProvider`. The raw `FirebaseRemoteConfig` SDK is confined to `FirebaseRemoteConfigClientAdapter`, which is only instantiated in `main.dart` under `kReleaseMode`. Debug and profile builds fall back to `NoopRemoteConfigService` returning in-code defaults
- `lib/firebase_options.dart` — platform-specific Firebase configuration generated by `flutterfire configure`
