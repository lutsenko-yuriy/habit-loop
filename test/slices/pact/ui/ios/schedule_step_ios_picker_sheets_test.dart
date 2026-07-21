/// HAB-187 WU2 — regression coverage for the picker-triggering call sites in
/// `schedule_step_ios.dart` after they were rewired onto the shared
/// `showCupertinoPickerSheet` helper (`cupertino_picker_sheet.dart`).
///
/// Each test drives a real call site (the daily time row, the weekday
/// dropdown, the monthly-by-weekday occurrence/weekday dropdowns, and the
/// day-of-month picker) end to end: tap to open the sheet, invoke the
/// underlying Cupertino picker's own change callback (dragging a wheel
/// picker in a widget test is unreliable), then assert `onScheduleChanged`
/// fires with the expected updated schedule.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/ios/schedule_step_ios.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _IosStepWrapper extends StatelessWidget {
  final PactCreationState state;
  final ValueChanged<ShowupSchedule> onScheduleChanged;

  const _IosStepWrapper({required this.state, required this.onScheduleChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ScheduleStepIos(
      state: state,
      l10n: l10n,
      onScheduleTypeChanged: (_) {},
      onScheduleChanged: onScheduleChanged,
    );
  }
}

Widget _wrapIos(Widget child) {
  return CupertinoApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: CupertinoPageScaffold(
      child: SafeArea(child: child),
    ),
  );
}

PactCreationState _stateFor({required ScheduleType scheduleType, required ShowupSchedule schedule}) {
  final base = PactCreationState(today: DateTime(2026, 3, 30));
  return base.copyWith(
    builder: base.builder.copyWith(scheduleType: scheduleType, schedule: schedule),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  testWidgets('daily: tapping the time row opens a sheet and selecting a time fires onScheduleChanged', (tester) async {
    ShowupSchedule? emitted;
    final state = _stateFor(
      scheduleType: ScheduleType.daily,
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
    );
    await tester.pumpWidget(_wrapIos(
      _IosStepWrapper(state: state, onScheduleChanged: (s) => emitted = s),
    ));
    await tester.pump();

    await tester.tap(find.text('Time'));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
    picker.onDateTimeChanged(DateTime(2026, 1, 1, 9, 30));
    await tester.pump();

    expect(emitted, const DailySchedule(timeOfDay: Duration(hours: 9, minutes: 30)));

    await tester.tap(find.widgetWithText(CupertinoButton, 'Done'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsNothing);
  });

  testWidgets('weekday: tapping the weekday dropdown opens a sheet and selecting a day fires onScheduleChanged',
      (tester) async {
    ShowupSchedule? emitted;
    final state = _stateFor(
      scheduleType: ScheduleType.weekday,
      schedule: const WeekdaySchedule(entries: [WeekdayEntry(weekday: 1, timeOfDay: Duration(hours: 8))]),
    );
    await tester.pumpWidget(_wrapIos(
      _IosStepWrapper(state: state, onScheduleChanged: (s) => emitted = s),
    ));
    await tester.pump();

    await tester.tap(find.widgetWithText(CupertinoButton, 'Mon'));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    picker.onSelectedItemChanged!(2); // index 2 -> weekday 3 (Wed)
    await tester.pump();

    expect(
      emitted,
      const WeekdaySchedule(entries: [WeekdayEntry(weekday: 3, timeOfDay: Duration(hours: 8))]),
    );
  });

  testWidgets(
      'monthlyByWeekday: tapping the occurrence dropdown opens a sheet and selecting an occurrence fires onScheduleChanged',
      (tester) async {
    ShowupSchedule? emitted;
    final state = _stateFor(
      scheduleType: ScheduleType.monthlyByWeekday,
      schedule: const MonthlyByWeekdaySchedule(
        entries: [MonthlyWeekdayEntry(occurrence: 1, weekday: 1, timeOfDay: Duration(hours: 8))],
      ),
    );
    await tester.pumpWidget(_wrapIos(
      _IosStepWrapper(state: state, onScheduleChanged: (s) => emitted = s),
    ));
    await tester.pump();

    await tester.tap(find.widgetWithText(CupertinoButton, '1st'));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    picker.onSelectedItemChanged!(1); // index 1 -> occurrence 2 (2nd)
    await tester.pump();

    expect(
      emitted,
      const MonthlyByWeekdaySchedule(
        entries: [MonthlyWeekdayEntry(occurrence: 2, weekday: 1, timeOfDay: Duration(hours: 8))],
      ),
    );
  });

  testWidgets(
      'monthlyByDate: tapping the day-of-month picker opens a sheet and selecting a day fires '
      'onScheduleChanged', (tester) async {
    ShowupSchedule? emitted;
    final state = _stateFor(
      scheduleType: ScheduleType.monthlyByDate,
      schedule: const MonthlyByDateSchedule(entries: [MonthlyDateEntry(dayOfMonth: 1, timeOfDay: Duration(hours: 8))]),
    );
    await tester.pumpWidget(_wrapIos(
      _IosStepWrapper(state: state, onScheduleChanged: (s) => emitted = s),
    ));
    await tester.pump();

    await tester.tap(find.text('Day of month: 1'));
    await tester.pumpAndSettle();

    final picker = tester.widget<CupertinoPicker>(find.byType(CupertinoPicker));
    picker.onSelectedItemChanged!(14); // index 14 -> day 15
    await tester.pump();

    expect(
      emitted,
      const MonthlyByDateSchedule(entries: [MonthlyDateEntry(dayOfMonth: 15, timeOfDay: Duration(hours: 8))]),
    );
  });
}
