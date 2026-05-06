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

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
import 'package:habit_loop/infrastructure/analytics/data/noop_analytics_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/contracts/crashlytics_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/data/noop_crashlytics_service.dart';
import 'package:habit_loop/infrastructure/logging/contracts/log_service.dart';
import 'package:habit_loop/infrastructure/logging/data/noop_log_service.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';
import 'package:habit_loop/infrastructure/remote_config/data/noop_remote_config_service.dart';
import 'package:habit_loop/slices/pact/application/pact_service.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';

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
  );
});
