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
  String get noPactsDescription => 'Create your first pact to start building a habit.';

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
  String tooManyPactsBody(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: 'You can only have $max active pacts at a time. Are you sure you want to create more?',
      one: 'You can only have 1 active pact at a time. Are you sure you want to create another?',
    );
    return '$_temp0';
  }

  @override
  String get tooManyPactsConfirm => 'Yes, create another';

  @override
  String get pactDetailTitle => 'Pact Details';

  @override
  String get sectionStats => 'Stats';

  @override
  String get sectionTimeline => 'Timeline';

  @override
  String get sectionStopReason => 'Stop reason';

  @override
  String get stopPactError => 'Failed to stop pact. Please try again.';

  @override
  String get statsDone => 'Done';

  @override
  String get statsFailed => 'Failed';

  @override
  String get statsRemaining => 'Remaining';

  @override
  String get statsCancelled => 'Stopped';

  @override
  String get statsStreak => 'Streak';

  @override
  String statsShowups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count showups',
      one: '$count showup',
    );
    return '$_temp0';
  }

  @override
  String get pactStartDate => 'Started';

  @override
  String get pactEndDate => 'Ends';

  @override
  String get pactEndedDate => 'Ended';

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
  String get stopPactBody => 'This cannot be undone. You can still view the pact history afterwards.';

  @override
  String get stopPactReasonHint => 'Reason (optional)';

  @override
  String get stopPactConfirm => 'Stop';

  @override
  String pactsActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pacts active',
      one: '1 pact active',
      zero: 'No pacts active',
    );
    return '$_temp0';
  }

  @override
  String pactsDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pacts done',
      one: '1 pact done',
      zero: 'No pacts done',
    );
    return '$_temp0';
  }

  @override
  String pactsCancelled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pacts stopped',
      one: '1 pact stopped',
      zero: 'No pacts stopped',
    );
    return '$_temp0';
  }

  @override
  String get addPact => 'Add a pact';

  @override
  String get pactListTitle => 'Pacts';

  @override
  String get filterActive => 'Active';

  @override
  String get filterDone => 'Done';

  @override
  String get filterCancelled => 'Stopped';

  @override
  String pactNextShowup(String date) {
    return 'Next: $date';
  }

  @override
  String pactEndedOn(String date) {
    return 'Ended $date';
  }

  @override
  String pactCancelledOn(String date) {
    return 'Stopped $date';
  }

  @override
  String get showupDetailTitle => 'Showup Details';

  @override
  String get showupDetailHabit => 'Habit';

  @override
  String get showupDetailScheduledAt => 'Scheduled at';

  @override
  String get showupDetailDuration => 'Duration';

  @override
  String get showupDetailStatus => 'Status';

  @override
  String get markDone => 'Mark as Done';

  @override
  String get markFailed => 'Mark as Failed';

  @override
  String get showupAutoFailed =>
      'This showup was automatically marked as failed because it was opened after its scheduled time had passed.';

  @override
  String get showupNoteLabel => 'Note';

  @override
  String get showupNoteSave => 'Save Note';

  @override
  String get showupNoteError => 'Failed to save note. Please try again.';

  @override
  String get showupMarkError => 'Failed to update showup status. Please try again.';

  @override
  String get showupHabitDeleted => '(habit deleted)';

  @override
  String get showupNotFound => 'This showup is no longer available.';

  @override
  String get languagePickerTitle => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageFrench => 'French';

  @override
  String get languageGerman => 'German';

  @override
  String get languageRussian => 'Russian';

  @override
  String get languageSystem => 'Use system language';

  @override
  String notificationReminderTitle(String habitName) {
    return '$habitName, it\'s showup time!';
  }

  @override
  String get notificationReminderBody => 'Tap to mark your showup.';

  @override
  String notificationDeadlineTitle(String habitName) {
    return '$habitName: mark your showup done';
  }

  @override
  String notificationDeadlineBody(String time) {
    return 'Window closes at $time.';
  }

  @override
  String notificationTimeLimitTitle(String habitName) {
    return '$habitName: showup time!';
  }

  @override
  String notificationTimeLimitBody(String duration) {
    return 'You have $duration to mark it done.';
  }

  @override
  String get notificationMissedTitle => 'You missed this one';

  @override
  String get notificationMissedBody => 'That\'s okay — show up next time.';

  @override
  String notificationDurationMinutes(int count) {
    return '$count min';
  }

  @override
  String notificationDurationHours(int count) {
    return '$count h';
  }
}
