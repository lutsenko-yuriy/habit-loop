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

### Auth and device identity providers

| Provider | Type | Default | Overridden in production |
|---|---|---|---|
| `authServiceProvider` | `Provider<AuthService>` | `NoopAuthService` | `FirebaseAuthService` (all build modes) |
| `deviceIdServiceProvider` | `Provider<DeviceIdService>` | `NoopDeviceIdService` | `SharedPreferencesDeviceIdService` (all build modes) |
| `authStateChangesProvider` | `StreamProvider<AuthState>` | Derived from `authServiceProvider` | No override needed |

### App info providers

| Provider | Type | Default | Notes |
|---|---|---|---|
| `appVersionProvider` | `FutureProvider<String>` | `""` on failure | Resolved once from `PackageInfo.fromPlatform()` |

### Locale providers

| Provider | Type | Default | Overridden in production |
|---|---|---|---|
| `localePreferenceServiceProvider` | `Provider<LocalePreferenceService>` | `NoopLocalePreferenceService` | `SharedPreferencesLocaleService` (all build modes) |
| `localeOverrideProvider` | `StateProvider<Locale?>` | `null` (follow system) | Initialised by `AppContainer.overrides()` from saved locale |

### Infrastructure service providers

| Provider | Type | Default | Overridden in production |
|---|---|---|---|
| `analyticsServiceProvider` | `Provider<AnalyticsService>` | `NoopAnalyticsService` | `FirebaseAnalyticsService` (release builds only) |
| `crashlyticsServiceProvider` | `Provider<CrashlyticsService>` | `NoopCrashlyticsService` | `FirebaseCrashlyticsService` (release builds only) |
| `logServiceProvider` | `Provider<LogService>` | `NoopLogService` | `TalkerLogService` (debug/profile builds only) |
| `remoteConfigServiceProvider` | `Provider<RemoteConfigService>` | `NoopRemoteConfigService` | `FirebaseRemoteConfigService` (release builds only) |
| `notificationServiceProvider` | `Provider<NotificationService>` | `NoopNotificationService` | `FlutterLocalNotificationService` (all build modes) |
| `firestoreClientProvider` | `Provider<FirestoreClient>` | `NoopFirestoreClient` | `FirestoreClientAdapter` (planned for WU3) |

### Repository providers

| Provider | Type | Default | Overridden in production |
|---|---|---|---|
| `pactRepositoryProvider` | `Provider<PactRepository>` | `UnimplementedError` | `SqlitePactRepository` (production), `InMemoryPactRepository` (tests) |
| `showupRepositoryProvider` | `Provider<ShowupRepository>` | `UnimplementedError` | `SqliteShowupRepository` (production), `InMemoryShowupRepository` (tests) |
| `pactSyncRepositoryProvider` | `Provider<PactSyncRepository>` | `NoopPactSyncRepository` | Same `SqlitePactRepository` instance as `pactRepositoryProvider` |
| `showupSyncRepositoryProvider` | `Provider<ShowupSyncRepository>` | `NoopShowupSyncRepository` | Same `SqliteShowupRepository` instance as `showupRepositoryProvider` |

### Application service providers

| Provider | Type | Default | Notes |
|---|---|---|---|
| `pactTransactionServiceProvider` | `Provider<PactTransactionService>` | `UnimplementedError` | `SqlitePactTransactionService` (production); `InMemoryPactTransactionService` (tests) |
| `pactServiceProvider` | `Provider<PactService>` | Composed via `ref.watch` | No override needed — reads from repository and stats providers |
| `pactStatsServiceProvider` | `Provider<PactStatsService>` | Composed via `ref.watch` | No override needed — Riverpod caches the instance for the container lifetime (effective singleton) |
| `reminderSchedulingServiceProvider` | `Provider<ReminderSchedulingService>` | Composed via `ref.watch` | No override needed — composes notification, remote config, analytics, and locale providers |

### Sync providers

| Provider | Type | Default | Notes |
|---|---|---|---|
| `syncCircuitBreakerProvider` | `StateNotifierProvider<SyncCircuitBreaker, SyncCircuitBreakerState>` | `SyncCircuitBreakerState.closed` | No override needed — always starts closed; state is in-memory only (resets on restart) |

---

## Dependency graph

```
ProviderScope
  └── AppContainer.overrides(...)
        │
        ├── pactRepositoryProvider          ← SqlitePactRepository(db)
        ├── showupRepositoryProvider         ← SqliteShowupRepository(db)
        ├── pactSyncRepositoryProvider       ← same SqlitePactRepository instance
        ├── showupSyncRepositoryProvider     ← same SqliteShowupRepository instance
        ├── pactTransactionServiceProvider   ← SqlitePactTransactionService(db)
        │
        ├── pactServiceProvider              ← PactService(pactRepo, showupRepo, txService, statsService)
        ├── pactStatsServiceProvider         ← PactStatsService(pactRepo, showupRepo, txService)
        │
        ├── analyticsServiceProvider         ← FirebaseAnalyticsService  (release only)
        ├── crashlyticsServiceProvider       ← FirebaseCrashlyticsService (release only)
        ├── logServiceProvider               ← TalkerLogService           (debug/profile only)
        ├── remoteConfigServiceProvider      ← FirebaseRemoteConfigService (release only)
        ├── notificationServiceProvider      ← FlutterLocalNotificationService (all modes)
        ├── firestoreClientProvider          ← NoopFirestoreClient (future: FirestoreClientAdapter)
        ├── syncCircuitBreakerProvider       ← SyncCircuitBreaker (in-memory, no override)
        │
        ├── authServiceProvider              ← FirebaseAuthService (all modes)
        ├── deviceIdServiceProvider          ← SharedPreferencesDeviceIdService (all modes)
        ├── authStateChangesProvider         ← derived from authServiceProvider
        │
        ├── localePreferenceServiceProvider  ← SharedPreferencesLocaleService (all modes)
        └── localeOverrideProvider           ← StateProvider initialised from saved locale
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
