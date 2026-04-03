// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Habit Loop';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get todayShowups => 'Today\'s Showups';

  @override
  String get noPactsYet => 'No pacts yet';

  @override
  String get noPactsDescription =>
      'Create your first pact to start building a habit.';

  @override
  String get createPact => 'Create a Pact';

  @override
  String get noShowupsForDay => 'No showups for this day';

  @override
  String get showupDone => 'Done';

  @override
  String get showupFailed => 'Failed';

  @override
  String get showupPending => 'Pending';

  @override
  String get pactCreationTitle => 'New Pact';

  @override
  String get habitNameLabel => 'Habit name';

  @override
  String get habitNameHint => 'e.g., Meditate, Jog, Read…';

  @override
  String get pactDurationStep => 'Pact Duration';

  @override
  String get startDateLabel => 'Start date';

  @override
  String get endDateLabel => 'End date';

  @override
  String get showupDurationStep => 'Showup Duration';

  @override
  String get showupDurationLabel => 'How long is each showup?';

  @override
  String showupDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get scheduleStep => 'Schedule';

  @override
  String get scheduleTypeLabel => 'When do you want to show up?';

  @override
  String get scheduleDaily => 'Every day';

  @override
  String get scheduleWeekday => 'Specific weekdays';

  @override
  String get scheduleMonthlyByWeekday => 'Monthly by weekday';

  @override
  String get scheduleMonthlyByDate => 'Monthly by date';

  @override
  String get timeOfDayLabel => 'Time';

  @override
  String get addEntry => 'Add another';

  @override
  String get removeEntry => 'Remove';

  @override
  String get weekdayMon => 'Mon';

  @override
  String get weekdayTue => 'Tue';

  @override
  String get weekdayWed => 'Wed';

  @override
  String get weekdayThu => 'Thu';

  @override
  String get weekdayFri => 'Fri';

  @override
  String get weekdaySat => 'Sat';

  @override
  String get weekdaySun => 'Sun';

  @override
  String get occurrenceFirst => '1st';

  @override
  String get occurrenceSecond => '2nd';

  @override
  String get occurrenceThird => '3rd';

  @override
  String get occurrenceFourth => '4th';

  @override
  String get dayOfMonthLabel => 'Day of month';

  @override
  String get reminderStep => 'Reminder';

  @override
  String get reminderLabel => 'Remind me before showup';

  @override
  String get reminderNone => 'No reminder';

  @override
  String get reminderAtStart => 'When it starts';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min before';
  }

  @override
  String get summaryHabit => 'Habit';

  @override
  String get summaryDuration => 'Pact duration';

  @override
  String get summaryShowupDuration => 'Showup duration';

  @override
  String get summarySchedule => 'Schedule';

  @override
  String get summaryReminder => 'Reminder';

  @override
  String get commitmentStep => 'Commitment';

  @override
  String get commitmentWarning =>
      'Missing a showup counts as a failure. There are no exceptions and no pausing a pact. By creating this pact, you commit to showing up every time.';

  @override
  String get commitmentAccept => 'I understand and commit';

  @override
  String get createPactConfirm => 'Create Pact';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get cancel => 'Cancel';

  @override
  String get tooManyPactsTitle => 'Too many active pacts';

  @override
  String tooManyPactsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'You already have $count active pacts. Are you sure you want to create more?',
      one:
          'You already have 1 active pact. Are you sure you want to create another?',
    );
    return '$_temp0';
  }

  @override
  String get tooManyPactsConfirm => 'Yes, create another';

  @override
  String get pactDetailTitle => 'Pact Details';

  @override
  String get statsDone => 'Done';

  @override
  String get statsFailed => 'Failed';

  @override
  String get statsRemaining => 'Remaining';

  @override
  String get statsStreak => 'Streak';

  @override
  String statsShowups(int count) {
    return '$count showups';
  }

  @override
  String get pactStartDate => 'Started';

  @override
  String get pactEndDate => 'Ends';

  @override
  String daysRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days remaining',
      one: '1 day remaining',
    );
    return '$_temp0';
  }

  @override
  String get pactStatusActive => 'Active';

  @override
  String get pactStatusStopped => 'Stopped';

  @override
  String get pactStatusCompleted => 'Completed';

  @override
  String get stopPact => 'Stop Pact';

  @override
  String get stopPactTitle => 'Stop this pact?';

  @override
  String get stopPactBody =>
      'This cannot be undone. You can still view the pact history afterwards.';

  @override
  String get stopPactReasonHint => 'Reason (optional)';

  @override
  String get stopPactConfirm => 'Stop';
}
