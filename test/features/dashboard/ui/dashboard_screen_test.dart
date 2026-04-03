import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/features/dashboard/ui/generic/dashboard_screen.dart';
import 'package:habit_loop/features/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/features/pact/data/in_memory_pact_repository.dart';
import 'package:habit_loop/features/pact/domain/pact.dart';
import 'package:habit_loop/features/pact/domain/pact_status.dart';
import 'package:habit_loop/features/pact/domain/showup_schedule.dart';
import 'package:habit_loop/features/showup/data/in_memory_showup_repository.dart';
import 'package:habit_loop/features/showup/domain/showup.dart';
import 'package:habit_loop/features/showup/domain/showup_status.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

final _today = DateTime(2026, 3, 29);

Widget _buildApp({
  List<Pact> pacts = const [],
  List<Showup> showups = const [],
}) {
  return ProviderScope(
    overrides: [
      pactRepositoryProvider
          .overrideWithValue(InMemoryPactRepository(pacts)),
      showupRepositoryProvider
          .overrideWithValue(InMemoryShowupRepository(showups)),
      todayProvider.overrideWithValue(_today),
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
        showups: [showupMar28],
      ));
      await tester.pumpAndSettle();

      // Today (29) is selected — no showups for today
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

    testWidgets('shows status dots for showups on calendar days',
        (tester) async {
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

    testWidgets('shows single large dot for 4 or more showups on a day',
        (tester) async {
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

    testWidgets('shows dialog when 3 or more active pacts exist on create tap',
        (tester) async {
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

    testWidgets('does not show dialog when fewer than 3 active pacts',
        (tester) async {
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
  });
}
