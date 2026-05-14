/// Single canonical file declaring every app-wide Riverpod provider.
///
/// All infrastructure-level providers live here. View models and application
/// services import from this file — never from the old per-service
/// `providers/` subdirectories.
///
/// Slice-local providers (e.g. `pactCreationTodayProvider`,
/// `pactDetailNowProvider`, `showupDetailNowProvider`, `todayProvider`,
/// `hasActivePactsProvider`) remain in their respective view-model files
/// because they are scoped to a single screen.
library;

import 'dart:io' show Platform;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/pact/pact_sync_repository.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/domain/showup/showup_sync_repository.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
import 'package:habit_loop/infrastructure/analytics/data/noop_analytics_service.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_service.dart';
import 'package:habit_loop/infrastructure/auth/contracts/auth_state.dart';
import 'package:habit_loop/infrastructure/auth/data/noop_auth_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/contracts/crashlytics_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/data/noop_crashlytics_service.dart';
import 'package:habit_loop/infrastructure/device/contracts/device_id_service.dart';
import 'package:habit_loop/infrastructure/device/data/noop_device_id_service.dart';
import 'package:habit_loop/infrastructure/firestore/contracts/firestore_client.dart';
import 'package:habit_loop/infrastructure/firestore/data/noop_firestore_client.dart';
import 'package:habit_loop/infrastructure/locale/contracts/locale_preference_service.dart';
import 'package:habit_loop/infrastructure/locale/data/noop_locale_preference_service.dart';
import 'package:habit_loop/infrastructure/logging/contracts/log_service.dart';
import 'package:habit_loop/infrastructure/logging/data/noop_log_service.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:habit_loop/infrastructure/notifications/data/noop_notification_service.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';
import 'package:habit_loop/infrastructure/remote_config/data/noop_remote_config_service.dart';
import 'package:habit_loop/infrastructure/sync/firestore_sync_service.dart';
import 'package:habit_loop/infrastructure/sync/noop_sync_service.dart';
import 'package:habit_loop/infrastructure/sync/sync_circuit_breaker.dart';
import 'package:habit_loop/infrastructure/sync/sync_service.dart';
import 'package:habit_loop/slices/pact/application/pact_service.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';
import 'package:habit_loop/slices/pact/data/noop_pact_sync_repository.dart';
import 'package:habit_loop/slices/reminder/application/reminder_scheduling_service.dart';
import 'package:habit_loop/slices/showup/data/noop_showup_sync_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ---------------------------------------------------------------------------
// Auth and device identity providers
// ---------------------------------------------------------------------------

/// Provides the active [AuthService] to the app.
///
/// Defaults to [NoopAuthService] so tests and environments without Firebase
/// Auth work without additional setup. Overridden in `main.dart` via
/// [AppContainer.overrides] with [FirebaseAuthService] in all build modes.
final authServiceProvider = Provider<AuthService>((ref) => NoopAuthService());

/// Provides the active [DeviceIdService] to the app.
///
/// Defaults to [NoopDeviceIdService] so tests work without SharedPreferences.
/// Overridden in `main.dart` via [AppContainer.overrides] with
/// [SharedPreferencesDeviceIdService].
final deviceIdServiceProvider = Provider<DeviceIdService>(
  (ref) => NoopDeviceIdService(),
);

/// Stream of [AuthState] changes from the active [AuthService].
///
/// Watched by the sync status UI (WU6) to react to sign-in / sign-out events.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

// ---------------------------------------------------------------------------
// App info providers
// ---------------------------------------------------------------------------

/// Provides the app version string, e.g. `"v1.2.3 (45)"`.
///
/// Resolved once by [PackageInfo.fromPlatform] and cached for the container
/// lifetime. Returns an empty string on failure so version display is
/// simply omitted rather than crashing.
final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return 'v${info.version} (${info.buildNumber})';
  } catch (_) {
    return '';
  }
});

// ---------------------------------------------------------------------------
// Locale providers
// ---------------------------------------------------------------------------

/// Provides the active [LocalePreferenceService] to the app.
///
/// Defaults to [NoopLocalePreferenceService] so tests and environments
/// without SharedPreferences work without additional setup. Overridden in
/// `main.dart` via [AppContainer.overrides] with [SharedPreferencesLocaleService].
final localePreferenceServiceProvider = Provider<LocalePreferenceService>(
  (ref) => NoopLocalePreferenceService(),
);

/// Nullable locale override provider.
///
/// `null` means "follow the system locale" — `MaterialApp.locale = null` lets
/// Flutter resolve the locale via [AppLocalizations.supportedLocales]
/// automatically.
///
/// On startup, `main.dart` loads the saved locale and initialises this provider
/// to that value (or leaves it `null` when no saved locale exists). The
/// language picker in the dashboard reads and writes this provider so that
/// locale changes take effect immediately without an app restart.
final localeOverrideProvider = StateProvider<Locale?>((ref) => null);

// ---------------------------------------------------------------------------
// Infrastructure service providers
// ---------------------------------------------------------------------------

/// Provides the active [AnalyticsService] to the app.
///
/// Defaults to [NoopAnalyticsService] so tests and non-Firebase environments
/// work without any additional setup. Overridden in `main.dart` via
/// [AppContainer.overrides] with [FirebaseAnalyticsService] in release builds.
final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => NoopAnalyticsService(),
);

/// Provides the active [CrashlyticsService] to the app.
///
/// Defaults to [NoopCrashlyticsService] so tests and non-Firebase environments
/// work without any additional setup. Overridden in `main.dart` via
/// [AppContainer.overrides] with [FirebaseCrashlyticsService] in release builds.
final crashlyticsServiceProvider = Provider<CrashlyticsService>(
  (ref) => NoopCrashlyticsService(),
);

/// Provides the active [LogService] to the app.
///
/// Defaults to [NoopLogService] — silent and safe for tests. Overridden in
/// `main.dart` via [AppContainer.overrides] with [TalkerLogService] in
/// debug/profile builds.
///
/// Do NOT override in release builds; the noop keeps talker_flutter out of the
/// release binary.
final logServiceProvider = Provider<LogService>((ref) => NoopLogService());

/// Provides the active [RemoteConfigService] to the app.
///
/// Defaults to [NoopRemoteConfigService] so tests and non-Firebase environments
/// return in-code defaults. Overridden in `main.dart` via
/// [AppContainer.overrides] with [FirebaseRemoteConfigService] in release builds.
final remoteConfigServiceProvider = Provider<RemoteConfigService>(
  (ref) => NoopRemoteConfigService(),
);

/// Provides the active [NotificationService] to the app.
///
/// Defaults to [NoopNotificationService] so tests and debug/profile builds
/// work without the real `flutter_local_notifications` plugin. Overridden in
/// `main.dart` via [AppContainer.overrides] with [FlutterLocalNotificationService]
/// in release builds.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NoopNotificationService(),
);

// ---------------------------------------------------------------------------
// Persistence / repository providers
// ---------------------------------------------------------------------------

/// Canonical [PactRepository] provider.
///
/// Throws [UnimplementedError] by default — must be overridden by
/// [AppContainer.overrides] in `main.dart` with a [SqlitePactRepository]
/// instance, and in tests with an [InMemoryPactRepository].
final pactRepositoryProvider = Provider<PactRepository>((ref) {
  throw UnimplementedError('pactRepositoryProvider must be overridden in main.dart');
});

/// Canonical [ShowupRepository] provider.
///
/// Throws [UnimplementedError] by default — must be overridden by
/// [AppContainer.overrides] in `main.dart` with a [SqliteShowupRepository]
/// instance, and in tests with an [InMemoryShowupRepository].
final showupRepositoryProvider = Provider<ShowupRepository>((ref) {
  throw UnimplementedError('showupRepositoryProvider must be overridden in main.dart');
});

/// Canonical [PactSyncRepository] provider.
///
/// Defaults to [NoopPactSyncRepository] so tests and environments without a
/// real database work without additional setup. Overridden in `main.dart` via
/// [AppContainer.overrides] with the same [SqlitePactRepository] instance
/// used for [pactRepositoryProvider].
final pactSyncRepositoryProvider = Provider<PactSyncRepository>(
  (ref) => const NoopPactSyncRepository(),
);

/// Canonical [ShowupSyncRepository] provider.
///
/// Defaults to [NoopShowupSyncRepository] so tests and environments without a
/// real database work without additional setup. Overridden in `main.dart` via
/// [AppContainer.overrides] with the same [SqliteShowupRepository] instance
/// used for [showupRepositoryProvider].
final showupSyncRepositoryProvider = Provider<ShowupSyncRepository>(
  (ref) => const NoopShowupSyncRepository(),
);

// ---------------------------------------------------------------------------
// Application service providers
// ---------------------------------------------------------------------------

/// Provides [PactTransactionService] to the app.
///
/// Throws [UnimplementedError] by default — must be overridden by
/// [AppContainer.overrides] in `main.dart` with a
/// [SqlitePactTransactionService] instance, and in tests with an
/// [InMemoryPactTransactionService].
final pactTransactionServiceProvider = Provider<PactTransactionService>((ref) {
  throw UnimplementedError('pactTransactionServiceProvider must be overridden in main.dart');
});

/// Provides [PactService] by composing the three lower-level providers and the
/// [PactStatsService] so that [PactService.updatePact] can notify the cache
/// when a pact transitions to [PactStatus.completed].
///
/// Works regardless of whether the lower-level providers are backed by
/// in-memory (test) or SQLite (production) implementations.
final pactServiceProvider = Provider<PactService>((ref) {
  return PactService(
    pactRepository: ref.watch(pactRepositoryProvider),
    showupRepository: ref.watch(showupRepositoryProvider),
    transactionService: ref.watch(pactTransactionServiceProvider),
    pactStatsService: ref.watch(pactStatsServiceProvider),
    syncService: ref.watch(syncServiceProvider),
  );
});

/// Provides [PactStatsService] by composing the repository and transaction
/// service providers.
///
/// Riverpod caches the instance for the lifetime of the container, making it
/// effectively a singleton.
final pactStatsServiceProvider = Provider<PactStatsService>((ref) {
  return PactStatsService(
    pactRepository: ref.watch(pactRepositoryProvider),
    showupRepository: ref.watch(showupRepositoryProvider),
    transactionService: ref.watch(pactTransactionServiceProvider),
    syncService: ref.watch(syncServiceProvider),
  );
});

/// Provides the active [FirestoreClient] to the app.
///
/// Defaults to [NoopFirestoreClient] so tests and offline scenarios work
/// without the `cloud_firestore` SDK. Overridden in `main.dart` via
/// [AppContainer.overrides] with [FirestoreClientAdapter] in all build modes
/// once the user is signed in.
final firestoreClientProvider = Provider<FirestoreClient>(
  (ref) => NoopFirestoreClient(),
);

/// Provides [ReminderSchedulingService] as a singleton.
///
/// Composes [notificationServiceProvider], [remoteConfigServiceProvider],
/// [analyticsServiceProvider], and [localePreferenceServiceProvider].
/// [AppLocalizations] is resolved internally by the service from the saved
/// locale preference — callers no longer pass a BuildContext or l10n object.
final reminderSchedulingServiceProvider = Provider<ReminderSchedulingService>((ref) {
  return ReminderSchedulingService(
    notificationService: ref.watch(notificationServiceProvider),
    remoteConfig: ref.watch(remoteConfigServiceProvider),
    analytics: ref.watch(analyticsServiceProvider),
    localePreference: ref.watch(localePreferenceServiceProvider),
    isIOS: Platform.isIOS,
  );
});

// ---------------------------------------------------------------------------
// Connectivity provider
// ---------------------------------------------------------------------------

/// Stream of [ConnectivityResult] lists from `connectivity_plus`.
///
/// Emits the current connectivity status immediately on first listen, then
/// re-emits whenever the device's network state changes. Used by
/// [SyncStatusViewModel] to derive the [SyncUiState.noInternet] state.
///
/// Defaults to `[ConnectivityResult.wifi]` while loading so the UI optimistically
/// assumes connectivity rather than flashing a "no internet" state on startup.
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) async* {
  final connectivity = Connectivity();
  yield await connectivity.checkConnectivity();
  yield* connectivity.onConnectivityChanged;
});

// ---------------------------------------------------------------------------
// Sync infrastructure providers
// ---------------------------------------------------------------------------

/// Provides the [SyncCircuitBreaker] that governs all Firestore network requests.
///
/// State is in-memory only and resets to [SyncCircuitBreakerState.closed] on every app
/// restart. WU4 / WU5 sync operations check [SyncCircuitBreaker.canRequest]
/// before making any Firestore call; WU6 (sync-status UI) watches this
/// provider to display the current sync health.
///
/// No override is needed — the circuit breaker always starts Closed.
final syncCircuitBreakerProvider = StateNotifierProvider<SyncCircuitBreaker, SyncCircuitBreakerState>(
  (ref) => SyncCircuitBreaker(),
);

/// Provides the [SyncService] implementation.
///
/// Defaults to [NoopSyncService] when [firestoreClientProvider] resolves to
/// [NoopFirestoreClient] (i.e. in tests), but composes the real
/// [FirestoreSyncService] when all dependencies are wired.
///
/// No [AppContainer.overrides] entry is needed — this provider is fully
/// self-composing from already-declared providers.
final syncServiceProvider = Provider<SyncService>((ref) {
  return FirestoreSyncService(
    firestoreClient: ref.watch(firestoreClientProvider),
    authService: ref.watch(authServiceProvider),
    circuitBreaker: ref.watch(syncCircuitBreakerProvider.notifier),
    pactSyncRepository: ref.watch(pactSyncRepositoryProvider),
    showupSyncRepository: ref.watch(showupSyncRepositoryProvider),
    pactRepository: ref.watch(pactRepositoryProvider),
    showupRepository: ref.watch(showupRepositoryProvider),
  );
});
