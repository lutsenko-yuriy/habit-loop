import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' show NotificationResponse;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/firebase_options.dart';
import 'package:habit_loop/infrastructure/analytics/data/firebase_analytics_client_adapter.dart';
import 'package:habit_loop/infrastructure/analytics/data/firebase_analytics_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/contracts/crashlytics_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/data/firebase_crashlytics_client_adapter.dart';
import 'package:habit_loop/infrastructure/crashlytics/data/firebase_crashlytics_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/data/noop_crashlytics_service.dart';
import 'package:habit_loop/infrastructure/injections/app_container.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/locale/data/shared_preferences_locale_service.dart';
import 'package:habit_loop/infrastructure/logging/data/talker_log_service.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:habit_loop/infrastructure/notifications/data/flutter_local_notification_service.dart';
import 'package:habit_loop/infrastructure/notifications/data/noop_notification_service.dart';
import 'package:habit_loop/infrastructure/notifications/data/notification_router.dart';
import 'package:habit_loop/infrastructure/persistence/habit_loop_database.dart';
import 'package:habit_loop/infrastructure/remote_config/data/firebase_remote_config_client_adapter.dart';
import 'package:habit_loop/infrastructure/remote_config/data/firebase_remote_config_service.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_screen.dart';
import 'package:habit_loop/slices/pact/data/sqlite_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/sqlite_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/sqlite_showup_repository.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Global navigator key used for deep-link routing from notification taps.
///
/// Passed to [HabitLoopApp] which wires it into [MaterialApp.navigatorKey].
/// [NotificationRouter.navigateToShowup] uses this key to push the showup
/// detail screen without a [BuildContext], making it safe to call from the
/// notification response callback (which fires outside the widget tree).
final _navigatorKey = GlobalKey<NavigatorState>();

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

  // Construct the crashlytics service early so it can be threaded into the
  // notification service (which needs it to report scheduling failures).
  // This mirrors the pattern used in AppContainer.overrides where a non-null
  // crashlyticsService is only wired in release builds.
  final CrashlyticsService earlycrashlytics = kReleaseMode
      ? FirebaseCrashlyticsService(FirebaseCrashlyticsClientAdapter(FirebaseCrashlytics.instance))
      : NoopCrashlyticsService();

  // Initialise notification service before runApp so the plugin and Android
  // channel are ready when the first frame renders. Only wire the real plugin
  // in release builds — debug/profile use the silent NoopNotificationService.
  //
  // timezone.initializeTimeZones() and FlutterTimezone.getLocalTimezone() are
  // called inside FlutterLocalNotificationService.initialize() so this block
  // just constructs the service and awaits its initialisation.
  NotificationService notificationService = NoopNotificationService();
  if (kReleaseMode) {
    final realService = FlutterLocalNotificationService(earlycrashlytics);
    try {
      // Wire the warm-start callback before initialize() so the plugin picks
      // it up during setup. The callback parses the payload and pushes the
      // showup detail screen via the global navigator key.
      // Analytics note: we pass 0 as minutesBeforeShowup because computing the
      // exact value requires a DB lookup (showup.scheduledAt) that is not
      // available in main.dart without async repo access.
      // TODO(HAB-13): resolve the exact minutesBeforeShowup from the repository.
      realService.setNotificationResponseCallback((NotificationResponse response) {
        final parsed = NotificationRouter.parsePayload(response.payload);
        if (parsed != null) {
          NotificationRouter.navigateToShowup(
            navigatorKey: _navigatorKey,
            showupId: parsed.showupId,
            pactId: parsed.pactId,
          );
        }
      });
      await realService.initialize();
      await realService.requestPermission();
      notificationService = realService;
    } catch (_) {
      // initialize()/requestPermission() already swallow, but guard here as
      // well so a constructor failure cannot prevent runApp.
      // Fall back to the noop — notifications simply won't work.
      notificationService = NoopNotificationService();
    }
  }

  // Load the user's saved locale preference before runApp so the initial
  // MaterialApp.locale is set correctly on the very first frame.
  // SharedPreferences.getInstance() is fast (reads from an in-memory cache
  // after the first call) and independent of the SQLite database lifecycle.
  SharedPreferencesLocaleService? localeService;
  try {
    final prefs = await SharedPreferences.getInstance();
    localeService = SharedPreferencesLocaleService(prefs);
  } catch (_) {
    // If SharedPreferences fails to initialise, fall back to system locale.
    localeService = null;
  }

  // Open the SQLite database and construct the shared repository instances.
  // HabitLoopDatabase.instance.database is a Future-based singleton: concurrent
  // callers all share the same Future so only one openDatabase call is ever made.
  //
  // If the database cannot be opened (e.g. disk full, corrupt file), fall back
  // to a minimal error screen rather than crashing to a black screen.
  try {
    final Database db = await HabitLoopDatabase.instance.database;
    final pactRepo = SqlitePactRepository(db);
    final showupRepo = SqliteShowupRepository(db);
    final txService = SqlitePactTransactionService(db);

    runApp(
      ProviderScope(
        overrides: await AppContainer.overrides(
          pactRepository: pactRepo,
          showupRepository: showupRepo,
          transactionService: txService,
          // Talker log service is active in debug and profile builds only; the
          // in-app overlay is gated on kDebugMode inside TalkerLogService.
          // Release builds fall back to the NoopLogService default.
          logService: !kReleaseMode ? TalkerLogService(Talker()) : null,
          // Only send analytics in release builds — debug/profile use NoopAnalyticsService.
          analyticsService: kReleaseMode
              ? FirebaseAnalyticsService(
                  FirebaseAnalyticsClientAdapter(FirebaseAnalytics.instance),
                )
              : null,
          // Only send crash reports in release builds — debug/profile use NoopCrashlyticsService.
          crashlyticsService: kReleaseMode
              ? FirebaseCrashlyticsService(
                  FirebaseCrashlyticsClientAdapter(FirebaseCrashlytics.instance),
                )
              : null,
          // Only wire Firebase Remote Config in release builds; debug/profile fall
          // back to NoopRemoteConfigService which returns in-code defaults.
          remoteConfigService: kReleaseMode ? remoteConfigService : null,
          // Wire the notification service. In release builds this is the real plugin;
          // in debug/profile it is the NoopNotificationService. Either way we pass it
          // so that the notificationServiceProvider is always overridden and available.
          notificationService: notificationService,
          // Wire locale persistence; AppContainer.overrides fetches the saved
          // locale internally via getSavedLocale() and populates localeOverrideProvider.
          localePreferenceService: localeService,
        ),
        child: HabitLoopApp(navigatorKey: _navigatorKey),
      ),
    );

    // Cold-start: if the app was launched by tapping a notification (i.e. the
    // app was killed), navigate to the showup detail screen after the first
    // frame is rendered and the widget tree is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final launchInfo = await notificationService.getAppLaunchDetails();
      if (launchInfo != null && launchInfo.didNotificationLaunchApp && launchInfo.payload != null) {
        final parsed = NotificationRouter.parsePayload(launchInfo.payload);
        if (parsed != null) {
          NotificationRouter.navigateToShowup(
            navigatorKey: _navigatorKey,
            showupId: parsed.showupId,
            pactId: parsed.pactId,
          );
        }
      }
    });
  } catch (e, st) {
    debugPrint('Failed to open database: $e\n$st');
    runApp(const _DatabaseErrorApp());
  }
}

class HabitLoopApp extends ConsumerWidget {
  const HabitLoopApp({super.key, required this.navigatorKey});

  /// Global navigator key used for deep-link routing from notification taps.
  ///
  /// Must be the same key instance that is passed to
  /// [NotificationRouter.navigateToShowup] in `main.dart`. Wiring it through
  /// [MaterialApp.navigatorKey] lets the notification callback resolve the
  /// current [NavigatorState] even when called outside the widget tree.
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the locale override so the entire widget tree rebuilds immediately
    // when the user picks a different language. null = follow system locale.
    final localeOverride = ref.watch(localeOverrideProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Habit Loop',
      theme: HabitLoopTheme.materialTheme,
      darkTheme: HabitLoopTheme.darkMaterialTheme,
      themeMode: ThemeMode.system,
      // Passing a non-null locale to MaterialApp suppresses Flutter's built-in
      // localeResolutionCallback and localeListResolutionCallback entirely —
      // Flutter simply uses the supplied locale without consulting those
      // callbacks. This is intentional for a user-forced override: the user
      // has explicitly chosen a language, so system negotiation is bypassed.
      // If localeResolutionCallback or localeListResolutionCallback are ever
      // added here, they will be silently ignored whenever localeOverride is
      // non-null and must be removed or adapted accordingly.
      locale: localeOverride,
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

/// Minimal fallback app shown when the SQLite database cannot be opened.
///
/// Displayed instead of a black screen when [HabitLoopDatabase.instance.database]
/// throws during startup (e.g. disk full, corrupt database file). The message is
/// English-only because the localisation delegates are not available at this
/// point — the error is a fatal infrastructure failure, not a user-facing flow.
class _DatabaseErrorApp extends StatelessWidget {
  const _DatabaseErrorApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Unable to open the app database.\n'
            'Please free up storage space and restart the app.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
