import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('fr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Habit Loop'**
  String get appTitle;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @todayShowups.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Showups'**
  String get todayShowups;

  /// No description provided for @noPactsYet.
  ///
  /// In en, this message translates to:
  /// **'No pacts yet'**
  String get noPactsYet;

  /// No description provided for @noPactsDescription.
  ///
  /// In en, this message translates to:
  /// **'Create your first pact to start building a habit.'**
  String get noPactsDescription;

  /// No description provided for @createPact.
  ///
  /// In en, this message translates to:
  /// **'Create a Pact'**
  String get createPact;

  /// No description provided for @noShowupsForDay.
  ///
  /// In en, this message translates to:
  /// **'No showups for this day'**
  String get noShowupsForDay;

  /// No description provided for @showupDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get showupDone;

  /// No description provided for @showupFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get showupFailed;

  /// No description provided for @showupPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get showupPending;

  /// No description provided for @pactCreationTitle.
  ///
  /// In en, this message translates to:
  /// **'New Pact'**
  String get pactCreationTitle;

  /// No description provided for @habitNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Habit name'**
  String get habitNameLabel;

  /// No description provided for @habitNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Meditate, Jog, Read…'**
  String get habitNameHint;

  /// No description provided for @pactDurationStep.
  ///
  /// In en, this message translates to:
  /// **'Pact Duration'**
  String get pactDurationStep;

  /// No description provided for @startDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get startDateLabel;

  /// No description provided for @endDateLabel.
  ///
  /// In en, this message translates to:
  /// **'End date'**
  String get endDateLabel;

  /// No description provided for @showupDurationStep.
  ///
  /// In en, this message translates to:
  /// **'Showup Duration'**
  String get showupDurationStep;

  /// No description provided for @showupDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'How long is each showup?'**
  String get showupDurationLabel;

  /// No description provided for @showupDurationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String showupDurationMinutes(int minutes);

  /// No description provided for @scheduleStep.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get scheduleStep;

  /// No description provided for @scheduleTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'When do you want to show up?'**
  String get scheduleTypeLabel;

  /// No description provided for @scheduleDaily.
  ///
  /// In en, this message translates to:
  /// **'Every day'**
  String get scheduleDaily;

  /// No description provided for @scheduleWeekday.
  ///
  /// In en, this message translates to:
  /// **'Specific weekdays'**
  String get scheduleWeekday;

  /// No description provided for @scheduleMonthlyByWeekday.
  ///
  /// In en, this message translates to:
  /// **'Monthly by weekday'**
  String get scheduleMonthlyByWeekday;

  /// No description provided for @scheduleMonthlyByDate.
  ///
  /// In en, this message translates to:
  /// **'Monthly by date'**
  String get scheduleMonthlyByDate;

  /// No description provided for @timeOfDayLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeOfDayLabel;

  /// No description provided for @addEntry.
  ///
  /// In en, this message translates to:
  /// **'Add another'**
  String get addEntry;

  /// No description provided for @removeEntry.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get removeEntry;

  /// No description provided for @weekdayMon.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMon;

  /// No description provided for @weekdayTue.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTue;

  /// No description provided for @weekdayWed.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWed;

  /// No description provided for @weekdayThu.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThu;

  /// No description provided for @weekdayFri.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFri;

  /// No description provided for @weekdaySat.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySat;

  /// No description provided for @weekdaySun.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySun;

  /// No description provided for @occurrenceFirst.
  ///
  /// In en, this message translates to:
  /// **'1st'**
  String get occurrenceFirst;

  /// No description provided for @occurrenceSecond.
  ///
  /// In en, this message translates to:
  /// **'2nd'**
  String get occurrenceSecond;

  /// No description provided for @occurrenceThird.
  ///
  /// In en, this message translates to:
  /// **'3rd'**
  String get occurrenceThird;

  /// No description provided for @occurrenceFourth.
  ///
  /// In en, this message translates to:
  /// **'4th'**
  String get occurrenceFourth;

  /// No description provided for @dayOfMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'Day of month'**
  String get dayOfMonthLabel;

  /// No description provided for @reminderStep.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get reminderStep;

  /// No description provided for @reminderLabel.
  ///
  /// In en, this message translates to:
  /// **'Remind me before showup'**
  String get reminderLabel;

  /// No description provided for @reminderNone.
  ///
  /// In en, this message translates to:
  /// **'No reminder'**
  String get reminderNone;

  /// No description provided for @reminderAtStart.
  ///
  /// In en, this message translates to:
  /// **'When it starts'**
  String get reminderAtStart;

  /// No description provided for @reminderMinutesBefore.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min before'**
  String reminderMinutesBefore(int minutes);

  /// No description provided for @summaryHabit.
  ///
  /// In en, this message translates to:
  /// **'Habit'**
  String get summaryHabit;

  /// No description provided for @summaryDuration.
  ///
  /// In en, this message translates to:
  /// **'Pact duration'**
  String get summaryDuration;

  /// No description provided for @summaryShowupDuration.
  ///
  /// In en, this message translates to:
  /// **'Showup duration'**
  String get summaryShowupDuration;

  /// No description provided for @summarySchedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get summarySchedule;

  /// No description provided for @summaryReminder.
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get summaryReminder;

  /// No description provided for @commitmentStep.
  ///
  /// In en, this message translates to:
  /// **'Commitment'**
  String get commitmentStep;

  /// No description provided for @commitmentWarning.
  ///
  /// In en, this message translates to:
  /// **'Missing a showup counts as a failure. There are no exceptions and no pausing a pact. By creating this pact, you commit to showing up every time.'**
  String get commitmentWarning;

  /// No description provided for @commitmentAccept.
  ///
  /// In en, this message translates to:
  /// **'I understand and commit'**
  String get commitmentAccept;

  /// No description provided for @createPactConfirm.
  ///
  /// In en, this message translates to:
  /// **'Create Pact'**
  String get createPactConfirm;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @tooManyPactsTitle.
  ///
  /// In en, this message translates to:
  /// **'Too many active pacts'**
  String get tooManyPactsTitle;

  /// No description provided for @tooManyPactsBody.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{You already have 1 active pact. Are you sure you want to create another?} other{You already have {count} active pacts. Are you sure you want to create more?}}'**
  String tooManyPactsBody(int count);

  /// No description provided for @tooManyPactsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Yes, create another'**
  String get tooManyPactsConfirm;

  /// No description provided for @pactDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Pact Details'**
  String get pactDetailTitle;

  /// No description provided for @sectionStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get sectionStats;

  /// No description provided for @sectionTimeline.
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get sectionTimeline;

  /// No description provided for @sectionStopReason.
  ///
  /// In en, this message translates to:
  /// **'Stop reason'**
  String get sectionStopReason;

  /// No description provided for @stopPactError.
  ///
  /// In en, this message translates to:
  /// **'Failed to stop pact. Please try again.'**
  String get stopPactError;

  /// No description provided for @statsDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get statsDone;

  /// No description provided for @statsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statsFailed;

  /// No description provided for @statsRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get statsRemaining;

  /// No description provided for @statsCancelled.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get statsCancelled;

  /// No description provided for @statsStreak.
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get statsStreak;

  /// No description provided for @statsShowups.
  ///
  /// In en, this message translates to:
  /// **'{count} showups'**
  String statsShowups(int count);

  /// No description provided for @pactStartDate.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get pactStartDate;

  /// No description provided for @pactEndDate.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get pactEndDate;

  /// No description provided for @pactEndedDate.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get pactEndedDate;

  /// No description provided for @daysRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{1 day remaining} other{{count} days remaining}}'**
  String daysRemaining(int count);

  /// No description provided for @pactStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get pactStatusActive;

  /// No description provided for @pactStatusStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get pactStatusStopped;

  /// No description provided for @pactStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get pactStatusCompleted;

  /// No description provided for @stopPact.
  ///
  /// In en, this message translates to:
  /// **'Stop Pact'**
  String get stopPact;

  /// No description provided for @stopPactTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop this pact?'**
  String get stopPactTitle;

  /// No description provided for @stopPactBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone. You can still view the pact history afterwards.'**
  String get stopPactBody;

  /// No description provided for @stopPactReasonHint.
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get stopPactReasonHint;

  /// No description provided for @stopPactConfirm.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopPactConfirm;

  /// No description provided for @pactsActive.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No pacts active} one{1 pact active} other{{count} pacts active}}'**
  String pactsActive(int count);

  /// No description provided for @pactsDone.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No pacts done} one{1 pact done} other{{count} pacts done}}'**
  String pactsDone(int count);

  /// No description provided for @pactsCancelled.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No pacts stopped} one{1 pact stopped} other{{count} pacts stopped}}'**
  String pactsCancelled(int count);

  /// No description provided for @addPact.
  ///
  /// In en, this message translates to:
  /// **'Add a pact'**
  String get addPact;

  /// No description provided for @pactListTitle.
  ///
  /// In en, this message translates to:
  /// **'Pacts'**
  String get pactListTitle;

  /// No description provided for @filterActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get filterActive;

  /// No description provided for @filterDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get filterDone;

  /// No description provided for @filterCancelled.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get filterCancelled;

  /// No description provided for @pactNextShowup.
  ///
  /// In en, this message translates to:
  /// **'Next: {date}'**
  String pactNextShowup(String date);

  /// No description provided for @pactEndedOn.
  ///
  /// In en, this message translates to:
  /// **'Ended {date}'**
  String pactEndedOn(String date);

  /// No description provided for @pactCancelledOn.
  ///
  /// In en, this message translates to:
  /// **'Stopped {date}'**
  String pactCancelledOn(String date);

  /// No description provided for @showupDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Showup Details'**
  String get showupDetailTitle;

  /// No description provided for @showupDetailHabit.
  ///
  /// In en, this message translates to:
  /// **'Habit'**
  String get showupDetailHabit;

  /// No description provided for @showupDetailScheduledAt.
  ///
  /// In en, this message translates to:
  /// **'Scheduled at'**
  String get showupDetailScheduledAt;

  /// No description provided for @showupDetailDuration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get showupDetailDuration;

  /// No description provided for @showupDetailStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get showupDetailStatus;

  /// No description provided for @markDone.
  ///
  /// In en, this message translates to:
  /// **'Mark as Done'**
  String get markDone;

  /// No description provided for @markFailed.
  ///
  /// In en, this message translates to:
  /// **'Mark as Failed'**
  String get markFailed;

  /// No description provided for @showupAutoFailed.
  ///
  /// In en, this message translates to:
  /// **'This showup was automatically marked as failed because it was opened after its scheduled time had passed.'**
  String get showupAutoFailed;

  /// No description provided for @showupNoteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get showupNoteLabel;

  /// No description provided for @showupNoteSave.
  ///
  /// In en, this message translates to:
  /// **'Save Note'**
  String get showupNoteSave;

  /// No description provided for @showupNoteError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save note. Please try again.'**
  String get showupNoteError;

  /// No description provided for @showupMarkError.
  ///
  /// In en, this message translates to:
  /// **'Failed to update showup status. Please try again.'**
  String get showupMarkError;

  /// No description provided for @showupHabitDeleted.
  ///
  /// In en, this message translates to:
  /// **'(habit deleted)'**
  String get showupHabitDeleted;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
