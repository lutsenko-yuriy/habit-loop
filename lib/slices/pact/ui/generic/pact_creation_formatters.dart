import 'package:flutter/material.dart' show BuildContext, TimeOfDay;
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

// Single definition so all call sites share the same yMd format.
String formatPactDate(BuildContext context, DateTime date) => formatLocaleDate(context, date);

// Human-readable schedule summary for the commitment step. Empty string when null.
String scheduleDescription(
  BuildContext context,
  AppLocalizations l10n,
  ShowupSchedule? schedule,
) {
  if (schedule == null) return '';
  if (schedule is DailySchedule) {
    final t = TimeOfDay(
      hour: schedule.timeOfDay.inHours,
      minute: schedule.timeOfDay.inMinutes % 60,
    ).format(context);
    return '${l10n.scheduleDaily} @ $t';
  }
  if (schedule is WeekdaySchedule) {
    return '${l10n.scheduleWeekday} (${schedule.entries.length})';
  }
  if (schedule is MonthlyByWeekdaySchedule) {
    return '${l10n.scheduleMonthlyByWeekday} (${schedule.entries.length})';
  }
  if (schedule is MonthlyByDateSchedule) {
    return '${l10n.scheduleMonthlyByDate} (${schedule.entries.length})';
  }
  if (schedule is SlotSchedule) {
    if (schedule.slots.isEmpty) return '';
    final weeklyCount = schedule.slots.whereType<WeeklySlot>().length;
    final monthlyCount = schedule.slots.whereType<MonthlySlot>().length;
    if (weeklyCount > 0 && monthlyCount == 0) {
      return '${l10n.scheduleCardWeekly} ($weeklyCount)';
    }
    if (monthlyCount > 0 && weeklyCount == 0) {
      return '${l10n.scheduleCardMonthly} ($monthlyCount)';
    }
    // Mixed weekly + monthly.
    return '${l10n.scheduleCardWeekly} ($weeklyCount) / ${l10n.scheduleCardMonthly} ($monthlyCount)';
  }
  return '';
}

String reminderDescription(AppLocalizations l10n, Duration? offset) {
  if (offset == null) return l10n.reminderNone;
  if (offset == Duration.zero) return l10n.reminderAtStart;
  return l10n.reminderMinutesBefore(offset.inMinutes);
}

String weekdayName(AppLocalizations l10n, int weekday) {
  switch (weekday) {
    case 1:
      return l10n.weekdayMon;
    case 2:
      return l10n.weekdayTue;
    case 3:
      return l10n.weekdayWed;
    case 4:
      return l10n.weekdayThu;
    case 5:
      return l10n.weekdayFri;
    case 6:
      return l10n.weekdaySat;
    case 7:
      return l10n.weekdaySun;
    default:
      return '';
  }
}

String occurrenceName(AppLocalizations l10n, int occurrence) {
  switch (occurrence) {
    case 1:
      return l10n.occurrenceFirst;
    case 2:
      return l10n.occurrenceSecond;
    case 3:
      return l10n.occurrenceThird;
    case 4:
      return l10n.occurrenceFourth;
    default:
      return '';
  }
}
