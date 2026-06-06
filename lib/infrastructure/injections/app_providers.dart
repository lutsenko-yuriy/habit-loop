// All infrastructure-level providers live here. Slice-local providers remain
// in their respective view-model files because they are scoped to a single screen.
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
import 'package:habit_loop/infrastructure/onboarding/contracts/onboarding_preference_service.dart';
import 'package:habit_loop/infrastructure/onboarding/data/noop_onboarding_service.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_override_store.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';
import 'package:habit_loop/infrastructure/remote_config/data/noop_remote_config_override_store.dart';
import 'package:habit_loop/infrastructure/remote_config/data/noop_remote_config_service.dart';
import 'package:habit_loop/infrastructure/sync/firestore_sync_service.dart';
import 'package:habit_loop/infrastructure/sync/sync_circuit_breaker.dart';
import 'package:habit_loop/infrastructure/sync/sync_service.dart';
import 'package:habit_loop/slices/pact/application/pact_service.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';
import 'package:habit_loop/slices/pact/data/noop_pact_sync_repository.dart';
import 'package:habit_loop/slices/reminder/application/reminder_scheduling_service.dart';
import 'package:habit_loop/slices/showup/application/showup_generation_service.dart';
import 'package:habit_loop/slices/showup/data/noop_showup_sync_repository.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ---------------------------------------------------------------------------
// Auth and device identity providers
// ---------------------------------------------------------------------------

final authServiceProvider = Provider<AuthService>((ref) => NoopAuthService());

final deviceIdServiceProvider = Provider<DeviceIdService>(
  (ref) => NoopDeviceIdService(),
);

/// Stream of [AuthState] changes — watched by the sync status UI.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// The `debug_backend` value active at startup.
///
/// The RC overrides screen compares the pending value against this to show the
/// restart-required banner only when the backend would actually change.
/// Debug/profile only — always `'real'` in release builds.
final debugBackendAtStartupProvider = Provider<String>(
  (ref) => RemoteConfigDefaults.debugBackend,
);

// ---------------------------------------------------------------------------
// App info providers
// ---------------------------------------------------------------------------

/// Returns `"vX.Y.Z (N)"` or `""` on failure.
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

final localePreferenceServiceProvider = Provider<LocalePreferenceService>(
  (ref) => NoopLocalePreferenceService(),
);

final onboardingPreferenceServiceProvider = Provider<OnboardingPreferenceService>(
  (ref) => const NoopOnboardingService(),
);

/// `null` = follow system locale; non-null = user-forced language.
final localeOverrideProvider = StateProvider<Locale?>((ref) => null);

/// Held `true` while sign-in + data-pull completes — prevents a flash of the
/// empty dashboard if [isAnonymous] transitions to `false` before pacts load.
final onboardingSignInLoadingProvider = StateProvider<bool>((ref) => false);

// ---------------------------------------------------------------------------
// Infrastructure service providers
// ---------------------------------------------------------------------------

final analyticsServiceProvider = Provider<AnalyticsService>(
  (ref) => NoopAnalyticsService(),
);

final crashlyticsServiceProvider = Provider<CrashlyticsService>(
  (ref) => NoopCrashlyticsService(),
);

// Do NOT override in release builds — keeps talker_flutter out of the release binary.
final logServiceProvider = Provider<LogService>((ref) => NoopLogService());

final remoteConfigServiceProvider = Provider<RemoteConfigService>(
  (ref) => NoopRemoteConfigService(),
);

final remoteConfigOverrideStoreProvider = Provider<RemoteConfigOverrideStore>(
  (ref) => const NoopRemoteConfigOverrideStore(),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NoopNotificationService(),
);

// ---------------------------------------------------------------------------
// Persistence / repository providers
// ---------------------------------------------------------------------------

/// Must be overridden in main.dart and tests — throws otherwise.
final pactRepositoryProvider = Provider<PactRepository>((ref) {
  throw UnimplementedError('pactRepositoryProvider must be overridden in main.dart');
});

/// Must be overridden in main.dart and tests — throws otherwise.
final showupRepositoryProvider = Provider<ShowupRepository>((ref) {
  throw UnimplementedError('showupRepositoryProvider must be overridden in main.dart');
});

final pactSyncRepositoryProvider = Provider<PactSyncRepository>(
  (ref) => const NoopPactSyncRepository(),
);

final showupSyncRepositoryProvider = Provider<ShowupSyncRepository>(
  (ref) => const NoopShowupSyncRepository(),
);

// ---------------------------------------------------------------------------
// Application service providers
// ---------------------------------------------------------------------------

/// Must be overridden in main.dart and tests — throws otherwise.
final pactTransactionServiceProvider = Provider<PactTransactionService>((ref) {
  throw UnimplementedError('pactTransactionServiceProvider must be overridden in main.dart');
});

final pactServiceProvider = Provider<PactService>((ref) {
  return PactService(
    pactRepository: ref.watch(pactRepositoryProvider),
    showupRepository: ref.watch(showupRepositoryProvider),
    transactionService: ref.watch(pactTransactionServiceProvider),
    pactStatsService: ref.watch(pactStatsServiceProvider),
    syncService: ref.watch(syncServiceProvider),
  );
});

final pactStatsServiceProvider = Provider<PactStatsService>((ref) {
  return PactStatsService(
    pactRepository: ref.watch(pactRepositoryProvider),
    showupRepository: ref.watch(showupRepositoryProvider),
    transactionService: ref.watch(pactTransactionServiceProvider),
    syncService: ref.watch(syncServiceProvider),
  );
});

final firestoreClientProvider = Provider<FirestoreClient>(
  (ref) => NoopFirestoreClient(),
);

/// `null` in release builds and when real backend is active.
/// Debug seed-data screen checks this to offer "Regenerate remote pacts".
// ignore: avoid_dynamic_calls
final fakeFirestoreClientProvider = Provider<Object?>((ref) => null);

final showupGenerationServiceProvider = Provider<ShowupGenerationService>((ref) {
  return ShowupGenerationService(repository: ref.watch(showupRepositoryProvider));
});

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

/// `true` when at least one non-none interface is active; defaults to `true`
/// while loading so the UI never flashes "no internet" on startup.
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  final initial = await connectivity.checkConnectivity();
  yield !initial.every((r) => r == ConnectivityResult.none);
  yield* connectivity.onConnectivityChanged.map(
    (results) => !results.every((r) => r == ConnectivityResult.none),
  );
});

// ---------------------------------------------------------------------------
// Sync infrastructure providers
// ---------------------------------------------------------------------------

/// Threshold read once from Remote Config at construction time (`sync_max_consecutive_failures`).
/// Resets to Closed on every app restart.
final syncCircuitBreakerProvider = StateNotifierProvider<SyncCircuitBreaker, SyncCircuitBreakerState>(
  (ref) {
    final rc = ref.read(remoteConfigServiceProvider);
    final threshold = rc.getInt('sync_max_consecutive_failures');
    return SyncCircuitBreaker(
      maxConsecutiveFailures: threshold > 0 ? threshold : RemoteConfigDefaults.syncMaxConsecutiveFailures,
    );
  },
);

// Self-composing from already-declared providers — no AppContainer.overrides entry needed.
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
