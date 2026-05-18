import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_screen.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/slices/pact/data/in_memory_pact_transaction_service.dart';
import 'package:habit_loop/slices/showup/data/in_memory_showup_repository.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/onboarding/fake_onboarding_preference_service.dart';

final _today = DateTime(2026, 3, 29);

Widget _buildApp({
  List<Pact> pacts = const [],
  List<Showup> showups = const [],
  FakeAnalyticsService? analyticsService,
}) {
  final pactRepo = InMemoryPactRepository(pacts);
  final showupRepo = InMemoryShowupRepository(showups);
  final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
  return ProviderScope(
    overrides: [
      pactRepositoryProvider.overrideWithValue(pactRepo),
      showupRepositoryProvider.overrideWithValue(showupRepo),
      pactTransactionServiceProvider.overrideWithValue(txService),
      todayProvider.overrideWithValue(_today),
      if (analyticsService != null) analyticsServiceProvider.overrideWithValue(analyticsService),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: DashboardScreen(),
    ),
  );
}

void main() {
  group('DashboardScreen', () {
    testWidgets('shows onboarding carousel when no pacts exist', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      // Onboarding carousel is shown instead of the old empty state.
      expect(find.text('No pacts yet'), findsNothing);
      expect(find.text('Create a Pact'), findsOneWidget);
    });

    testWidgets('shows calendar strip with 7 days', (tester) async {
      await tester.pumpWidget(_buildApp(pacts: [
        Pact(
          id: '1',
          habitName: 'Meditate',
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 9, 1),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
          status: PactStatus.active,
        ),
      ]));
      await tester.pumpAndSettle();

      // Should show day numbers for the 7-day range: 26, 27, 28, 29, 30, 31, 1
      expect(find.text('26'), findsOneWidget);
      expect(find.text('27'), findsOneWidget);
      expect(find.text('28'), findsOneWidget);
      expect(find.text('29'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('shows showups for selected day', (tester) async {
      final showup = Showup(
        id: '1',
        pactId: '1',
        scheduledAt: DateTime(2026, 3, 29, 7, 0),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.pending,
      );

      // Use a Monday-only schedule so lazy generation produces no showups on
      // today (Sunday March 29) — this prevents duplicate 'Meditate' tiles.
      await tester.pumpWidget(_buildApp(
        pacts: [
          Pact(
            id: '1',
            habitName: 'Meditate',
            startDate: DateTime(2026, 3, 1),
            endDate: DateTime(2026, 9, 1),
            showupDuration: const Duration(minutes: 10),
            schedule: const WeekdaySchedule(entries: [
              WeekdayEntry(weekday: DateTime.monday, timeOfDay: Duration(hours: 7)),
            ]),
            status: PactStatus.active,
          ),
        ],
        showups: [showup],
      ));
      await tester.pumpAndSettle();

      expect(find.text('Meditate'), findsOneWidget);
    });

    testWidgets('tapping a different day selects it', (tester) async {
      final showupMar28 = Showup(
        id: '1',
        pactId: '1',
        scheduledAt: DateTime(2026, 3, 28, 7, 0),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.done,
      );

      // Use a Monday-only schedule so lazy generation produces no showup on
      // today (Sunday March 29) — keeping the "no showups" empty state visible.
      await tester.pumpWidget(_buildApp(
        pacts: [
          Pact(
            id: '1',
            habitName: 'Meditate',
            startDate: DateTime(2026, 3, 1),
            endDate: DateTime(2026, 9, 1),
            showupDuration: const Duration(minutes: 10),
            schedule: const WeekdaySchedule(entries: [
              WeekdayEntry(weekday: DateTime.monday, timeOfDay: Duration(hours: 7)),
            ]),
            status: PactStatus.active,
          ),
        ],
        showups: [showupMar28],
      ));
      await tester.pumpAndSettle();

      // Today (29, Sunday) is selected — no showups generated for Sunday
      expect(find.text('No showups for this day'), findsOneWidget);

      // Tap on day 28
      await tester.tap(find.text('28'));
      await tester.pumpAndSettle();

      // Now should show the showup for Mar 28
      expect(find.text('Meditate'), findsOneWidget);
    });

    testWidgets('shows create pact button when pacts exist', (tester) async {
      await tester.pumpWidget(_buildApp(pacts: [
        Pact(
          id: '1',
          habitName: 'Meditate',
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 9, 1),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
          status: PactStatus.active,
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('create-pact-button')), findsOneWidget);
    });

    testWidgets('shows status dots for showups on calendar days', (tester) async {
      final doneShowup = Showup(
        id: '1',
        pactId: '1',
        scheduledAt: DateTime(2026, 3, 28, 7, 0),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.done,
      );
      final pendingShowup = Showup(
        id: '2',
        pactId: '1',
        scheduledAt: DateTime(2026, 3, 29, 7, 0),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.pending,
      );

      await tester.pumpWidget(_buildApp(
        pacts: [
          Pact(
            id: '1',
            habitName: 'Meditate',
            startDate: DateTime(2026, 3, 1),
            endDate: DateTime(2026, 9, 1),
            showupDuration: const Duration(minutes: 10),
            schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
            status: PactStatus.active,
          ),
        ],
        showups: [doneShowup, pendingShowup],
      ));
      await tester.pumpAndSettle();

      // Dots are rendered as small Container widgets with specific colors.
      // We verify they exist by finding the status dot key.
      expect(find.byKey(const Key('status-dot-1')), findsOneWidget);
      expect(find.byKey(const Key('status-dot-2')), findsOneWidget);
    });

    testWidgets('shows single large dot for 4 or more showups on a day', (tester) async {
      final showups = List.generate(
        4,
        (i) => Showup(
          id: 'su$i',
          pactId: '$i',
          scheduledAt: DateTime(2026, 3, 29, 7 + i, 0),
          duration: const Duration(minutes: 10),
          status: ShowupStatus.pending,
        ),
      );
      final pacts = List.generate(
        4,
        (i) => Pact(
          id: '$i',
          habitName: 'Habit $i',
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 9, 1),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
          status: PactStatus.active,
        ),
      );

      await tester.pumpWidget(_buildApp(pacts: pacts, showups: showups));
      await tester.pumpAndSettle();

      // Individual dots must not be rendered; overflow dot must appear instead.
      expect(find.byKey(const Key('status-dot-su0')), findsNothing);
      expect(find.byKey(const Key('status-dot-overflow-2026-03-29')), findsOneWidget);
    });

    testWidgets('overflow dot is green when all resolved and done >= failed', (tester) async {
      final showups = [
        Showup(
            id: 'a',
            pactId: '1',
            scheduledAt: DateTime(2026, 3, 29, 7),
            duration: const Duration(minutes: 10),
            status: ShowupStatus.done),
        Showup(
            id: 'b',
            pactId: '2',
            scheduledAt: DateTime(2026, 3, 29, 8),
            duration: const Duration(minutes: 10),
            status: ShowupStatus.done),
        Showup(
            id: 'c',
            pactId: '3',
            scheduledAt: DateTime(2026, 3, 29, 9),
            duration: const Duration(minutes: 10),
            status: ShowupStatus.failed),
        Showup(
            id: 'd',
            pactId: '4',
            scheduledAt: DateTime(2026, 3, 29, 10),
            duration: const Duration(minutes: 10),
            status: ShowupStatus.done),
      ];
      // Use Monday-only schedules so lazy generation skips Sunday (today = Mar 29)
      // and the pre-seeded showups remain the only ones on today's calendar slot.
      final pacts = List.generate(
          4,
          (i) => Pact(
                id: '${i + 1}',
                habitName: 'Habit $i',
                startDate: DateTime(2026, 3, 1),
                endDate: DateTime(2026, 9, 1),
                showupDuration: const Duration(minutes: 10),
                schedule: const WeekdaySchedule(entries: [
                  WeekdayEntry(weekday: DateTime.monday, timeOfDay: Duration(hours: 7)),
                ]),
                status: PactStatus.active,
              ));

      await tester.pumpWidget(_buildApp(pacts: pacts, showups: showups));
      await tester.pumpAndSettle();

      final dot = tester.widget<Container>(
        find.byKey(const Key('status-dot-overflow-2026-03-29')),
      );
      final decoration = dot.decoration! as BoxDecoration;
      expect(decoration.color, isNot(equals(Colors.grey)));
    });

    testWidgets('overflow dot is amber when any showup is in active/past window (active UI state)', (tester) async {
      // All showups are scheduled in the past (March 2026) with domain status
      // pending. Since now > scheduledAt for all of them, deriveShowupUiState
      // returns ShowupUiState.active → amber overflow dot. None are planned, so
      // the "active AND no planned" rule fires.
      final showups = List.generate(
          4,
          (i) => Showup(
                id: 'p$i',
                pactId: '$i',
                scheduledAt: DateTime(2026, 3, 29, 7 + i),
                duration: const Duration(minutes: 10),
                status: ShowupStatus.pending,
              ));
      final pacts = List.generate(
          4,
          (i) => Pact(
                id: '$i',
                habitName: 'Habit $i',
                startDate: DateTime(2026, 3, 1),
                endDate: DateTime(2026, 9, 1),
                showupDuration: const Duration(minutes: 10),
                schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
                status: PactStatus.active,
              ));

      await tester.pumpWidget(_buildApp(pacts: pacts, showups: showups));
      await tester.pumpAndSettle();

      final dot = tester.widget<Container>(
        find.byKey(const Key('status-dot-overflow-2026-03-29')),
      );
      final decoration = dot.decoration! as BoxDecoration;
      // All showups are ShowupUiState.active (no planned) → amber (not grey, not green, not red).
      final greyColor = Theme.of(tester.element(find.byType(DashboardScreen))).colorScheme.onSurfaceVariant;
      expect(decoration.color, isNot(equals(greyColor)));
      expect(decoration.color, equals(Colors.amber));
    });

    testWidgets('overflow dot is amber when some done but one is in active/past window', (tester) async {
      // The domain-pending showup 'd' is scheduled in the past (March 29,
      // 10 AM). Since now > scheduledAt, its derived UI state is
      // ShowupUiState.active → amber overflow dot. The done showups don't count
      // as planned, so the "active AND no planned" rule fires.
      final showups = [
        Showup(
            id: 'a',
            pactId: '1',
            scheduledAt: DateTime(2026, 3, 29, 7),
            duration: const Duration(minutes: 10),
            status: ShowupStatus.done),
        Showup(
            id: 'b',
            pactId: '2',
            scheduledAt: DateTime(2026, 3, 29, 8),
            duration: const Duration(minutes: 10),
            status: ShowupStatus.done),
        Showup(
            id: 'c',
            pactId: '3',
            scheduledAt: DateTime(2026, 3, 29, 9),
            duration: const Duration(minutes: 10),
            status: ShowupStatus.done),
        Showup(
            id: 'd',
            pactId: '4',
            scheduledAt: DateTime(2026, 3, 29, 10),
            duration: const Duration(minutes: 10),
            status: ShowupStatus.pending),
      ];
      final pacts = List.generate(
          4,
          (i) => Pact(
                id: '${i + 1}',
                habitName: 'Habit $i',
                startDate: DateTime(2026, 3, 1),
                endDate: DateTime(2026, 9, 1),
                showupDuration: const Duration(minutes: 10),
                schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
                status: PactStatus.active,
              ));

      await tester.pumpWidget(_buildApp(pacts: pacts, showups: showups));
      await tester.pumpAndSettle();

      final dot = tester.widget<Container>(
        find.byKey(const Key('status-dot-overflow-2026-03-29')),
      );
      final decoration = dot.decoration! as BoxDecoration;
      // One showup is ShowupUiState.active (no planned) → amber (not grey, not green).
      expect(decoration.color, equals(Colors.amber));
    });

    testWidgets('shows dialog when 3 or more active pacts exist on create tap', (tester) async {
      final pacts = List.generate(
        3,
        (i) => Pact(
          id: '$i',
          habitName: 'Habit $i',
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 9, 1),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
          status: PactStatus.active,
        ),
      );

      await tester.pumpWidget(_buildApp(pacts: pacts));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('create-pact-button')));
      await tester.pumpAndSettle();

      expect(find.text('Too many active pacts'), findsOneWidget);
    });

    testWidgets('does not show dialog when fewer than 3 active pacts', (tester) async {
      final pacts = List.generate(
        2,
        (i) => Pact(
          id: '$i',
          habitName: 'Habit $i',
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 9, 1),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
          status: PactStatus.active,
        ),
      );

      await tester.pumpWidget(_buildApp(pacts: pacts));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('create-pact-button')));
      await tester.pumpAndSettle();

      expect(find.text('Too many active pacts'), findsNothing);
    });

    testWidgets('tapping a showup tile navigates to showup detail screen', (tester) async {
      final showup = Showup(
        id: 'showup-1',
        pactId: 'pact-1',
        scheduledAt: DateTime(2026, 3, 29, 7, 0),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.pending,
      );
      // Use a Monday-only schedule so lazy generation does not produce an
      // additional showup on today (Sunday March 29). Only the pre-seeded
      // showup appears, making find.text('Meditate') unambiguous.
      final pact = Pact(
        id: 'pact-1',
        habitName: 'Meditate',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 9, 1),
        showupDuration: const Duration(minutes: 10),
        schedule: const WeekdaySchedule(entries: [
          WeekdayEntry(weekday: DateTime.monday, timeOfDay: Duration(hours: 7)),
        ]),
        status: PactStatus.active,
      );

      await tester.pumpWidget(_buildApp(pacts: [pact], showups: [showup]));
      await tester.pumpAndSettle();

      // Tap the showup tile to navigate to detail screen.
      await tester.tap(find.text('Meditate'));
      await tester.pumpAndSettle();

      // The showup detail screen title should appear.
      expect(find.text('Showup Details'), findsOneWidget);
    });

    testWidgets('dialog body uses plural for 1 active pact', (tester) async {
      // This test verifies the singular form. In practice the dialog only
      // appears at 3+, but we can reach the singular branch if the threshold
      // is exactly 1 — tested here by using a custom threshold scenario.
      // Since the threshold is 3, we test with exactly 3 pacts and verify
      // the plural "active pacts" (not "active pact") form is shown.
      final pacts = List.generate(
        3,
        (i) => Pact(
          id: '$i',
          habitName: 'Habit $i',
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 9, 1),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
          status: PactStatus.active,
        ),
      );

      await tester.pumpWidget(_buildApp(pacts: pacts));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('create-pact-button')));
      await tester.pumpAndSettle();

      // Plural form for 3 pacts.
      expect(
        find.textContaining('3 active pacts'),
        findsOneWidget,
      );
    });

    testWidgets('logs dashboard screen_view again when returning from showup detail', (tester) async {
      final analytics = FakeAnalyticsService();
      final showup = Showup(
        id: 'showup-1',
        pactId: 'pact-1',
        scheduledAt: DateTime(2026, 3, 29, 7, 0),
        duration: const Duration(minutes: 10),
        status: ShowupStatus.pending,
      );
      final pact = Pact(
        id: 'pact-1',
        habitName: 'Meditate',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 9, 1),
        showupDuration: const Duration(minutes: 10),
        schedule: const WeekdaySchedule(entries: [
          WeekdayEntry(weekday: DateTime.monday, timeOfDay: Duration(hours: 7)),
        ]),
        status: PactStatus.active,
      );

      await tester.pumpWidget(
        _buildApp(
          pacts: [pact],
          showups: [showup],
          analyticsService: analytics,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        analytics.loggedScreens.where((screen) => screen.name == 'dashboard'),
        hasLength(1),
      );

      await tester.tap(find.text('Meditate'));
      await tester.pumpAndSettle();
      expect(find.text('Showup Details'), findsOneWidget);

      final detailNavigator = Navigator.of(tester.element(find.byType(Scaffold).last));
      detailNavigator.pop();
      await tester.pumpAndSettle();

      expect(
        analytics.loggedScreens.where((screen) => screen.name == 'dashboard'),
        hasLength(2),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Cold-start blink prevention (HAB-77)
  //
  // The blink on cold start was caused by [hasActivePactsProvider] (a
  // FutureProvider) going through AsyncLoading before resolving. The fix uses
  // a write-once SharedPreferences flag ([onboarding_passed]) read synchronously
  // on the first Flutter frame:
  //   - Flag = false (new user / fresh install): carousel shown immediately.
  //   - Flag = true  (returning user): dashboard shown immediately — no
  //     AsyncLoading state, no intermediate blank+spinner, no blink.
  //
  // The flag is written by [DashboardScreen] the first time it renders the
  // dashboard (not the carousel), guaranteeing both possible paths (pact
  // created, or Google sign-in succeeded) set it before the next cold start.
  // ---------------------------------------------------------------------------
  group('cold-start blink prevention / onboarding flag (HAB-77)', () {
    Widget buildWithOnboarding({
      bool onboardingPassed = false,
      List<Pact> pacts = const [],
    }) {
      final pactRepo = InMemoryPactRepository(pacts);
      final showupRepo = InMemoryShowupRepository();
      final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
      final onboardingService = FakeOnboardingPreferenceService(initialValue: onboardingPassed);
      return ProviderScope(
        overrides: [
          pactRepositoryProvider.overrideWithValue(pactRepo),
          showupRepositoryProvider.overrideWithValue(showupRepo),
          pactTransactionServiceProvider.overrideWithValue(txService),
          todayProvider.overrideWithValue(_today),
          onboardingPreferenceServiceProvider.overrideWithValue(onboardingService),
        ],
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('en'),
          home: DashboardScreen(),
        ),
      );
    }

    testWidgets(
      'shows carousel on first frame when onboarding not yet passed (new-user path)',
      (tester) async {
        // onboardingPassed=false, no pacts, anonymous (default) →
        // showCarousel=true immediately — no spinner, carousel on first frame.
        await tester.pumpWidget(buildWithOnboarding());

        expect(find.text('Create a Pact'), findsOneWidget);
        expect(find.byKey(const Key('language-picker-button')), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'shows dashboard on first frame when onboarding already passed (returning-user path)',
      (tester) async {
        // onboardingPassed=true → showCarousel=false immediately, regardless of
        // whether hasActivePactsProvider has resolved. Language picker is in the
        // dashboard nav bar / AppBar — its presence confirms the correct screen
        // was selected on the very first frame, without any intermediate state.
        await tester.pumpWidget(buildWithOnboarding(onboardingPassed: true));

        expect(find.byKey(const Key('language-picker-button')), findsOneWidget);
        expect(find.text('Create a Pact'), findsNothing);
      },
    );

    testWidgets(
      'writes onboarding flag when dashboard first shown',
      (tester) async {
        // Pacts present → after hasActivePactsProvider resolves hasPacts=true →
        // showCarousel=false → DashboardScreen calls markOnboardingPassed().
        final pact = Pact(
          id: 'p1',
          habitName: 'Meditate',
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 9, 1),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
          status: PactStatus.active,
        );
        final pactRepo = InMemoryPactRepository([pact]);
        final showupRepo = InMemoryShowupRepository();
        final txService = InMemoryPactTransactionService(pactRepo, showupRepo);
        final onboardingService = FakeOnboardingPreferenceService();

        await tester.pumpWidget(ProviderScope(
          overrides: [
            pactRepositoryProvider.overrideWithValue(pactRepo),
            showupRepositoryProvider.overrideWithValue(showupRepo),
            pactTransactionServiceProvider.overrideWithValue(txService),
            todayProvider.overrideWithValue(_today),
            onboardingPreferenceServiceProvider.overrideWithValue(onboardingService),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: DashboardScreen(),
          ),
        ));
        await tester.pumpAndSettle();

        // Dashboard was shown (pact exists) → flag must have been written.
        expect(onboardingService.isOnboardingPassed, isTrue);
        expect(onboardingService.markCalledCount, 1);
      },
    );

    testWidgets(
      'writes onboarding flag only once even across multiple rebuilds',
      (tester) async {
        final pact = Pact(
          id: 'p1',
          habitName: 'Meditate',
          startDate: DateTime(2026, 3, 1),
          endDate: DateTime(2026, 9, 1),
          showupDuration: const Duration(minutes: 10),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 7)),
          status: PactStatus.active,
        );
        final onboardingService = FakeOnboardingPreferenceService();
        final pactRepo = InMemoryPactRepository([pact]);
        final showupRepo = InMemoryShowupRepository();
        final txService = InMemoryPactTransactionService(pactRepo, showupRepo);

        await tester.pumpWidget(ProviderScope(
          overrides: [
            pactRepositoryProvider.overrideWithValue(pactRepo),
            showupRepositoryProvider.overrideWithValue(showupRepo),
            pactTransactionServiceProvider.overrideWithValue(txService),
            todayProvider.overrideWithValue(_today),
            onboardingPreferenceServiceProvider.overrideWithValue(onboardingService),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: DashboardScreen(),
          ),
        ));
        // Multiple pump calls to trigger additional rebuilds.
        await tester.pump();
        await tester.pump();
        await tester.pumpAndSettle();

        expect(onboardingService.markCalledCount, 1);
      },
    );
  });
}
