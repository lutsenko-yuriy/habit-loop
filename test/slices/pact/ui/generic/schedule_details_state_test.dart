import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/schedule_details_state.dart';

// ---------------------------------------------------------------------------
// Test harness — minimal StatefulWidget that mixes in ScheduleDetailsState.
// ---------------------------------------------------------------------------

class _TestDetailsWidget extends StatefulWidget {
  final PactCreationState state;

  const _TestDetailsWidget({required this.state});

  @override
  State<_TestDetailsWidget> createState() => _TestDetailsWidgetState();
}

class _TestDetailsWidgetState extends State<_TestDetailsWidget> with ScheduleDetailsState<_TestDetailsWidget> {
  @override
  PactCreationState get detailsState => widget.state;

  @override
  AppLocalizations get detailsL10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    initScheduleDetails();
  }

  @override
  Widget buildDailyDetails() => Text('daily:${dailyTime.inHours}h');

  @override
  Widget buildWeekdayDetails() => Text('weekday:${weekdayEntries.length}');

  @override
  Widget buildMonthlyByWeekdayDetails() => Text('monthlyByWeekday:${monthlyWeekdayEntries.length}');

  @override
  Widget buildMonthlyByDateDetails() => Text('monthlyByDate:${monthlyDateEntries.length}');

  @override
  Widget buildSlotDetails() => const Text('slot');

  @override
  Widget build(BuildContext context) => buildScheduleDetails(context);
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(_TestDetailsWidget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

PactCreationState _stateWith({
  required ScheduleType scheduleType,
  ShowupSchedule? schedule,
}) {
  final base = PactCreationState(today: DateTime(2026, 1, 1));
  return base.copyWith(
    builder: base.builder.copyWith(scheduleType: scheduleType, schedule: schedule),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('initScheduleDetails — daily time', () {
    testWidgets('initializes dailyTime from DailySchedule', (tester) async {
      final state = _stateWith(
        scheduleType: ScheduleType.daily,
        schedule: const DailySchedule(timeOfDay: Duration(hours: 9, minutes: 30)),
      );
      await tester.pumpWidget(_wrap(_TestDetailsWidget(state: state)));
      await tester.pump();
      expect(find.text('daily:9h'), findsOneWidget);
    });

    testWidgets('defaults dailyTime to 8h when schedule is not DailySchedule', (tester) async {
      final state = _stateWith(scheduleType: ScheduleType.daily);
      await tester.pumpWidget(_wrap(_TestDetailsWidget(state: state)));
      await tester.pump();
      expect(find.text('daily:8h'), findsOneWidget);
    });
  });

  group('initScheduleDetails — weekday entries', () {
    testWidgets('initializes weekdayEntries from WeekdaySchedule', (tester) async {
      final state = _stateWith(
        scheduleType: ScheduleType.weekday,
        schedule: const WeekdaySchedule(entries: [
          WeekdayEntry(weekday: 3, timeOfDay: Duration(hours: 10)),
          WeekdayEntry(weekday: 5, timeOfDay: Duration(hours: 11)),
        ]),
      );
      await tester.pumpWidget(_wrap(_TestDetailsWidget(state: state)));
      await tester.pump();
      expect(find.text('weekday:2'), findsOneWidget);
    });

    testWidgets('defaults weekdayEntries to one entry when no WeekdaySchedule', (tester) async {
      final state = _stateWith(scheduleType: ScheduleType.weekday);
      await tester.pumpWidget(_wrap(_TestDetailsWidget(state: state)));
      await tester.pump();
      expect(find.text('weekday:1'), findsOneWidget);
    });
  });

  group('initScheduleDetails — monthly entries', () {
    testWidgets('initializes monthlyWeekdayEntries from MonthlyByWeekdaySchedule', (tester) async {
      final state = _stateWith(
        scheduleType: ScheduleType.monthlyByWeekday,
        schedule: const MonthlyByWeekdaySchedule(entries: [
          MonthlyWeekdayEntry(occurrence: 1, weekday: 1, timeOfDay: Duration(hours: 8)),
          MonthlyWeekdayEntry(occurrence: 2, weekday: 3, timeOfDay: Duration(hours: 9)),
        ]),
      );
      await tester.pumpWidget(_wrap(_TestDetailsWidget(state: state)));
      await tester.pump();
      expect(find.text('monthlyByWeekday:2'), findsOneWidget);
    });

    testWidgets('initializes monthlyDateEntries from MonthlyByDateSchedule', (tester) async {
      final state = _stateWith(
        scheduleType: ScheduleType.monthlyByDate,
        schedule: const MonthlyByDateSchedule(entries: [
          MonthlyDateEntry(dayOfMonth: 15, timeOfDay: Duration(hours: 8)),
        ]),
      );
      await tester.pumpWidget(_wrap(_TestDetailsWidget(state: state)));
      await tester.pump();
      expect(find.text('monthlyByDate:1'), findsOneWidget);
    });
  });

  group('buildScheduleDetails dispatch', () {
    testWidgets('dispatches to buildDailyDetails for daily type', (tester) async {
      final state = _stateWith(scheduleType: ScheduleType.daily);
      await tester.pumpWidget(_wrap(_TestDetailsWidget(state: state)));
      await tester.pump();
      expect(find.textContaining('daily:'), findsOneWidget);
    });

    testWidgets('dispatches to buildWeekdayDetails for weekday type', (tester) async {
      final state = _stateWith(scheduleType: ScheduleType.weekday);
      await tester.pumpWidget(_wrap(_TestDetailsWidget(state: state)));
      await tester.pump();
      expect(find.textContaining('weekday:'), findsOneWidget);
    });

    testWidgets('dispatches to buildMonthlyByWeekdayDetails', (tester) async {
      final state = _stateWith(scheduleType: ScheduleType.monthlyByWeekday);
      await tester.pumpWidget(_wrap(_TestDetailsWidget(state: state)));
      await tester.pump();
      expect(find.textContaining('monthlyByWeekday:'), findsOneWidget);
    });

    testWidgets('dispatches to buildMonthlyByDateDetails', (tester) async {
      final state = _stateWith(scheduleType: ScheduleType.monthlyByDate);
      await tester.pumpWidget(_wrap(_TestDetailsWidget(state: state)));
      await tester.pump();
      expect(find.textContaining('monthlyByDate:'), findsOneWidget);
    });

    testWidgets('dispatches to buildSlotDetails for slot type', (tester) async {
      final state = _stateWith(
        scheduleType: ScheduleType.slot,
        schedule: const SlotSchedule(slots: []),
      );
      await tester.pumpWidget(_wrap(_TestDetailsWidget(state: state)));
      await tester.pump();
      expect(find.text('slot'), findsOneWidget);
    });
  });
}
