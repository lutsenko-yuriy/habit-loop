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

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/pact/pact_repository.dart';
import 'package:habit_loop/domain/showup/showup_repository.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
import 'package:habit_loop/infrastructure/analytics/data/noop_analytics_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/contracts/crashlytics_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/data/noop_crashlytics_service.dart';
import 'package:habit_loop/infrastructure/locale/contracts/locale_preference_service.dart';
import 'package:habit_loop/infrastructure/locale/data/noop_locale_preference_service.dart';
import 'package:habit_loop/infrastructure/logging/contracts/log_service.dart';
import 'package:habit_loop/infrastructure/logging/data/noop_log_service.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:habit_loop/infrastructure/notifications/data/noop_notification_service.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';
import 'package:habit_loop/infrastructure/remote_config/data/noop_remote_config_service.dart';
import 'package:habit_loop/slices/pact/application/pact_service.dart';
import 'package:habit_loop/slices/pact/application/pact_stats_service.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';
import 'package:habit_loop/slices/reminder/application/reminder_scheduling_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
