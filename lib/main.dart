import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/firebase_options.dart';
import 'package:habit_loop/infrastructure/analytics/data/firebase_analytics_client_adapter.dart';
import 'package:habit_loop/infrastructure/analytics/data/firebase_analytics_service.dart';
import 'package:habit_loop/infrastructure/analytics/providers/analytics_providers.dart';
import 'package:habit_loop/infrastructure/crashlytics/data/firebase_crashlytics_client_adapter.dart';
import 'package:habit_loop/infrastructure/crashlytics/data/firebase_crashlytics_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/providers/crashlytics_providers.dart';
import 'package:habit_loop/infrastructure/logging/data/talker_log_service.dart';
import 'package:habit_loop/infrastructure/logging/providers/log_service_providers.dart';
import 'package:habit_loop/infrastructure/persistence/habit_loop_database.dart';
import 'package:habit_loop/infrastructure/remote_config/data/firebase_remote_config_client_adapter.dart';
import 'package:habit_loop/infrastructure/remote_config/data/firebase_remote_config_service.dart';
import 'package:habit_loop/infrastructure/remote_config/providers/remote_config_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_screen.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/application/pact_transaction_service.dart';
import 'package:habit_loop/slices/pact/data/sqlite_pact_repository.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_view_model.dart';
import 'package:habit_loop/slices/showup/data/sqlite_showup_repository.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';
import 'package:sqflite/sqflite.dart';
import 'package:talker_flutter/talker_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kReleaseMode) {
    // Forward Flutter framework errors to Crashlytics.
    FlutterError.onError = (details) {
      try {
        unawaited(
          FirebaseCrashlytics.instance.recordFlutterFatalError(details),
        );
      } catch (_) {}
    };
    // Forward Dart async / platform errors to Crashlytics.
    PlatformDispatcher.instance.onError = (error, stack) {
      try {
        // recordError returns a Future but the callback must return bool synchronously.
        // Errors from the native layer are caught here to prevent a re-entrant error loop.
        unawaited(
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true),
        );
      } catch (_) {}
      return true;
    };

    // Set session-scoped custom keys so every crash report carries locale and
    // session start time. These are fire-and-forget diagnostics; failures are
    // swallowed by the no-throw CrashlyticsService contract.
    try {
      unawaited(FirebaseCrashlytics.instance.setCustomKey('locale', Platform.localeName));
      unawaited(
        FirebaseCrashlytics.instance.setCustomKey('app_session_start_time', DateTime.now().toIso8601String()),
      );
    } catch (_) {}
  }

  // Initialise Remote Config before runApp so flags are ready on first frame.
  // Failures are swallowed by the service — they must not prevent app launch.
  FirebaseRemoteConfigService? remoteConfigService;
  if (kReleaseMode) {
    try {
      final remoteConfigClient = FirebaseRemoteConfigClientAdapter(
        FirebaseRemoteConfig.instance,
      );
      remoteConfigService = FirebaseRemoteConfigService(remoteConfigClient);
      await remoteConfigService.initialize();
    } catch (_) {
      // initialize() already swallows, but guard here as well so a constructor
      // failure cannot prevent runApp.
      remoteConfigService = null;
    }
  }

  // Instantiate Talker for local logging. The in-app overlay is shown only in
  // debug mode (kDebugMode guard inside TalkerLogService). This is intentionally
  // wired in debug and profile builds only; release builds fall back to the
  // NoopLogService default from logServiceProvider.
  final talker = kReleaseMode ? null : Talker();
  final logService = talker != null ? TalkerLogService(talker) : null;

  // Open the SQLite database and construct the shared repository instances.
  // HabitLoopDatabase.instance.database is a Future-based singleton: concurrent
  // callers all share the same Future so only one openDatabase call is ever made.
  final Database db = await HabitLoopDatabase.instance.database;
  final pactRepo = SqlitePactRepository(db);
  final showupRepo = SqliteShowupRepository(db);
  final txService = PactTransactionService(db);

  runApp(
    ProviderScope(
      overrides: [
        // Wire TalkerLogService in debug/profile builds for local visibility.
        // Release builds use the NoopLogService default from logServiceProvider.
        if (logService != null) logServiceProvider.overrideWithValue(logService),

        // Only send analytics in release builds — debug/profile use NoopAnalyticsService.
        if (kReleaseMode)
          analyticsServiceProvider.overrideWithValue(
            FirebaseAnalyticsService(
              FirebaseAnalyticsClientAdapter(FirebaseAnalytics.instance),
            ),
          ),
        // Only send crash reports in release builds — debug/profile use NoopCrashlyticsService.
        if (kReleaseMode)
          crashlyticsServiceProvider.overrideWithValue(
            FirebaseCrashlyticsService(
              FirebaseCrashlyticsClientAdapter(FirebaseCrashlytics.instance),
            ),
          ),
        // Only wire Firebase Remote Config in release builds; debug/profile fall
        // back to NoopRemoteConfigService which returns in-code defaults.
        if (kReleaseMode && remoteConfigService != null)
          remoteConfigServiceProvider.overrideWithValue(remoteConfigService),

        // Wire the shared SQLite-backed repository instances. All slices that
        // need a PactRepository or ShowupRepository read these providers.
        pactRepositoryProvider.overrideWithValue(pactRepo),
        showupRepositoryProvider.overrideWithValue(showupRepo),
        pactTransactionServiceProvider.overrideWithValue(txService),

        // Per-slice repository providers wired to the same SQLite instances.
        // These remain because PactListViewModel and ShowupDetailViewModel still
        // read them directly — they will be consolidated to pactServiceProvider
        // in a future cleanup pass.
        pactListRepositoryProvider.overrideWithValue(pactRepo),
        pactListShowupRepositoryProvider.overrideWithValue(showupRepo),
        showupDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
        showupDetailPactRepositoryProvider.overrideWithValue(pactRepo),
      ],
      child: const HabitLoopApp(),
    ),
  );
}

class HabitLoopApp extends StatelessWidget {
  const HabitLoopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Loop',
      theme: HabitLoopTheme.materialTheme,
      darkTheme: HabitLoopTheme.darkMaterialTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        return CupertinoTheme(
          data: HabitLoopTheme.cupertinoTheme.copyWith(
            brightness: Theme.of(context).brightness,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const DashboardScreen(),
    );
  }
}
