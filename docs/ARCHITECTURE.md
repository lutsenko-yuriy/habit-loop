# Architecture

Vertical-slice architecture where each slice is a feature from @docs/PRODUCT_SPEC.md, with three layers per slice: domain, data, and UI.

## Directory structure

```
lib/
├── main.dart                          # App entry point (runApp)
├── l10n/                              # ARB source files + generated/ output
├── analytics/                         # Cross-cutting analytics infrastructure (shared across all features)
│   ├── domain/                        # AnalyticsEvent (abstract base), AnalyticsScreen, AnalyticsService interface
│   ├── data/                          # FirebaseAnalyticsService, FirebaseAnalyticsClientAdapter, NoopAnalyticsService
│   └── providers/                     # analyticsServiceProvider (Riverpod)
├── crashlytics/                       # Cross-cutting crash reporting infrastructure (shared across all features)
│   ├── domain/
│   │   └── crashlytics_service.dart            # abstract CrashlyticsService interface (no-throw contract)
│   ├── data/
│   │   ├── firebase_crashlytics_service.dart       # real implementation (swallows exceptions)
│   │   ├── firebase_crashlytics_client_adapter.dart # wraps FirebaseCrashlytics SDK; only used in main.dart
│   │   └── noop_crashlytics_service.dart           # default no-op
│   └── providers/
│       └── crashlytics_providers.dart  # crashlyticsServiceProvider (Provider<CrashlyticsService>)
└── features/
    ├── dashboard/                     # Home screen: calendar strip, showup list, pacts panel
    │   ├── domain/
    │   ├── data/
    │   └── ui/ (generic/, ios/, android/)
    ├── pact/                          # Pact creation wizard + pact detail screen
    │   ├── domain/
    │   ├── data/
    │   ├── analytics/                 # PactCreatedEvent, PactStoppedEvent
    │   └── ui/ (generic/, ios/, android/)
    ├── showup/                        # Showup model, generation, repository, stats
    │   ├── domain/
    │   ├── data/
    │   ├── analytics/                 # ShowupMarkedDoneEvent, ShowupMarkedFailedEvent, ShowupAutoFailedEvent
    │   └── ui/ (generic/, ios/, android/)
    └── reminder/                      # Notification scheduling (not yet implemented)
        ├── domain/
        ├── data/
        └── ui/ (generic/, ios/, android/)

test/
├── analytics/                         # Mirrors lib/analytics/
│   ├── domain/
│   ├── data/
│   └── fake_analytics_service.dart    # Shared fake for tests that assert on analytics calls
├── crashlytics/                       # Mirrors lib/crashlytics/
│   ├── data/
│   │   ├── firebase_crashlytics_service_test.dart
│   │   └── noop_crashlytics_service_test.dart
│   └── fake_crashlytics_service.dart  # Shared fake for test overrides
└── features/                          # Mirrors lib/features/
    ├── dashboard/ (domain/, ui/)
    ├── pact/ (analytics/, data/, domain/, ui/)
    └── showup/ (analytics/, data/, domain/, ui/)
```

## Layers

### Domain
Core business logic. No dependencies on data, UI, or infrastructure.
- Models: `Pact`, `PactStatus`, `Showup`, `ShowupStatus`, `ShowupSchedule`, `PactStats`
- Repository interfaces: `PactRepository`, `ShowupRepository`
- Generators: `ShowupGenerator`, `ShowupDateUtils`

### Data
Storage and persistence. Implements repository interfaces from domain.
- Currently: `InMemoryPactRepository`, `InMemoryShowupRepository` (sqflite implementations planned — see @docs/BACKLOG.md)

### UI
Platform-split presentation:
- `generic/` — view models (Riverpod notifiers) and shared state classes
- `ios/` — Cupertino widgets
- `android/` — Material widgets

### Analytics

`lib/analytics/` is top-level cross-cutting infrastructure shared by all features, which is why it lives alongside `lib/features/` and `lib/l10n/` rather than inside `features/`. It contains the abstract base class, service interface, Firebase adapter, noop adapter, and Riverpod provider. It has no `ui/` directory because it contains no widgets — the provider lives under `providers/` instead.

Each feature vertical may contain an `analytics/` subdirectory (e.g. `features/pact/analytics/`, `features/showup/analytics/`) with event classes extending `AnalyticsEvent`. This keeps event definitions co-located with the domain they describe.

### Crashlytics

`lib/crashlytics/` follows the same cross-cutting top-level pattern as `lib/analytics/`: it lives alongside `lib/features/` rather than inside a feature vertical because crash reporting is shared by the entire app. It has no `ui/` directory (no widgets) — the Riverpod provider lives under `providers/` instead. Activation is gated on `kReleaseMode` in `main.dart`, so debug and test runs fall back to `NoopCrashlyticsService`. The `CrashlyticsService` interface has a strict no-throw contract: implementations must swallow any exceptions raised by the underlying SDK so that crash reporting failures can never crash the app themselves. The raw `FirebaseCrashlytics` SDK is referenced in `main.dart` in two ways: via `FirebaseCrashlyticsClientAdapter` for the Riverpod provider override, and directly in the `FlutterError.onError` / `PlatformDispatcher.instance.onError` global error handlers (which must be installed before `runApp`, before the Riverpod container exists). The rest of the app depends only on the abstract interface.

## Dependencies

- [Riverpod](https://riverpod.dev/) — state management and dependency injection
- [sqflite](https://pub.dev/packages/sqflite) — local storage (dependency declared, real implementations pending)
- [firebase_core](https://pub.dev/packages/firebase_core) — Firebase SDK bootstrap; `Firebase.initializeApp()` called in `main()` before `runApp`
- [firebase_analytics](https://pub.dev/packages/firebase_analytics) — analytics / event tracking; wrapped by `AnalyticsService` in `lib/analytics/` and wired via `analyticsServiceProvider`. The raw `FirebaseAnalytics` SDK is only touched in `main.dart` through `FirebaseAnalyticsClientAdapter`; the rest of the app depends on the `AnalyticsService` interface
- [firebase_crashlytics](https://pub.dev/packages/firebase_crashlytics) — crash reporting; wrapped by `CrashlyticsService` in `lib/crashlytics/` and provided via `crashlyticsServiceProvider`. `FlutterError.onError` and `PlatformDispatcher.instance.onError` are wired in `main.dart` under `kReleaseMode` only. The raw `FirebaseCrashlytics` SDK is referenced in `main.dart` via `FirebaseCrashlyticsClientAdapter` (for the provider override) and directly in the global error handlers (which run before `runApp`)
- `lib/firebase_options.dart` — platform-specific Firebase configuration generated by `flutterfire configure`
