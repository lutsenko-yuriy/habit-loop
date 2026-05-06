# Dependency Injection

All app-wide Riverpod provider declarations live in
`lib/infrastructure/injections/`. `main.dart` calls `AppContainer.overrides()`
to build the full `List<Override>` passed to `ProviderScope`.

---

## Files

| File | Purpose |
|---|---|
| `lib/infrastructure/injections/app_providers.dart` | Single canonical file declaring every app-wide Riverpod provider |
| `lib/infrastructure/injections/app_container.dart` | `AppContainer` static class — builds the `List<Override>` for `ProviderScope` |

---

## Providers

### Infrastructure service providers

| Provider | Type | Default | Overridden in production |
|---|---|---|---|
| `analyticsServiceProvider` | `Provider<AnalyticsService>` | `NoopAnalyticsService` | `FirebaseAnalyticsService` (release builds only) |
| `crashlyticsServiceProvider` | `Provider<CrashlyticsService>` | `NoopCrashlyticsService` | `FirebaseCrashlyticsService` (release builds only) |
| `logServiceProvider` | `Provider<LogService>` | `NoopLogService` | `TalkerLogService` (debug/profile builds only) |
| `remoteConfigServiceProvider` | `Provider<RemoteConfigService>` | `NoopRemoteConfigService` | `FirebaseRemoteConfigService` (release builds only) |

### Repository providers

| Provider | Type | Default | Overridden in production |
|---|---|---|---|
| `pactRepositoryProvider` | `Provider<PactRepository>` | `UnimplementedError` | `SqlitePactRepository` (production), `InMemoryPactRepository` (tests) |
| `showupRepositoryProvider` | `Provider<ShowupRepository>` | `UnimplementedError` | `SqliteShowupRepository` (production), `InMemoryShowupRepository` (tests) |

### Application service providers

| Provider | Type | Default | Notes |
|---|---|---|---|
| `pactTransactionServiceProvider` | `Provider<PactTransactionService>` | `UnimplementedError` | `SqlitePactTransactionService` (production); `InMemoryPactTransactionService` (tests) |
| `pactServiceProvider` | `Provider<PactService>` | Composed via `ref.watch` | No override needed — reads from `pactRepositoryProvider`, `showupRepositoryProvider`, `pactTransactionServiceProvider` |
| `pactStatsServiceProvider` | `Provider<PactStatsService>` | Composed via `ref.watch` | No override needed — Riverpod caches the instance for the container lifetime (effective singleton) |

---

## Dependency graph

```
ProviderScope
  └── AppContainer.overrides(...)
        │
        ├── pactRepositoryProvider          ← SqlitePactRepository(db)
        ├── showupRepositoryProvider         ← SqliteShowupRepository(db)
        ├── pactTransactionServiceProvider   ← SqlitePactTransactionService(db)
        │
        ├── pactServiceProvider              ← PactService(pactRepo, showupRepo, txService)
        ├── pactStatsServiceProvider         ← PactStatsService(pactRepo, showupRepo, txService)
        │
        ├── analyticsServiceProvider         ← FirebaseAnalyticsService  (release only)
        ├── crashlyticsServiceProvider       ← FirebaseCrashlyticsService (release only)
        ├── logServiceProvider               ← TalkerLogService           (debug/profile only)
        └── remoteConfigServiceProvider      ← FirebaseRemoteConfigService (release only)
```

---

## Slice-local providers (NOT in app_providers.dart)

These providers are scoped to a single screen and remain in their view-model
files. They are intentionally excluded from `AppContainer` — they carry
screen-local state (e.g. the current clock snapshot, per-screen repository
references for tests).

| Provider | Location | Purpose |
|---|---|---|
| `pactCreationTodayProvider` | `pact_creation_view_model.dart` | Today's date for the creation wizard |
| `pactDetailNowProvider` | `pact_detail_view_model.dart` | Current time for pact detail / stop-pact |
| `showupDetailNowProvider` | `showup_detail_view_model.dart` | Current time for showup auto-fail logic |
| `todayProvider` | `dashboard_view_model.dart` | Today's date for the dashboard strip |
| `hasActivePactsProvider` | `dashboard_view_model.dart` | Whether any active pacts exist |

---

## Adding a new provider

1. Declare the provider in `lib/infrastructure/injections/app_providers.dart`.
2. If the provider requires a production override (e.g. a real database-backed
   service), add it as a parameter to `AppContainer.overrides()` in
   `lib/infrastructure/injections/app_container.dart`.
3. In `main.dart`, construct the instance and pass it to `AppContainer.overrides()`.
4. In tests, override the canonical provider in the `ProviderContainer` instead
   of declaring a parallel slice-local provider.
