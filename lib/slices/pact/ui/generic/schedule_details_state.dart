import 'package:flutter/widgets.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/pact/application/pact_creation_state.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_formatters.dart' as pf;

/// Mixin for [State] classes that back a schedule-details editor.
///
/// Provides shared state fields, a common [initScheduleDetails] bootstrapper,
/// helpers for weekday/occurrence name formatting, and a [buildScheduleDetails]
/// dispatcher that routes to the five abstract build methods.
mixin ScheduleDetailsState<T extends StatefulWidget> on State<T> {
  PactCreationState get detailsState;
  AppLocalizations get detailsL10n;
  ValueChanged<ShowupSchedule> get detailsOnScheduleChanged;

  late Duration dailyTime;
  late List<WeekdayEntry> weekdayEntries;
  late List<MonthlyWeekdayEntry> monthlyWeekdayEntries;
  late List<MonthlyDateEntry> monthlyDateEntries;

  void initScheduleDetails() {
    final schedule = detailsState.schedule;
    dailyTime = schedule is DailySchedule ? schedule.timeOfDay : const Duration(hours: 8);
    weekdayEntries = schedule is WeekdaySchedule
        ? List.of(schedule.entries)
        : [const WeekdayEntry(weekday: 1, timeOfDay: Duration(hours: 8))];
    monthlyWeekdayEntries = schedule is MonthlyByWeekdaySchedule
        ? List.of(schedule.entries)
        : [const MonthlyWeekdayEntry(occurrence: 1, weekday: 1, timeOfDay: Duration(hours: 8))];
    monthlyDateEntries = schedule is MonthlyByDateSchedule
        ? List.of(schedule.entries)
        : [const MonthlyDateEntry(dayOfMonth: 1, timeOfDay: Duration(hours: 8))];
  }

  String weekdayNameFor(int weekday) => pf.weekdayName(detailsL10n, weekday);
  String occurrenceNameFor(int occurrence) => pf.occurrenceName(detailsL10n, occurrence);

  Widget buildDailyDetails();
  Widget buildWeekdayDetails();
  Widget buildMonthlyByWeekdayDetails();
  Widget buildMonthlyByDateDetails();
  Widget buildSlotDetails();

  Widget buildScheduleDetails(BuildContext context) {
    switch (detailsState.scheduleType!) {
      case ScheduleType.daily:
        return buildDailyDetails();
      case ScheduleType.weekday:
        return buildWeekdayDetails();
      case ScheduleType.monthlyByWeekday:
        return buildMonthlyByWeekdayDetails();
      case ScheduleType.monthlyByDate:
        return buildMonthlyByDateDetails();
      case ScheduleType.slot:
        return buildSlotDetails();
    }
  }
}
