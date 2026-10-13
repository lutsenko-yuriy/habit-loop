import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_stats.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/domain/user/user_profile_repository.dart';
import 'package:habit_loop/infrastructure/firestore/contracts/firestore_client.dart';
import 'package:habit_loop/infrastructure/injections/app_container.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/onboarding/contracts/onboarding_preference_service.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/main.dart';
import 'package:habit_loop/slices/checklist/data/in_memory_checklist_run_repository.dart';
import 'package:habit_loop/slices/checklist/data/in_memory_pact_checklist_link_repository.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_status_handler.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_ui_state.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_break_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../test/infrastructure/analytics/fake_analytics_service.dart';
import '../test/infrastructure/auth/fake_auth_service.dart';
import '../test/infrastructure/checklister/fake_checklister_gateway.dart';
import '../test/infrastructure/deep_links/fake_incoming_link_service.dart';
import '../test/infrastructure/locale/fake_locale_preference_service.dart';
import '../test/infrastructure/notifications/fake_notification_service.dart';
import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import '../test/infrastructure/sync/fake_sync_service.dart';
import 'robots/dashboard_robot.dart';
import 'robots/onboarding_robot.dart';
import 'robots/pact_detail_robot.dart';

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
    required this.tester,
    required this.pactRepo,
    required this.showupRepo,
    required this.pactBreakRepo,
    required this.auth,
    required this.analytics,
    required this.notifications,
    required this.syncService,
    required this.localeService,
    required this.checklister,
    required this.incomingLinks,
    required this.checklistLinkRepo,
    required this.checklistRunRepo,
    required this.navigatorKey,
    this.onboardingService,
    this.userProfileRepository,
    this.firestoreClient,
  });

  /// Tester the harness was created with; backs the screen robots below.
  final WidgetTester tester;

  late final DashboardRobot dashboard = DashboardRobot(tester);
  late final PactDetailRobot pactDetail = PactDetailRobot(tester);
  late final OnboardingRobot onboarding = OnboardingRobot(tester);

  final InMemoryPactRepository pactRepo;
  final InMemoryShowupRepository showupRepo;
  final InMemoryPactBreakRepository pactBreakRepo;
  final FakeAuthService auth;
  final FakeAnalyticsService analytics;
  final FakeNotificationService notifications;
  final FakeSyncService syncService;
  final FakeLocalePreferenceService localeService;

  /// GH-464: Checklister is installed by default; set `checklister.installed`
  /// or `canLaunch` to simulate otherwise, read `launchedUrls` to assert.
  final FakeChecklisterGateway checklister;

  /// GH-464: simulate `habitloop://` callbacks via `incomingLinks.emit(uri)`.
  final FakeIncomingLinkService incomingLinks;

  /// GH-464: in-memory checklist link / run stores wired into the app.
  final InMemoryPactChecklistLinkRepository checklistLinkRepo;
  final InMemoryChecklistRunRepository checklistRunRepo;

  /// HAB-232: non-null only when [AppHarness.create] was called with an
  /// explicit `onboardingService` — otherwise the widget tree uses the
  /// default `NoopOnboardingService` (app_providers.dart), unaffected by this
  /// field's absence. Pass the same instance into a second [AppHarness.create]
  /// call to simulate a subsequent launch.
  final OnboardingPreferenceService? onboardingService;

  /// HAB-232: non-null only when [AppHarness.create] was called with an
  /// explicit `userProfileRepository` — otherwise the widget tree uses the
  /// default `InMemoryUserProfileRepository` (app_providers.dart).
  final UserProfileRepository? userProfileRepository;

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
  /// - [remoteConfigOverrides]: RC flag values layered on top of
  ///   [TestRemoteConfigDefaults.all] via [FakeRemoteConfigService.withTestDefaults]
  ///   (HAB-260). Prefer this over overriding [remoteConfigServiceProvider]
  ///   directly through [extraOverrides] — that would fully replace the
  ///   harness's own service instead of layering on top of it.
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
    Map<String, dynamic> remoteConfigOverrides = const {},
    Future<void> Function(AppHarness h)? beforePump,
    bool initiallyAnonymous = false,
    FakeSyncService Function(InMemoryPactRepository, InMemoryShowupRepository)? syncServiceFactory,
    FirestoreClient? firestoreClient,
    OnboardingPreferenceService? onboardingService,
    UserProfileRepository? userProfileRepository,
  }) async {
    // The integration binding leaves the real IME attached, whose stale updates can revert
    // tester.enterText (GH-474) — route text input through the fake keyboard instead.
    final textInput = tester.binding.testTextInput
      ..reset()
      ..register();
    addTearDown(textInput.unregister);

    final pactRepo = InMemoryPactRepository();
    final showupRepo = InMemoryShowupRepository();
    final pactBreakRepo = InMemoryPactBreakRepository();
    final txService = InMemoryPactTransactionService(pactRepo, showupRepo);

    final auth = FakeAuthService(userId: 'test-user', isAnonymous: initiallyAnonymous);
    final analytics = FakeAnalyticsService();
    final notifications = FakeNotificationService();
    final syncService = syncServiceFactory?.call(pactRepo, showupRepo) ?? FakeSyncService();
    final localeService = FakeLocalePreferenceService();
    final checklister = FakeChecklisterGateway();
    final incomingLinks = FakeIncomingLinkService();
    final checklistLinkRepo = InMemoryPactChecklistLinkRepository();
    final checklistRunRepo = InMemoryChecklistRunRepository();

    final overrides = await AppContainer.overrides(
      pactRepository: pactRepo,
      showupRepository: showupRepo,
      transactionService: txService,
      pactBreakRepository: pactBreakRepo,
      authService: auth,
      analyticsService: analytics,
      notificationService: notifications,
      localePreferenceService: localeService,
      checklisterGateway: checklister,
      incomingLinkService: incomingLinks,
      pactChecklistLinkRepository: checklistLinkRepo,
      checklistRunRepository: checklistRunRepo,
      // HAB-232: only overridden when a test explicitly opts in — otherwise every
      // pre-existing scenario keeps its original NoopOnboardingService/
      // InMemoryUserProfileRepository defaults (app_providers.dart) unchanged.
      onboardingPreferenceService: onboardingService,
      userProfileRepository: userProfileRepository,
    );

    final navigatorKey = GlobalKey<NavigatorState>();

    final harness = AppHarness._(
      tester: tester,
      pactRepo: pactRepo,
      showupRepo: showupRepo,
      pactBreakRepo: pactBreakRepo,
      auth: auth,
      analytics: analytics,
      notifications: notifications,
      syncService: syncService,
      localeService: localeService,
      checklister: checklister,
      incomingLinks: incomingLinks,
      checklistLinkRepo: checklistLinkRepo,
      checklistRunRepo: checklistRunRepo,
      navigatorKey: navigatorKey,
      onboardingService: onboardingService,
      userProfileRepository: userProfileRepository,
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
          // display_name_personalization_enabled's RC default is `true`, and
          // resolveReleaseGatedFlag bypasses the release-version gate entirely
          // in debug builds (which integration tests run as) — so it would
          // show EnterNameScreen and block every pre-existing scenario from
          // ever reaching the dashboard. TestRemoteConfigDefaults.all pins it
          // off (HAB-260); [remoteConfigOverrides] layers on top of that.
          // A guard test (HAB-260 WU3) keeps any future integration_test/
          // file from overriding remoteConfigServiceProvider directly and
          // silently discarding this layering.
          remoteConfigServiceProvider.overrideWithValue(
            FakeRemoteConfigService.withTestDefaults(overrides: remoteConfigOverrides),
          ),
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
    unawaited(incomingLinks.dispose());
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

/// The sync-status icon actually rendered for [state] on the platform this
/// test is running on — mirrors `DashboardScreen`'s own `defaultTargetPlatform`
/// switch. Use this instead of hardcoding a Material `Icons.*` literal: the
/// real dashboard renders `CupertinoIcons.*` on iOS (see HAB-188 WU3), and a
/// hardcoded Material icon happens to "pass" there only by coincidence.
IconData syncIconFor(SyncUiState state) => defaultTargetPlatform == TargetPlatform.iOS
    ? syncStatusIconDataCupertino(state)
    : syncStatusIconDataMaterial(state);

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

/// Pumps until [finder] has no matches or [timeout] expires — the inverse of
/// [waitFor], for asserting a widget has actually been removed rather than
/// just tapped away (HAB-232).
Future<void> waitForGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = tester.binding.clock.now().add(timeout);
  while (finder.evaluate().isNotEmpty) {
    if (tester.binding.clock.now().isAfter(deadline)) {
      throw TestFailure('waitForGone timed out: still present: $finder');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Transitional delegate to [OnboardingRobot.saveEnterName] (GH-476; removed in the final WU).
Future<void> saveEnterName(WidgetTester tester, String name) => OnboardingRobot(tester).saveEnterName(name);

/// Transitional delegate to [OnboardingRobot.skipEnterName] (GH-476).
Future<void> skipEnterName(WidgetTester tester) => OnboardingRobot(tester).skipEnterName();

/// Transitional delegate to [OnboardingRobot.enterNameText] (GH-476).
String enterNameFieldText(WidgetTester tester) => OnboardingRobot(tester).enterNameText;

/// Transitional delegate to [DashboardRobot.changeNameText] (GH-476).
String changeNameFieldText(WidgetTester tester) => DashboardRobot(tester).changeNameText;

/// Transitional delegate to [DashboardRobot.openChangeNameDialog] (GH-476).
Future<void> openChangeNameDialogFromKebab(WidgetTester tester) => DashboardRobot(tester).openChangeNameDialog();

/// Transitional delegate to [DashboardRobot.saveChangeName] (GH-476).
Future<void> saveChangeName(WidgetTester tester, String name) => DashboardRobot(tester).saveChangeName(name);

/// Disables onboarding auto-advance (RC value below `_minAutoAdvanceSeconds`).
///
/// A plain overrides map — pass it as `AppHarness.create`'s
/// `remoteConfigOverrides` (merge in any other keys a test needs) rather than
/// wrapping it in `extraOverrides` (HAB-260). `display_name_personalization_enabled`
/// no longer needs pinning here since `TestRemoteConfigDefaults.all` already
/// covers it.
const noAutoAdvance = {'onboarding_auto_advance_seconds': 0};

/// Transitional delegate to [DashboardRobot.openPactsPanel] (GH-476).
Future<void> openPactsPanel(WidgetTester tester) => DashboardRobot(tester).openPactsPanel();

/// Transitional delegate to [DashboardRobot.openPactDetail] (GH-476).
Future<void> openPactDetail(WidgetTester tester, String habitName) => DashboardRobot(tester).openPactDetail(habitName);

/// Transitional delegate to [PactDetailRobot.scrollToStartBreakButton] (GH-476).
Future<void> scrollToPactDetailStartBreakButton(WidgetTester tester) =>
    PactDetailRobot(tester).scrollToStartBreakButton();

/// Transitional delegate to [PactDetailRobot.openTimeline] (GH-476).
Future<void> openTimeline(WidgetTester tester) => PactDetailRobot(tester).openTimeline();

/// Builds a [Pact] fixture with defaults suited to integration tests.
///
/// `createdAt` defaults to `startDate` — every fixture across the suite
/// creates the pact on its own start date, so this removes a field that
/// was otherwise repeated at every call site.
///
/// **`endDate` defaults to `2099-12-31`.** Every fixture in this suite that
/// omits `endDate` also uses a `startDate` near 2099, keeping the resulting
/// span short (weeks to months). A near-term `startDate` (e.g. 2026) combined
/// with the far-future default produces a decades-long pact, which can make
/// per-load work (e.g. `ShowupGenerator` enumerating occurrences) expensive
/// enough to look like a hang rather than a slow test (HAB-202, 2026-07-30 —
/// see `docs/knowledge/notes/HAB-202.md`). Pass an explicit `endDate` for any
/// fixture that isn't dated near 2099.
Pact buildPact({
  required String id,
  String habitName = 'Test Habit',
  required DateTime startDate,
  DateTime? endDate,
  Duration showupDuration = const Duration(minutes: 10),
  ShowupSchedule schedule = const DailySchedule(timeOfDay: Duration(hours: 8)),
  PactStatus status = PactStatus.active,
  DateTime? createdAt,
  Duration? reminderOffset,
  String? stopReason,
  PactStats? stats,
  DateTime? stoppedAt,
  bool archived = false,
  String? predecessorPactId,
}) =>
    Pact(
      id: id,
      habitName: habitName,
      startDate: startDate,
      endDate: endDate ?? DateTime(2099, 12, 31),
      showupDuration: showupDuration,
      schedule: schedule,
      status: status,
      createdAt: createdAt ?? startDate,
      reminderOffset: reminderOffset,
      stopReason: stopReason,
      stats: stats,
      stoppedAt: stoppedAt,
      archived: archived,
      predecessorPactId: predecessorPactId,
    );

/// Builds a [PactBreak] fixture with defaults suited to integration tests.
PactBreak buildBreak({
  required String id,
  required String pactId,
  required DateTime startDate,
  DateTime? plannedEndDate,
  String rationale = 'Taking a break',
  DateTime? createdAt,
  DateTime? stoppedAt,
}) =>
    PactBreak(
      id: id,
      pactId: pactId,
      startDate: startDate,
      rationale: rationale,
      plannedEndDate: plannedEndDate,
      createdAt: createdAt,
      stoppedAt: stoppedAt,
    );

/// Builds a [Showup] fixture with defaults suited to integration tests.
Showup buildShowup({
  required String id,
  required String pactId,
  required DateTime scheduledAt,
  Duration duration = const Duration(minutes: 10),
  ShowupStatus status = ShowupStatus.pending,
  String? note,
  bool redeemable = true,
}) =>
    Showup(
      id: id,
      pactId: pactId,
      scheduledAt: scheduledAt,
      duration: duration,
      status: status,
      note: note,
      redeemable: redeemable,
    );
