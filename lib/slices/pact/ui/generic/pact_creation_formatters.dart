import 'package:flutter/material.dart' show BuildContext, TimeOfDay;
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/l10n/date_formatters.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

/// Formats a pact-related date using the ambient locale (e.g. `3/30/2026` in
/// en-US, `30/03/2026` in fr).
///
/// Extracted from `commitment_step_ios.dart` / `commitment_step_android.dart`
/// where the same formatter was declared privately in both platform widgets.
String formatPactDate(BuildContext context, DateTime date) => formatLocaleDate(context, date);

/// Builds the human-readable summary for a [ShowupSchedule] shown on the
/// commitment (review) step of the pact creation wizard.
///
/// Returns an empty string when [schedule] is `null` (wizard not yet filled in).
/// The [context] is only used to format the time-of-day inside [DailySchedule]
/// via [TimeOfDay.format], so it requires `MaterialLocalizations` to be in
/// scope. For the three entry-list schedules the output is simply the l10n
/// label with the entry count in parentheses, e.g. `Specific weekdays (3)`.
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
  return '';
}

/// Returns the reminder summary string for the commitment step:
/// - `null` offset → "No reminder"
/// - `Duration.zero` → "When it starts"
/// - positive offset → "N min before"
String reminderDescription(AppLocalizations l10n, Duration? offset) {
  if (offset == null) return l10n.reminderNone;
  if (offset == Duration.zero) return l10n.reminderAtStart;
  return l10n.reminderMinutesBefore(offset.inMinutes);
}

/// Maps an ISO weekday number (1 = Monday … 7 = Sunday) to its short localized
/// name. Returns an empty string for any other input.
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

/// Maps a monthly-by-weekday occurrence (1..4) to its localized ordinal (1st,
/// 2nd, 3rd, 4th in en). Returns an empty string for any other input.
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
