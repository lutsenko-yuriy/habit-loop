import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/contracts/crashlytics_service.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/logging/contracts/log_service.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_view_model.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';

/// Composition root for the Habit Loop app.
///
/// [AppContainer.overrides] returns the full [List<Override>] consumed by
/// [ProviderScope] in `main.dart`. This class knows *which* instances to wire
/// to *which* providers; `main.dart` knows *how* to construct those instances
/// (Firebase init, kReleaseMode branching, SQLite opening).
///
/// The class is mode-agnostic: it contains no `kReleaseMode` checks. Callers
/// pass already-constructed service instances so [AppContainer] is testable
/// without importing `package:flutter/foundation.dart`.
abstract final class AppContainer {
  /// Builds the complete list of Riverpod provider overrides for production.
  ///
  /// Parameters that are `null` are omitted from the override list, meaning the
  /// corresponding provider falls back to its noop default. This is used for
  /// optional services (analytics, crashlytics, remoteConfig) that are only
  /// wired in release builds.
  ///
  /// Required parameters:
  /// - [pactRepository] — SQLite-backed [PactRepository].
  /// - [showupRepository] — SQLite-backed [ShowupRepository].
  /// - [transactionService] — SQLite-backed [PactTransactionService].
  ///
  /// Optional parameters (omitted → noop default):
  /// - [analyticsService] — only provided in release builds.
  /// - [crashlyticsService] — only provided in release builds.
  /// - [logService] — provided in debug/profile builds.
  /// - [remoteConfigService] — only provided in release builds.
  static List<Override> overrides({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    required PactTransactionService transactionService,
    AnalyticsService? analyticsService,
    CrashlyticsService? crashlyticsService,
    LogService? logService,
    RemoteConfigService? remoteConfigService,
  }) {
    return [
      // Canonical repository providers.
      pactRepositoryProvider.overrideWithValue(pactRepository),
      showupRepositoryProvider.overrideWithValue(showupRepository),

      // Canonical transaction service provider.
      pactTransactionServiceProvider.overrideWithValue(transactionService),

      // Per-slice view-model repository providers wired to the same instances.
      // These remain because PactListViewModel and ShowupDetailViewModel read
      // them directly via their own slice-local providers.
      pactListRepositoryProvider.overrideWithValue(pactRepository),
      pactListShowupRepositoryProvider.overrideWithValue(showupRepository),
      showupDetailShowupRepositoryProvider.overrideWithValue(showupRepository),
      showupDetailPactRepositoryProvider.overrideWithValue(pactRepository),

      // Optional infrastructure services — only added when non-null.
      if (logService != null) logServiceProvider.overrideWithValue(logService),
      if (analyticsService != null) analyticsServiceProvider.overrideWithValue(analyticsService),
      if (crashlyticsService != null) crashlyticsServiceProvider.overrideWithValue(crashlyticsService),
      if (remoteConfigService != null) remoteConfigServiceProvider.overrideWithValue(remoteConfigService),
    ];
  }
}
