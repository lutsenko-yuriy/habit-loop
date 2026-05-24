import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/ui/generic/slot_schedule_editor.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [child] in a localised [MaterialApp] so l10n resolves inside tests.
Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

/// A no-op time picker that immediately returns null (user cancelled).
Future<Duration?> _noopTimePicker(BuildContext _, Duration __) async => null;

/// A fake time picker that always returns 9:15.
Future<Duration?> _fixedTimePicker(BuildContext _, Duration __) async => const Duration(hours: 9, minutes: 15);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SlotScheduleEditor', () {
    group('rendering', () {
      testWidgets('renders one card for a single WeeklySlot', (tester) async {
        final schedule = SlotSchedule(slots: [
          WeeklySlot(weekdays: {1, 3}, timeOfDay: const Duration(hours: 8)),
        ]);
        await tester.pumpWidget(_wrap(
          SlotScheduleEditor(
            schedule: schedule,
            onChanged: (_) {},
            showTimePicker: _noopTimePicker,
          ),
        ));
        expect(find.byKey(const Key('slot-card-0')), findsOneWidget);
        expect(find.byKey(const Key('slot-card-1')), findsNothing);
      });

      testWidgets('renders two cards for two slots', (tester) async {
        final schedule = SlotSchedule(slots: [
          WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 8)),
          const MonthlySlot(dayOfMonth: 15, timeOfDay: Duration(hours: 18)),
        ]);
        await tester.pumpWidget(_wrap(
          SlotScheduleEditor(
            schedule: schedule,
            onChanged: (_) {},
            showTimePicker: _noopTimePicker,
          ),
        ));
        expect(find.byKey(const Key('slot-card-0')), findsOneWidget);
        expect(find.byKey(const Key('slot-card-1')), findsOneWidget);
      });

      testWidgets('remove button is hidden when only one slot', (tester) async {
        final schedule = SlotSchedule(slots: [
          WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 8)),
        ]);
        await tester.pumpWidget(_wrap(
          SlotScheduleEditor(
            schedule: schedule,
            onChanged: (_) {},
            showTimePicker: _noopTimePicker,
          ),
        ));
        // The button is kept in the tree (maintainSize) but wrapped in an
        // invisible Visibility widget so layout is stable.
        final visibilityFinder = find.ancestor(
          of: find.byKey(const Key('remove-slot-0')),
          matching: find.byType(Visibility),
        );
        expect(visibilityFinder, findsOneWidget);
        expect(tester.widget<Visibility>(visibilityFinder).visible, isFalse);
      });

      testWidgets('remove button is shown for each card when two or more slots', (tester) async {
        final schedule = SlotSchedule(slots: [
          WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 8)),
          const MonthlySlot(dayOfMonth: 5, timeOfDay: Duration(hours: 9)),
        ]);
        await tester.pumpWidget(_wrap(
          SlotScheduleEditor(
            schedule: schedule,
            onChanged: (_) {},
            showTimePicker: _noopTimePicker,
          ),
        ));
        expect(find.byKey(const Key('remove-slot-0')), findsOneWidget);
        expect(find.byKey(const Key('remove-slot-1')), findsOneWidget);
      });

      testWidgets('add-weekly-slot and add-monthly-slot buttons are present', (tester) async {
        final schedule = SlotSchedule(slots: [
          WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 8)),
        ]);
        await tester.pumpWidget(_wrap(
          SlotScheduleEditor(
            schedule: schedule,
            onChanged: (_) {},
            showTimePicker: _noopTimePicker,
          ),
        ));
        expect(find.byKey(const Key('add-weekly-slot')), findsOneWidget);
        expect(find.byKey(const Key('add-monthly-slot')), findsOneWidget);
      });
    });

    group('adding slots', () {
      testWidgets('tapping add-weekly-slot emits schedule with a new WeeklySlot appended', (tester) async {
        const schedule = SlotSchedule(slots: [
          MonthlySlot(dayOfMonth: 1, timeOfDay: Duration(hours: 8)),
        ]);
        SlotSchedule? emitted;
        await tester.pumpWidget(_wrap(
          SlotScheduleEditor(
            schedule: schedule,
            onChanged: (s) => emitted = s,
            showTimePicker: _noopTimePicker,
          ),
        ));

        await tester.tap(find.byKey(const Key('add-weekly-slot')));
        await tester.pump();

        expect(emitted, isNotNull);
        expect(emitted!.slots.length, 2);
        expect(emitted!.slots[0], isA<MonthlySlot>());
        expect(emitted!.slots[1], isA<WeeklySlot>());
      });

      testWidgets('tapping add-monthly-slot emits schedule with a new MonthlySlot appended', (tester) async {
        final schedule = SlotSchedule(slots: [
          WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 8)),
        ]);
        SlotSchedule? emitted;
        await tester.pumpWidget(_wrap(
          SlotScheduleEditor(
            schedule: schedule,
            onChanged: (s) => emitted = s,
            showTimePicker: _noopTimePicker,
          ),
        ));

        await tester.tap(find.byKey(const Key('add-monthly-slot')));
        await tester.pump();

        expect(emitted, isNotNull);
        expect(emitted!.slots.length, 2);
        expect(emitted!.slots[0], isA<WeeklySlot>());
        expect(emitted!.slots[1], isA<MonthlySlot>());
      });
    });

    group('removing slots', () {
      testWidgets('tapping remove on first slot emits schedule without that slot', (tester) async {
        final schedule = SlotSchedule(slots: [
          WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 8)),
          const MonthlySlot(dayOfMonth: 15, timeOfDay: Duration(hours: 18)),
        ]);
        SlotSchedule? emitted;
        await tester.pumpWidget(_wrap(
          SlotScheduleEditor(
            schedule: schedule,
            onChanged: (s) => emitted = s,
            showTimePicker: _noopTimePicker,
          ),
        ));

        await tester.tap(find.byKey(const Key('remove-slot-0')));
        await tester.pump();

        expect(emitted, isNotNull);
        expect(emitted!.slots.length, 1);
        expect(emitted!.slots[0], isA<MonthlySlot>());
      });

      testWidgets('tapping remove on second slot emits schedule without that slot', (tester) async {
        final schedule = SlotSchedule(slots: [
          WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 8)),
          const MonthlySlot(dayOfMonth: 15, timeOfDay: Duration(hours: 18)),
        ]);
        SlotSchedule? emitted;
        await tester.pumpWidget(_wrap(
          SlotScheduleEditor(
            schedule: schedule,
            onChanged: (s) => emitted = s,
            showTimePicker: _noopTimePicker,
          ),
        ));

        await tester.tap(find.byKey(const Key('remove-slot-1')));
        await tester.pump();

        expect(emitted, isNotNull);
        expect(emitted!.slots.length, 1);
        expect(emitted!.slots[0], isA<WeeklySlot>());
      });
    });

    group('weekday toggling (WeeklySlot)', () {
      testWidgets('tapping an unselected weekday button adds it to the slot', (tester) async {
        // Start with Mon only selected.
        final schedule = SlotSchedule(slots: [
          WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 8)),
        ]);
        SlotSchedule? emitted;
        await tester.pumpWidget(_wrap(
          SlotScheduleEditor(
            schedule: schedule,
            onChanged: (s) => emitted = s,
            showTimePicker: _noopTimePicker,
          ),
        ));

        // Tap the Wed button (weekday 3).
        await tester.tap(find.byKey(const Key('weekday-0-3')));
        await tester.pump();

        expect(emitted, isNotNull);
        final slot = emitted!.slots[0] as WeeklySlot;
        expect(slot.weekdays, containsAll([1, 3]));
      });

      testWidgets('tapping a selected weekday button removes it when others remain', (tester) async {
        // Start with Mon+Tue selected.
        final schedule = SlotSchedule(slots: [
          WeeklySlot(weekdays: {1, 2}, timeOfDay: const Duration(hours: 8)),
        ]);
        SlotSchedule? emitted;
        await tester.pumpWidget(_wrap(
          SlotScheduleEditor(
            schedule: schedule,
            onChanged: (s) => emitted = s,
            showTimePicker: _noopTimePicker,
          ),
        ));

        // Tap Mon (weekday 1) to deselect it.
        await tester.tap(find.byKey(const Key('weekday-0-1')));
        await tester.pump();

        expect(emitted, isNotNull);
        final slot = emitted!.slots[0] as WeeklySlot;
        expect(slot.weekdays, equals({2}));
      });

      testWidgets('tapping the last selected weekday is a no-op (cannot have 0 weekdays)', (tester) async {
        // Only Mon selected — cannot remove it.
        final schedule = SlotSchedule(slots: [
          WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 8)),
        ]);
        SlotSchedule? emitted;
        await tester.pumpWidget(_wrap(
          SlotScheduleEditor(
            schedule: schedule,
            onChanged: (s) => emitted = s,
            showTimePicker: _noopTimePicker,
          ),
        ));

        await tester.tap(find.byKey(const Key('weekday-0-1')));
        await tester.pump();

        // onChanged must NOT have been called (no-op).
        expect(emitted, isNull);
      });
    });

    group('time picker (WeeklySlot)', () {
      testWidgets('tapping time chip calls showTimePicker and emits updated slot on non-null return', (tester) async {
        final schedule = SlotSchedule(slots: [
          WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 8)),
        ]);
        SlotSchedule? emitted;
        await tester.pumpWidget(_wrap(
          SlotScheduleEditor(
            schedule: schedule,
            onChanged: (s) => emitted = s,
            showTimePicker: _fixedTimePicker,
          ),
        ));

        await tester.tap(find.byKey(const Key('time-chip-0')));
        await tester.pump();

        expect(emitted, isNotNull);
        final slot = emitted!.slots[0] as WeeklySlot;
        expect(slot.timeOfDay, const Duration(hours: 9, minutes: 15));
      });

      testWidgets('tapping time chip does not emit when showTimePicker returns null (cancelled)', (tester) async {
        final schedule = SlotSchedule(slots: [
          WeeklySlot(weekdays: {1}, timeOfDay: const Duration(hours: 8)),
        ]);
        SlotSchedule? emitted;
        await tester.pumpWidget(_wrap(
          SlotScheduleEditor(
            schedule: schedule,
            onChanged: (s) => emitted = s,
            showTimePicker: _noopTimePicker,
          ),
        ));

        await tester.tap(find.byKey(const Key('time-chip-0')));
        await tester.pump();

        expect(emitted, isNull);
      });
    });

    group('day-of-month picker (MonthlySlot)', () {
      testWidgets('MonthlySlot card shows a day-of-month selector', (tester) async {
        const schedule = SlotSchedule(slots: [
          MonthlySlot(dayOfMonth: 15, timeOfDay: Duration(hours: 8)),
        ]);
        await tester.pumpWidget(_wrap(
          SlotScheduleEditor(
            schedule: schedule,
            onChanged: (_) {},
            showTimePicker: _noopTimePicker,
          ),
        ));
        expect(find.byKey(const Key('day-of-month-0')), findsOneWidget);
      });
    });
  });
}
