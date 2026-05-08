import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show
        AndroidInitializationSettings,
        DarwinInitializationSettings,
        FlutterLocalNotificationsPlugin,
        InitializationSettings,
        NotificationResponse;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
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
import 'package:habit_loop/infrastructure/notifications/contracts/notification_constants.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:habit_loop/infrastructure/notifications/data/flutter_local_notification_service.dart';
import 'package:habit_loop/infrastructure/notifications/data/noop_notification_service.dart';
import 'package:habit_loop/infrastructure/notifications/data/notification_router.dart';
import 'package:habit_loop/infrastructure/persistence/habit_loop_database.dart';
import 'package:habit_loop/infrastructure/remote_config/data/firebase_remote_config_client_adapter.dart';
import 'package:habit_loop/infrastructure/remote_config/data/firebase_remote_config_service.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/navigation/notification_navigator.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_screen.dart';
import 'package:habit_loop/slices/pact/data/sqlite_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/sqlite_pact_transaction_service.dart';
import 'package:habit_loop/slices/reminder/analytics/reminder_analytics_events.dart';
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

/// Top-level [ProviderContainer] used for foreground notification callbacks
/// that fire outside the widget tree (e.g. "Mark done" from warm-start).
///
/// Assigned in [main] after the overrides list is computed — same overrides
/// as the [ProviderScope] so Riverpod providers (e.g. [pactStatsServiceProvider])
/// are correctly populated. The `?.` guards in the callback are a safety net
/// in case the callback fires before [main] completes.
ProviderContainer? _container;

/// Guards against double navigation when both [onDidReceiveNotificationResponse]
/// and the cold-start [getAppLaunchDetails] path would each push a
/// [ShowupDetailScreen] for the same tap.
///
/// On iOS, [flutter_local_notifications] calls [onDidReceiveNotificationResponse]
/// during [FlutterLocalNotificationsPlugin.initialize] (before [runApp]) for
/// cold-start notification taps. At that point [_navigatorKey.currentState] is
/// null, so we defer navigation to a [WidgetsBinding.addPostFrameCallback].
/// The [getAppLaunchDetails] path in [main] fires its own [addPostFrameCallback]
/// and could push a second route. This flag ensures only one of the two paths
/// actually navigates. It resets to `false` after the cold-start frame so
/// subsequent warm-start taps are not suppressed.
bool _notificationNavigationHandled = false;

/// Background notification response handler for Android.
///
/// Called by [flutter_local_notifications] in a **separate background isolate**
/// when the user acts on a notification action button while the app is not in
/// the foreground (e.g. taps "Mark done" from the notification tray while the
/// app is in the background or killed state).
///
/// **Constraints:**
/// - Must be a top-level function annotated with `@pragma('vm:entry-point')`.
/// - Cannot access Riverpod providers — the isolate has no ProviderScope.
/// - Cannot access the global `_navigatorKey` — UI is not mounted.
/// - Dependencies must be constructed directly (no DI).
///
/// **Note:** This handler cannot be unit-tested in the Flutter test harness
/// because it runs in a background isolate managed by the OS. Integration
/// testing on a real device is required to verify end-to-end behaviour.
@pragma('vm:entry-point')
void _notificationBackgroundHandler(NotificationResponse response) {
  // Only handle the "mark_done" action — ignore taps on the notification body
  // (those are handled by the warm-start onDidReceiveNotificationResponse).
  if (response.actionId != NotificationConstants.markDoneActionId) return;

  final parsed = NotificationRouter.parsePayload(response.payload);
  if (parsed == null) return;

  // Mark the showup done without Riverpod. We construct the SQLite repository
  // directly using the production HabitLoopDatabase singleton.
  //
  // TODO(HAB-13-WU5): Update PactStats after marking done. Constructing
  // PactStatsService in a background isolate requires both the pact repository
  // and the showup repository, which adds complexity and risk of SQLite
  // contention. For now, stats are refreshed on next foreground launch when
  // PactDetailViewModel.load() is called.
  unawaited(_markShowupDoneFromBackground(parsed.showupId, parsed.pactId));
}

/// Marks a showup as done from the background isolate.
///
/// Opens the production SQLite database, loads the showup by ID, updates its
/// status to [ShowupStatus.done], and persists the change.
///
/// Also fires [ShowupMarkedDoneFromNotificationEvent] analytics in release
/// builds (via a freshly constructed [FirebaseAnalyticsService]).
Future<void> _markShowupDoneFromBackground(String showupId, String pactId) async {
  try {
    // Reuse the production database singleton. On Android, the background
    // isolate shares the same app process when the app is in the background,
    // so the singleton's file path is correct.
    final db = await HabitLoopDatabase.instance.database;
    final showupRepo = SqliteShowupRepository(db);

    final Showup? showup = await showupRepo.getShowupById(showupId);
    if (showup == null) return; // Already deleted or never persisted.
    if (showup.status != ShowupStatus.pending) return; // Already resolved.

    final updated = Showup(
      id: showup.id,
      pactId: showup.pactId,
      scheduledAt: showup.scheduledAt,
      duration: showup.duration,
      status: ShowupStatus.done,
      note: showup.note,
    );
    await showupRepo.updateShowup(updated);

    // Cancel both the reminder and deadline notifications for this showup.
    // The ID formulas must stay in sync with [NotificationConstants] — the
    // single source of truth shared between this handler and
    // [FlutterLocalNotificationService].
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      // Re-initialise minimally for cancellation only (no callbacks needed).
      await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      await plugin.cancel(NotificationConstants.reminderNotificationId(showupId));
      await plugin.cancel(NotificationConstants.deadlineNotificationId(showupId));
    } catch (_) {
      // Cancellation failures must never crash the background handler.
    }

    // Fire analytics in release builds only.
    if (kReleaseMode) {
      try {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      } catch (_) {
        // Already initialised or init failed — proceed anyway.
      }
      try {
        final analytics = FirebaseAnalyticsService(
          FirebaseAnalyticsClientAdapter(FirebaseAnalytics.instance),
        );
        await analytics.logEvent(ShowupMarkedDoneFromNotificationEvent(pactId: pactId));
      } catch (_) {
        // Analytics failures must never crash the background handler.
      }
    }
  } catch (_) {
    // Background handlers must not throw — swallow all errors silently.
  }
}

/// Marks a showup as done from the foreground warm-start callback.
///
/// Unlike [_markShowupDoneFromBackground], this runs on the **main isolate**
/// where [_container] (a [ProviderContainer] with production overrides) is
/// available. Using Riverpod ensures [PactStatsService] cache is invalidated
/// correctly and the UI reflects the change without a manual reload.
///
/// Falls back to [_markShowupDoneFromBackground] if [_container] is not yet
/// initialised (safety net for the unlikely case the callback fires before
/// [main] completes).
Future<void> _markShowupDoneFromForeground(String showupId, String pactId) async {
  final container = _container;
  if (container == null) {
    // Container not yet ready — fall back to the background path.
    await _markShowupDoneFromBackground(showupId, pactId);
    return;
  }
  try {
    final showupRepo = container.read(showupRepositoryProvider);
    final pactStatsService = container.read(pactStatsServiceProvider);
    final notificationService = container.read(notificationServiceProvider);
    final analyticsService = container.read(analyticsServiceProvider);

    final Showup? showup = await showupRepo.getShowupById(showupId);
    if (showup == null) return; // Already deleted or never persisted.
    if (showup.status != ShowupStatus.pending) return; // Idempotency guard — already resolved.

    // persistShowupStatus atomically updates the showup status in the DB and
    // refreshes the PactStatsService in-memory cache in one call.
    await pactStatsService.persistShowupStatus(showup: showup, status: ShowupStatus.done);

    // Cancel both reminder and deadline notifications for this showup.
    await notificationService.cancelShowupReminder(showupId);

    // Fire analytics event.
    unawaited(analyticsService.logEvent(ShowupMarkedDoneFromNotificationEvent(pactId: pactId)));
  } catch (_) {
    // Foreground callback failures must be swallowed — analytics/UI staleness
    // is preferable to a visible crash.
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The background notification handler (_notificationBackgroundHandler) is
  // registered on the FlutterLocalNotificationService instance during the
  // notification service setup block below (before initialize() is called).
  // It is an Android-only path; iOS action responses always use the foreground
  // onDidReceiveNotificationResponse callback.

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

  // Declare analyticsService early so the warm-start notification callback can
  // close over it. The variable is assigned below (inside the try block after
  // the database opens) before any user interaction can fire the callback.
  // Using a nullable reference here is safe: the callback guards with `?.`.
  FirebaseAnalyticsService? notificationAnalyticsService;

  // Initialise notification service before runApp so the plugin and Android
  // channel are ready when the first frame renders. The real plugin is used in
  // all build modes (debug, profile, release) so notification navigation can be
  // tested with plain `flutter run`. Unit tests are unaffected because they
  // never call main() — they override notificationServiceProvider directly.
  //
  // timezone.initializeTimeZones() and FlutterTimezone.getLocalTimezone() are
  // called inside FlutterLocalNotificationService.initialize() so this block
  // just constructs the service and awaits its initialisation.
  NotificationService notificationService = NoopNotificationService();
  {
    final realService = FlutterLocalNotificationService(earlycrashlytics);
    try {
      // Wire the background handler before initialize() so the plugin passes it
      // to the OS-spawned background isolate on Android. On iOS this path is
      // never taken — iOS always calls the foreground callback below.
      realService.setBackgroundNotificationHandler(_notificationBackgroundHandler);

      // Wire the warm-start callback before initialize() so the plugin picks
      // it up during setup. The callback parses the payload and pushes the
      // showup detail screen via the global navigator key.
      // Analytics: the callback closes over `notificationAnalyticsService` which will be
      // assigned by the time the user can interact with a notification
      // (after runApp completes). The `?.` guard is a safety net only.
      realService.setNotificationResponseCallback((NotificationResponse response) {
        debugPrint('[Notif] response received — actionId=${response.actionId} payload=${response.payload}');
        final parsed = NotificationRouter.parsePayload(response.payload);
        if (parsed == null) {
          debugPrint('[Notif] payload parse failed — skipping navigation');
          return;
        }

        if (response.actionId == NotificationConstants.markDoneActionId) {
          // The user tapped "Mark done" from the notification tray while the
          // app is in the foreground or warm-started. Use the top-level
          // ProviderContainer so PactStatsService cache is updated correctly —
          // the widget tree will reflect the change without requiring a reload.
          // Do NOT navigate to ShowupDetailScreen: the user chose to act
          // without opening the app.
          debugPrint('[Notif] mark-done action — showupId=${parsed.showupId}');
          unawaited(_markShowupDoneFromForeground(parsed.showupId, parsed.pactId));
          return;
        }

        // Default: user tapped the notification body — navigate to showup detail.
        //
        // On iOS, flutter_local_notifications invokes this callback during
        // FlutterLocalNotificationsPlugin.initialize() for cold starts (before
        // runApp mounts the widget tree). _navigatorKey.currentState is null at
        // that moment, so we must defer the push to the next frame rather than
        // dropping it. For warm starts the navigator is already mounted and the
        // push happens immediately.
        final coldStart = _navigatorKey.currentState == null;
        debugPrint('[Notif] body tap — coldStart=$coldStart showupId=${parsed.showupId}');
        if (!coldStart) {
          // Warm start — navigator ready, push now.
          _notificationNavigationHandled = true;
          NotificationNavigator.navigateToShowup(
            navigatorKey: _navigatorKey,
            showupId: parsed.showupId,
          );
        } else {
          // Cold start — defer to the first post-frame, at which point the
          // navigator will be mounted. The _notificationNavigationHandled flag
          // prevents the getAppLaunchDetails() path from also pushing a route.
          final deferredShowupId = parsed.showupId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            debugPrint('[Notif] cold-start deferred callback — handled=$_notificationNavigationHandled');
            if (!_notificationNavigationHandled) {
              _notificationNavigationHandled = true;
              NotificationNavigator.navigateToShowup(
                navigatorKey: _navigatorKey,
                showupId: deferredShowupId,
              );
            }
          });
        }
        // Fire deep-link analytics. coldStart reflects whether the navigator was
        // mounted when the callback fired — a reliable proxy for app lifecycle state.
        unawaited(
          notificationAnalyticsService?.logEvent(
            AppOpenedFromNotificationEvent(
              pactId: parsed.pactId,
              showupId: parsed.showupId,
              coldStart: coldStart,
            ),
          ),
        );
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

    // Construct (or reuse) the analytics service so it can be passed both to
    // AppContainer.overrides (for Riverpod) and to the deep-link analytics
    // events fired from the cold-start addPostFrameCallback below.
    // Also assigns `notificationAnalyticsService` so the warm-start notification callback
    // (closed over above) can fire events once the app is running.
    notificationAnalyticsService =
        kReleaseMode ? FirebaseAnalyticsService(FirebaseAnalyticsClientAdapter(FirebaseAnalytics.instance)) : null;
    final analyticsService = notificationAnalyticsService;

    // Compute overrides once and reuse them for both ProviderScope (the widget
    // tree) and _container (the top-level ProviderContainer used by the
    // foreground "Mark done" callback outside the widget tree).
    final overrides = await AppContainer.overrides(
      pactRepository: pactRepo,
      showupRepository: showupRepo,
      transactionService: txService,
      // Talker log service is active in debug and profile builds only; the
      // in-app overlay is gated on kDebugMode inside TalkerLogService.
      // Release builds fall back to the NoopLogService default.
      logService: !kReleaseMode ? TalkerLogService(Talker()) : null,
      // Only send analytics in release builds — debug/profile use NoopAnalyticsService.
      analyticsService: analyticsService,
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
    );

    // Create the top-level ProviderContainer with the same overrides so that
    // the foreground "Mark done" notification callback (_markShowupDoneFromForeground)
    // can read Riverpod providers (ShowupRepository, PactStatsService, etc.)
    // without going through the widget tree.
    _container = ProviderContainer(overrides: overrides);

    runApp(
      ProviderScope(
        overrides: overrides,
        child: HabitLoopApp(navigatorKey: _navigatorKey),
      ),
    );

    // Cold-start fallback: if the notification response callback fired during
    // initialize() and already deferred navigation via addPostFrameCallback,
    // _notificationNavigationHandled will be set to true by that deferred
    // callback before this one runs (both fire on the same first frame, in
    // registration order: the callback's defer was registered first). In that
    // case we skip getAppLaunchDetails() to avoid a double push.
    //
    // If the callback did NOT fire (e.g. Android cold start where the response
    // is not replayed during initialize()), we fall back to getAppLaunchDetails()
    // which is the correct cold-start path on Android.
    //
    // Reset _notificationNavigationHandled after this frame so future warm-start
    // taps handled solely by onDidReceiveNotificationResponse are not blocked.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('[Notif] post-frame callback — handled=$_notificationNavigationHandled');
      if (_notificationNavigationHandled) {
        // Navigation was already triggered by the deferred callback from
        // onDidReceiveNotificationResponse. Reset for next warm-start tap.
        _notificationNavigationHandled = false;
        return;
      }
      final launchInfo = await notificationService.getAppLaunchDetails();
      debugPrint(
          '[Notif] getAppLaunchDetails — didLaunch=${launchInfo?.didNotificationLaunchApp} payload=${launchInfo?.payload}');
      if (launchInfo != null && launchInfo.didNotificationLaunchApp && launchInfo.payload != null) {
        final parsed = NotificationRouter.parsePayload(launchInfo.payload);
        if (parsed != null) {
          _notificationNavigationHandled = true;
          NotificationNavigator.navigateToShowup(
            navigatorKey: _navigatorKey,
            showupId: parsed.showupId,
          );
          // Fire deep-link analytics. This is a cold start because the app was
          // launched from a killed state via notification tap.
          unawaited(
            analyticsService?.logEvent(
              AppOpenedFromNotificationEvent(
                pactId: parsed.pactId,
                showupId: parsed.showupId,
                coldStart: true,
              ),
            ),
          );
          // Reset so future warm-start taps are not blocked.
          _notificationNavigationHandled = false;
        }
      }
    });
  } catch (e, st) {
    // Record to Crashlytics so we have a stack trace in production.
    // earlycrashlytics is always constructed above (before this try block).
    try {
      unawaited(earlycrashlytics.recordError(e, st));
    } catch (_) {}
    debugPrint('Failed during app initialisation: $e\n$st');
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
