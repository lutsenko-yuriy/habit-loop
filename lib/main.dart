import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
import 'package:habit_loop/infrastructure/auth/contracts/auth_service.dart';
import 'package:habit_loop/infrastructure/auth/data/firebase_auth_client_adapter.dart';
import 'package:habit_loop/infrastructure/auth/data/firebase_auth_service.dart';
import 'package:habit_loop/infrastructure/auth/data/first_launch_auth_fix.dart';
import 'package:habit_loop/infrastructure/auth/data/local_auth_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/contracts/crashlytics_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/data/firebase_crashlytics_client_adapter.dart';
import 'package:habit_loop/infrastructure/crashlytics/data/firebase_crashlytics_service.dart';
import 'package:habit_loop/infrastructure/crashlytics/data/noop_crashlytics_service.dart';
import 'package:habit_loop/infrastructure/device/data/shared_preferences_device_id_service.dart';
import 'package:habit_loop/infrastructure/firestore/data/fake_firestore_client.dart';
import 'package:habit_loop/infrastructure/firestore/data/fault_injecting_firestore_client.dart';
import 'package:habit_loop/infrastructure/firestore/data/firebase_firestore_client_adapter.dart';
import 'package:habit_loop/infrastructure/injections/app_container.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/locale/data/shared_preferences_locale_service.dart';
import 'package:habit_loop/infrastructure/logging/data/talker_log_service.dart';
import 'package:habit_loop/infrastructure/notifications/contracts/notification_service.dart';
import 'package:habit_loop/infrastructure/notifications/data/flutter_local_notification_service.dart';
import 'package:habit_loop/infrastructure/notifications/data/noop_notification_service.dart';
import 'package:habit_loop/infrastructure/notifications/data/notification_router.dart';
import 'package:habit_loop/infrastructure/onboarding/data/shared_preferences_onboarding_service.dart';
import 'package:habit_loop/infrastructure/persistence/habit_loop_database.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_defaults.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_override_store.dart';
import 'package:habit_loop/infrastructure/remote_config/contracts/remote_config_service.dart';
import 'package:habit_loop/infrastructure/remote_config/data/firebase_remote_config_client_adapter.dart';
import 'package:habit_loop/infrastructure/remote_config/data/firebase_remote_config_service.dart';
import 'package:habit_loop/infrastructure/remote_config/data/noop_remote_config_service.dart';
import 'package:habit_loop/infrastructure/remote_config/data/overridable_remote_config_service.dart';
import 'package:habit_loop/infrastructure/remote_config/data/shared_preferences_remote_config_override_store.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/navigation/notification_navigator.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_refresh_signal.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_screen.dart';
import 'package:habit_loop/slices/pact/data/sqlite_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/sqlite_pact_transaction_service.dart';
import 'package:habit_loop/slices/reminder/analytics/reminder_analytics_events.dart';
import 'package:habit_loop/slices/showup/data/sqlite_showup_repository.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:talker_flutter/talker_flutter.dart';

// Navigator key wired into MaterialApp so notification callbacks can push
// routes without a BuildContext (they fire outside the widget tree).
final _navigatorKey = GlobalKey<NavigatorState>();

// Increments dashboardRefreshSignalProvider inside the ProviderScope that owns
// DashboardViewModel.
void _signalDashboardRefresh() {
  final ctx = _navigatorKey.currentContext;
  if (ctx == null) return;
  ProviderScope.containerOf(ctx).read(dashboardRefreshSignalProvider.notifier).state++;
}

// On iOS, flutter_local_notifications calls onDidReceiveNotificationResponse
// during initialize() (before runApp). Both the deferred callback and the
// getAppLaunchDetails() path in main() would push a route for the same tap —
// this flag ensures only one of the two paths navigates. Reset after first frame.
bool _notificationNavigationHandled = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kReleaseMode) {
    FlutterError.onError = (details) {
      try {
        unawaited(FirebaseCrashlytics.instance.recordFlutterFatalError(details));
      } catch (_) {}
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      try {
        // recordError is async but this callback must return bool synchronously.
        // Errors from the native layer are caught here to prevent a re-entrant loop.
        unawaited(FirebaseCrashlytics.instance.recordError(error, stack, fatal: true));
      } catch (_) {}
      return true;
    };
    try {
      unawaited(FirebaseCrashlytics.instance.setCustomKey('locale', Platform.localeName));
      unawaited(
        FirebaseCrashlytics.instance.setCustomKey('app_session_start_time', DateTime.now().toIso8601String()),
      );
    } catch (_) {}
  }

  // Initialise Remote Config before runApp so flags are ready on first frame.
  RemoteConfigService? remoteConfigService;
  RemoteConfigOverrideStore? remoteConfigOverrideStore;
  if (kReleaseMode) {
    try {
      final remoteConfigClient = FirebaseRemoteConfigClientAdapter(
        FirebaseRemoteConfig.instance,
      );
      final firebaseService = FirebaseRemoteConfigService(remoteConfigClient);
      await firebaseService.initialize();
      remoteConfigService = firebaseService;
    } catch (_) {
      // initialize() already swallows; guard here so a constructor failure
      // cannot prevent runApp.
      remoteConfigService = null;
    }
  } else {
    try {
      final prefs = await SharedPreferences.getInstance();
      final store = SharedPreferencesRemoteConfigOverrideStore(prefs);
      remoteConfigOverrideStore = store;
      remoteConfigService = OverridableRemoteConfigService(
        inner: NoopRemoteConfigService(),
        store: store,
      );
    } catch (_) {}
  }

  // Read debug_backend before constructing auth/Firestore — decision needed at startup.
  final debugBackend = !kReleaseMode
      ? (remoteConfigOverrideStore?.getOverride('debug_backend') ?? RemoteConfigDefaults.debugBackend)
      : RemoteConfigDefaults.debugBackend;
  final useLocalBackend = debugBackend == 'local';

  final CrashlyticsService earlycrashlytics = kReleaseMode
      ? FirebaseCrashlyticsService(FirebaseCrashlyticsClientAdapter(FirebaseCrashlytics.instance))
      : NoopCrashlyticsService();

  // Declared early so the warm-start notification callback can close over it.
  // Assigned after the database opens; the `?.` guard is a safety net if the
  // callback fires before the DB try-block completes.
  FirebaseAnalyticsService? notificationAnalyticsService;

  // Initialise before runApp so the plugin and Android channel are ready on the
  // first frame. Used in all build modes so navigation can be tested with
  // `flutter run` — unit tests override notificationServiceProvider directly.
  NotificationService notificationService = NoopNotificationService();
  {
    final realService = FlutterLocalNotificationService(earlycrashlytics);
    try {
      realService.setNotificationResponseCallback((NotificationResponse response) {
        if (kDebugMode) {
          debugPrint('[Notif] response received — actionId=${response.actionId} payload=${response.payload}');
        }
        final parsed = NotificationRouter.parsePayload(response.payload);
        if (parsed == null) {
          if (kDebugMode) debugPrint('[Notif] payload parse failed — skipping navigation');
          return;
        }

        // Notification body tap → navigate to showup detail.
        // On iOS, this callback fires during initialize() for cold starts —
        // _navigatorKey.currentState is null, so we must defer to the next frame.
        final coldStart = _navigatorKey.currentState == null;
        if (kDebugMode) debugPrint('[Notif] body tap — coldStart=$coldStart showupId=${parsed.showupId}');
        if (!coldStart) {
          // Warm start — navigator ready, push now.
          _notificationNavigationHandled = true;
          unawaited(NotificationNavigator.navigateToShowup(
            navigatorKey: _navigatorKey,
            showupId: parsed.showupId,
            onReturn: _signalDashboardRefresh,
          ));
        } else {
          // Cold start — the navigator is not yet mounted when this callback
          // fires. On debug/JIT builds the first post-frame callback can fire
          // before runApp's warm-up frame has attached the NavigatorState, so
          // we retry on each subsequent frame until the navigator is ready.
          // Ten attempts is well above any real initialisation delay; if the
          // navigator is still null after that, navigation is silently dropped.
          final deferredShowupId = parsed.showupId;
          void tryNavigate(int attemptsLeft) {
            if (_notificationNavigationHandled || attemptsLeft <= 0) return;
            if (_navigatorKey.currentState == null) {
              if (kDebugMode) {
                debugPrint('[Notif] cold-start: navigator not ready, retrying (attempts left: $attemptsLeft)');
              }
              // ignore: avoid_dynamic_calls — local recursive fn, not dynamic dispatch
              WidgetsBinding.instance.addPostFrameCallback((_) => tryNavigate(attemptsLeft - 1));
              return;
            }
            if (kDebugMode) debugPrint('[Notif] cold-start deferred push — showupId=$deferredShowupId');
            _notificationNavigationHandled = true;
            unawaited(NotificationNavigator.navigateToShowup(
              navigatorKey: _navigatorKey,
              showupId: deferredShowupId,
              onReturn: _signalDashboardRefresh,
            ));
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (kDebugMode) {
              debugPrint('[Notif] cold-start deferred callback — handled=$_notificationNavigationHandled');
            }
            tryNavigate(10);
          });
        }
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
      // initialize() already swallows; guard here so a constructor failure
      // cannot prevent runApp.
      notificationService = NoopNotificationService();
    }
  }

  // Load saved locale before runApp so the initial frame uses the correct locale.
  SharedPreferencesLocaleService? localeService;
  try {
    final prefs = await SharedPreferences.getInstance();
    localeService = SharedPreferencesLocaleService(prefs);
  } catch (_) {
    localeService = null;
  }

  final AuthService authService =
      useLocalBackend ? LocalAuthService() : FirebaseAuthService(FirebaseAuthClientAdapter(FirebaseAuth.instance));
  SharedPreferencesDeviceIdService? deviceIdService;
  try {
    deviceIdService = SharedPreferencesDeviceIdService(
      await SharedPreferences.getInstance(),
    );
  } catch (_) {
    deviceIdService = null;
  }

  // If the database cannot be opened, fall back to an error screen.
  try {
    final Database db = await HabitLoopDatabase.instance.database;
    final pactRepo = SqlitePactRepository(db);
    final showupRepo = SqliteShowupRepository(db);
    final txService = SqlitePactTransactionService(db);

    // Assign notificationAnalyticsService so the warm-start callback (closed
    // over above) can fire events. Also used in the cold-start post-frame callback.
    notificationAnalyticsService =
        kReleaseMode ? FirebaseAnalyticsService(FirebaseAnalyticsClientAdapter(FirebaseAnalytics.instance)) : null;
    final analyticsService = notificationAnalyticsService;

    SharedPreferencesOnboardingService? onboardingService;
    try {
      onboardingService = SharedPreferencesOnboardingService(
        await SharedPreferences.getInstance(),
      );
    } catch (_) {
      onboardingService = null;
    }

    // Shared instance so seed-data UI operations immediately affect the live sync service.
    final FakeFirestoreClient? sharedFakeFirestore = (!kReleaseMode && useLocalBackend) ? FakeFirestoreClient() : null;

    final overrides = await AppContainer.overrides(
      pactRepository: pactRepo,
      showupRepository: showupRepo,
      pactSyncRepository: pactRepo,
      showupSyncRepository: showupRepo,
      transactionService: txService,
      logService: !kReleaseMode ? TalkerLogService(Talker()) : null,
      analyticsService: analyticsService,
      crashlyticsService: kReleaseMode
          ? FirebaseCrashlyticsService(
              FirebaseCrashlyticsClientAdapter(FirebaseCrashlytics.instance),
            )
          : null,
      remoteConfigService: remoteConfigService,
      remoteConfigOverrideStore: remoteConfigOverrideStore,
      notificationService: notificationService,
      localePreferenceService: localeService,
      onboardingPreferenceService: onboardingService,
      authService: authService,
      deviceIdService: deviceIdService,
      firestoreClient: kReleaseMode
          ? FirebaseFirestoreClientAdapter(FirebaseFirestore.instance)
          : FaultInjectingFirestoreClient(
              inner:
                  useLocalBackend ? sharedFakeFirestore! : FirebaseFirestoreClientAdapter(FirebaseFirestore.instance),
              rc: remoteConfigService ?? NoopRemoteConfigService(),
            ),
      fakeFirestoreClient: (!kReleaseMode && useLocalBackend) ? sharedFakeFirestore : null,
      debugBackendAtStartup: !kReleaseMode ? debugBackend : null,
    );

    runApp(
      ProviderScope(
        overrides: overrides,
        child: HabitLoopApp(navigatorKey: _navigatorKey),
      ),
    );

    // Sign in after runApp so a slow network never delays the first frame.
    // Pull remote changes only after initialize() so userId is guaranteed non-null.
    unawaited(() async {
      if (useLocalBackend) {
        await authService.initialize();
      } else {
        final prefs = await SharedPreferences.getInstance();
        await clearStaleKeychainIfFirstLaunch(authService: authService, prefs: prefs);
        await authService.initialize();
        // ignore: use_build_context_synchronously — _navigatorKey is the root
        // navigator, which is never disposed during the app lifetime.
        final syncCtx = _navigatorKey.currentContext;
        if (syncCtx != null) {
          // ignore: use_build_context_synchronously
          unawaited(ProviderScope.containerOf(syncCtx).read(syncServiceProvider).pullRemoteChanges());
        }
      }
    }());

    // Cold-start dedup: if onDidReceiveNotificationResponse already deferred a
    // push via addPostFrameCallback, _notificationNavigationHandled is true when
    // this callback fires (both are on the same first frame, in registration order).
    // Skip getAppLaunchDetails() to avoid a double push; reset so warm-start taps
    // after this are not suppressed.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (kDebugMode) debugPrint('[Notif] post-frame callback — handled=$_notificationNavigationHandled');
      if (_notificationNavigationHandled) {
        _notificationNavigationHandled = false;
        return;
      }
      final launchInfo = await notificationService.getAppLaunchDetails();
      if (kDebugMode) {
        debugPrint(
            '[Notif] getAppLaunchDetails — didLaunch=${launchInfo?.didNotificationLaunchApp} payload=${launchInfo?.payload}');
      }
      if (launchInfo != null && launchInfo.didNotificationLaunchApp && launchInfo.payload != null) {
        final parsed = NotificationRouter.parsePayload(launchInfo.payload);
        if (parsed != null) {
          _notificationNavigationHandled = true;
          unawaited(NotificationNavigator.navigateToShowup(
            navigatorKey: _navigatorKey,
            showupId: parsed.showupId,
            onReturn: _signalDashboardRefresh,
          ));
          unawaited(
            analyticsService?.logEvent(
              AppOpenedFromNotificationEvent(
                pactId: parsed.pactId,
                showupId: parsed.showupId,
                coldStart: true,
              ),
            ),
          );
          _notificationNavigationHandled = false;
        }
      }
    });
  } catch (e, st) {
    try {
      unawaited(earlycrashlytics.recordError(e, st));
    } catch (_) {}
    debugPrint('Failed during app initialisation: $e\n$st');
    runApp(const _DatabaseErrorApp());
  }
}

class HabitLoopApp extends ConsumerWidget {
  const HabitLoopApp({super.key, required this.navigatorKey});

  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeOverride = ref.watch(localeOverrideProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Habit Loop',
      theme: HabitLoopTheme.materialTheme,
      darkTheme: HabitLoopTheme.darkMaterialTheme,
      themeMode: ThemeMode.system,
      // Non-null locale bypasses Flutter's localeResolutionCallback entirely —
      // intentional for user-forced overrides. Any future localeResolutionCallback
      // will be silently ignored when localeOverride is non-null.
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

// Shown when the SQLite database cannot be opened (e.g. disk full).
// English-only — localisation delegates are unavailable at this point.
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
