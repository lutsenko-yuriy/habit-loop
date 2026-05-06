import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/contracts/crashlytics_service.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/locale/contracts/locale_preference_service.dart';
import 'package:habit_loop/infrastructure/logging/contracts/log_service.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';

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
  /// This method is `async` because it calls [LocalePreferenceService.getSavedLocale]
  /// internally when [localePreferenceService] is provided, so the saved locale is
  /// fetched once before `runApp` and applied to [localeOverrideProvider] on the
  /// first frame without a separate async step in `main.dart`.
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
  /// - [localePreferenceService] — provided when SharedPreferences is available;
  ///   `null` falls back to [NoopLocalePreferenceService]. When non-null, the
  ///   saved locale is fetched internally via [LocalePreferenceService.getSavedLocale]
  ///   and used to populate [localeOverrideProvider]. A `null` result means the
  ///   app follows the system locale.
  static Future<List<Override>> overrides({
    required PactRepository pactRepository,
    required ShowupRepository showupRepository,
    required PactTransactionService transactionService,
    AnalyticsService? analyticsService,
    CrashlyticsService? crashlyticsService,
    LogService? logService,
    RemoteConfigService? remoteConfigService,
    LocalePreferenceService? localePreferenceService,
  }) async {
    // Fetch the saved locale before building the override list so the correct
    // locale is applied on the very first frame without an extra await in main.dart.
    Locale? initialLocale;
    if (localePreferenceService != null) {
      initialLocale = await localePreferenceService.getSavedLocale();
    }

    return [
      // Canonical repository providers.
      pactRepositoryProvider.overrideWithValue(pactRepository),
      showupRepositoryProvider.overrideWithValue(showupRepository),

      // Canonical transaction service provider.
      pactTransactionServiceProvider.overrideWithValue(transactionService),

      // Optional infrastructure services — only added when non-null.
      if (logService != null) logServiceProvider.overrideWithValue(logService),
      if (analyticsService != null) analyticsServiceProvider.overrideWithValue(analyticsService),
      if (crashlyticsService != null) crashlyticsServiceProvider.overrideWithValue(crashlyticsService),
      if (remoteConfigService != null) remoteConfigServiceProvider.overrideWithValue(remoteConfigService),

      // Locale persistence and initial locale override.
      if (localePreferenceService != null) localePreferenceServiceProvider.overrideWithValue(localePreferenceService),
      if (initialLocale != null) localeOverrideProvider.overrideWith((ref) => initialLocale!),
    ];
  }
}
