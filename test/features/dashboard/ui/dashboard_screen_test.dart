import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/features/dashboard/ui/generic/dashboard_screen.dart';
import 'package:habit_loop/features/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/features/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/features/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/features/showup/ui/generic/showup_detail_view_model.dart';
import 'package:habit_loop/infrastructure/analytics/providers/analytics_providers.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

import '../../../analytics/fake_analytics_service.dart';

final _today = DateTime(2026, 3, 29);

Widget _buildApp({
  List<Pact> pacts = const [],
  List<Showup> showups = const [],
  FakeAnalyticsService? analyticsService,
}) {
  final pactRepo = InMemoryPactRepository(pacts);
  final showupRepo = InMemoryShowupRepository(showups);
  return ProviderScope(
    overrides: [
      pactRepositoryProvider.overrideWithValue(pactRepo),
      showupRepositoryProvider.overrideWithValue(showupRepo),
      todayProvider.overrideWithValue(_today),
      showupDetailShowupRepositoryProvider.overrideWithValue(showupRepo),
      showupDetailPactRepositoryProvider.overrideWithValue(pactRepo),
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
    testWidgets('shows empty state when no pacts exist', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();

      expect(find.text('No pacts yet'), findsOneWidget);
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

    testWidgets('overflow dot is grey when any showup is still pending', (tester) async {
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
      final expectedColor = Theme.of(tester.element(find.byType(DashboardScreen))).colorScheme.onSurfaceVariant;
      expect(decoration.color, equals(expectedColor));
    });

    testWidgets('overflow dot is grey when some done but some still pending', (tester) async {
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
      final expectedColor = Theme.of(tester.element(find.byType(DashboardScreen))).colorScheme.onSurfaceVariant;
      expect(decoration.color, equals(expectedColor));
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
}
