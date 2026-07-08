import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/firestore/contracts/firestore_client.dart';
import 'package:habit_loop/infrastructure/injections/app_container.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/main.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../test/infrastructure/analytics/fake_analytics_service.dart';
import '../test/infrastructure/auth/fake_auth_service.dart';
import '../test/infrastructure/locale/fake_locale_preference_service.dart';
import '../test/infrastructure/notifications/fake_notification_service.dart';
import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import '../test/infrastructure/sync/fake_sync_service.dart';

/// Full-stack test harness that boots [HabitLoopApp] with:
/// - in-memory repository doubles (avoids sqflite_common_ffi isolate
///   deadlock inside Flutter's FakeAsync test environment)
/// - fake Firebase services (auth, analytics, notifications, sync)
///
/// SQLite persistence is already well-tested via unit tests in
/// `test/slices/pact/data/` and `test/slices/showup/data/`. The harness
/// focuses on end-to-end UI flow correctness rather than the storage layer.
///
/// Usage:
/// ```dart
/// late AppHarness h;
/// setUp(() async { h = await AppHarness.create(tester); });
/// tearDown(() => h.dispose());
/// ```
class AppHarness {
  AppHarness._({
    required this.pactRepo,
    required this.showupRepo,
    required this.auth,
    required this.analytics,
    required this.notifications,
    required this.syncService,
    required this.localeService,
    required this.navigatorKey,
    this.firestoreClient,
  });

  final InMemoryPactRepository pactRepo;
  final InMemoryShowupRepository showupRepo;
  final FakeAuthService auth;
  final FakeAnalyticsService analytics;
  final FakeNotificationService notifications;
  final FakeSyncService syncService;
  final FakeLocalePreferenceService localeService;

  /// Navigator key wired into [HabitLoopApp]. Use this in tests to drive
  /// navigation programmatically (e.g. to simulate a notification tap).
  final GlobalKey<NavigatorState> navigatorKey;

  /// Non-null when the harness was created with a custom [FirestoreClient].
  ///
  /// In this mode the real [FirestoreSyncService] is used (wired via the
  /// self-composing [syncServiceProvider]) so that [pullRemoteChanges] runs
  /// end-to-end against the provided client. [syncService] is still allocated
  /// but is **not** wired into the [ProviderScope] in this mode.
  final FirestoreClient? firestoreClient;

  /// No-op on host: in-memory repositories need no special initialisation.
  ///
  /// Call once per process from [setUpAll] so both host and on-device entry
  /// points share the same pattern.
  static void initForHost() {}

  /// No-op placeholder for on-device integration tests.
  ///
  /// The platform SQLite factory is already correct on a real device.
  /// Call this from integration test entry points alongside the shared
  /// flow logic so both execution modes call one init function.
  static void initForOnDevice() {
    // Nothing to do — platform factory is already wired.
  }

  /// Creates an [AppHarness] and pumps [HabitLoopApp] into [tester].
  ///
  /// Parameters:
  /// - [extraOverrides]: Riverpod overrides layered on top of
  ///   [AppContainer.overrides], e.g. time-controlled providers:
  ///   ```dart
  ///   extraOverrides: [todayProvider.overrideWithValue(DateTime(2099, 6, 15))],
  ///   ```
  /// - [beforePump]: optional async callback called after the repository
  ///   instances are ready but *before* [tester.pumpWidget]. Use this to
  ///   pre-seed pacts and showups so they are visible on the very first
  ///   dashboard load without requiring wizard navigation.
  /// - [initiallyAnonymous]: when `true`, the harness starts with an anonymous
  ///   auth state. Use this for tests that drive the sign-in flow themselves
  ///   (e.g. the sync-on-login flow).
  /// - [syncServiceFactory]: optional factory for a custom [FakeSyncService]
  ///   subclass that has access to the in-memory repos. Used to seed "remote"
  ///   data via [FakeSyncService.pullRemoteChanges] without touching the repos
  ///   before the test's sign-in step.
  /// - [firestoreClient]: when provided, the harness wires [firestoreClientProvider]
  ///   with this client instead of overriding [syncServiceProvider] with a
  ///   [FakeSyncService]. This lets the real [FirestoreSyncService] run
  ///   end-to-end against a [FakeFirestoreClient] or
  ///   [FaultInjectingFirestoreClient] for integration tests that exercise
  ///   [pullRemoteChanges] and the circuit-breaker without touching live
  ///   Firestore.
  static Future<AppHarness> create(
    WidgetTester tester, {
    List<Override> extraOverrides = const [],
    Future<void> Function(AppHarness h)? beforePump,
    bool initiallyAnonymous = false,
    FakeSyncService Function(InMemoryPactRepository, InMemoryShowupRepository)? syncServiceFactory,
    FirestoreClient? firestoreClient,
  }) async {
    final pactRepo = InMemoryPactRepository();
    final showupRepo = InMemoryShowupRepository();
    final txService = InMemoryPactTransactionService(pactRepo, showupRepo);

    final auth = FakeAuthService(userId: 'test-user', isAnonymous: initiallyAnonymous);
    final analytics = FakeAnalyticsService();
    final notifications = FakeNotificationService();
    final syncService = syncServiceFactory?.call(pactRepo, showupRepo) ?? FakeSyncService();
    final localeService = FakeLocalePreferenceService();

    final overrides = await AppContainer.overrides(
      pactRepository: pactRepo,
      showupRepository: showupRepo,
      transactionService: txService,
      authService: auth,
      analyticsService: analytics,
      notificationService: notifications,
      localePreferenceService: localeService,
    );

    final navigatorKey = GlobalKey<NavigatorState>();

    final harness = AppHarness._(
      pactRepo: pactRepo,
      showupRepo: showupRepo,
      auth: auth,
      analytics: analytics,
      notifications: notifications,
      syncService: syncService,
      localeService: localeService,
      navigatorKey: navigatorKey,
      firestoreClient: firestoreClient,
    );

    if (beforePump != null) await beforePump(harness);

    // Register widget-tree teardown via addTearDown so it runs while
    // LiveTestWidgetsFlutterBinding.inTest is still true. Regular tearDown
    // callbacks run after the binding clears inTest, at which point pump()
    // throws an assertion. addTearDown runs before that boundary.
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          // When firestoreClient is provided, override firestoreClientProvider so
          // the self-composed FirestoreSyncService runs against the supplied fake
          // client (FakeFirestoreClient or FaultInjectingFirestoreClient).
          // Otherwise, fall back to FakeSyncService so tests that don't need the
          // full sync stack still run without touching any Firestore code.
          if (firestoreClient != null)
            firestoreClientProvider.overrideWithValue(firestoreClient)
          else
            syncServiceProvider.overrideWithValue(syncService),
          // connectivity_plus calls a platform channel that blocks indefinitely
          // on the test host. Override with a static "has internet" stream so
          // pumpAndSettle() never hangs waiting for a platform response.
          connectivityProvider.overrideWith((_) => Stream.value(true)),
          // package_info_plus calls a platform channel that may also block.
          // Return empty string — the dashboard shows it as a subtitle and the
          // test doesn't assert on version text.
          appVersionProvider.overrideWith((_) async => ''),
          ...extraOverrides,
        ],
        child: HabitLoopApp(navigatorKey: navigatorKey),
      ),
    );

    // Multiple pumps to let the full async init chain complete without
    // pumpAndSettle(), which hangs on CircularProgressIndicator animations
    // from DashboardViewModel.isLoading and PactsPanel loading states.
    //
    // Emit auth state AFTER the first pump so that authStateChangesProvider has
    // already subscribed to the broadcast stream. FakeAuthService uses a plain
    // BroadcastStreamController (no replay), so an event emitted before the
    // provider subscribes would be silently dropped and the provider would stay
    // in AsyncLoading forever — causing SyncStatusViewModel to show "connecting"
    // instead of "notLinked" for anonymous users.
    await tester.pump(); // initState's Future.microtask fires; stream providers subscribe
    // Emit the *current* auth state rather than the constructor-time value so
    // that beforePump callbacks (e.g. clearStaleKeychainIfFirstLaunch) that
    // call signOut() on auth are not silently undone by this emit.
    auth.emitState(userId: auth.currentUserId, isAnonymous: auth.isAnonymous);
    await tester.pump(); // authStateChangesProvider receives event; notifiers rebuild
    await tester.pump(const Duration(milliseconds: 50)); // cascading updates
    await tester.pump(const Duration(milliseconds: 100)); // stream providers settle
    await tester.pump(const Duration(milliseconds: 100)); // autoDispose rebuilds

    return harness;
  }

  /// Closes services. Widget-tree cleanup is handled by the [addTearDown]
  /// registered in [create] — it runs while [LiveTestWidgetsFlutterBinding]
  /// still has [inTest] set, which allows [pump] to be called. This method
  /// only closes services, so it is safe to call from a regular [tearDown].
  void dispose() {
    auth.dispose();
  }
}

/// Finds the [AppLocalizations] for the current widget tree.
///
/// Uses the [Navigator] element (which is inside MaterialApp's Localizations
/// widget) so that AppLocalizations.of() can walk up to the Localizations
/// ancestor and return the resolved instance.
AppLocalizations l10n(WidgetTester tester) {
  final context = tester.element(find.byType(Navigator).first);
  return AppLocalizations.of(context)!;
}

/// Pumps until [finder] has at least one match or [timeout] expires.
///
/// Prefer over a raw [WidgetTester.pumpAndSettle] when provider rebuilds or
/// async DB work may span more than one frame.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = tester.binding.clock.now().add(timeout);
  while (!finder.evaluate().isNotEmpty) {
    if (tester.binding.clock.now().isAfter(deadline)) {
      throw TestFailure('waitFor timed out: $finder');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Disables onboarding auto-advance (RC value below `_minAutoAdvanceSeconds`).
final noAutoAdvance = remoteConfigServiceProvider.overrideWithValue(
  FakeRemoteConfigService(overrides: {'onboarding_auto_advance_seconds': 0}),
);

/// Opens the collapsible pacts panel from the dashboard.
Future<void> openPactsPanel(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('pacts-panel-drag-handle')));
  // Bare pump flushes the tap handler synchronously before the 400 ms animation
  // clock starts — without this the panel may still be collapsed on entry.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Opens the detail screen for the pact named [habitName] from the pacts panel.
Future<void> openPactDetail(WidgetTester tester, String habitName) async {
  await waitFor(tester, find.text(habitName));
  await tester.tap(find.text(habitName).last);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Opens the timeline screen from an already-open pact detail screen.
Future<void> openTimeline(WidgetTester tester) async {
  // Wait for the pact detail to finish loading before scrolling — the button
  // only appears once the view model has resolved, which can take >450 ms on
  // a real device; calling ensureVisible before that causes a deadlock.
  await waitFor(tester, find.byKey(const Key('pact-detail-timeline-button')));
  await tester.ensureVisible(find.byKey(const Key('pact-detail-timeline-button')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('pact-detail-timeline-button')));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 100));
}
