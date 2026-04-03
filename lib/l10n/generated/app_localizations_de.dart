// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Habit Loop';

  @override
  String get dashboardTitle => 'Übersicht';

  @override
  String get todayShowups => 'Heutige Showups';

  @override
  String get noPactsYet => 'Noch keine Pakte';

  @override
  String get noPactsDescription =>
      'Erstelle deinen ersten Pakt, um eine Gewohnheit aufzubauen.';

  @override
  String get createPact => 'Pakt erstellen';

  @override
  String get noShowupsForDay => 'Keine Showups an diesem Tag';

  @override
  String get showupDone => 'Erledigt';

  @override
  String get showupFailed => 'Verpasst';

  @override
  String get showupPending => 'Ausstehend';

  @override
  String get pactCreationTitle => 'Neuer Pakt';

  @override
  String get habitNameLabel => 'Name der Gewohnheit';

  @override
  String get habitNameHint => 'z.B. Meditieren, Joggen, Lesen…';

  @override
  String get pactDurationStep => 'Paktdauer';

  @override
  String get startDateLabel => 'Startdatum';

  @override
  String get endDateLabel => 'Enddatum';

  @override
  String get showupDurationStep => 'Showup-Dauer';

  @override
  String get showupDurationLabel => 'Wie lang ist jedes Showup?';

  @override
  String showupDurationMinutes(int minutes) {
    return '$minutes Min.';
  }

  @override
  String get scheduleStep => 'Zeitplan';

  @override
  String get scheduleTypeLabel => 'Wann möchtest du erscheinen?';

  @override
  String get scheduleDaily => 'Jeden Tag';

  @override
  String get scheduleWeekday => 'Bestimmte Wochentage';

  @override
  String get scheduleMonthlyByWeekday => 'Monatlich nach Wochentag';

  @override
  String get scheduleMonthlyByDate => 'Monatlich nach Datum';

  @override
  String get timeOfDayLabel => 'Uhrzeit';

  @override
  String get addEntry => 'Weiteren hinzufügen';

  @override
  String get removeEntry => 'Entfernen';

  @override
  String get weekdayMon => 'Mo';

  @override
  String get weekdayTue => 'Di';

  @override
  String get weekdayWed => 'Mi';

  @override
  String get weekdayThu => 'Do';

  @override
  String get weekdayFri => 'Fr';

  @override
  String get weekdaySat => 'Sa';

  @override
  String get weekdaySun => 'So';

  @override
  String get occurrenceFirst => '1.';

  @override
  String get occurrenceSecond => '2.';

  @override
  String get occurrenceThird => '3.';

  @override
  String get occurrenceFourth => '4.';

  @override
  String get dayOfMonthLabel => 'Tag des Monats';

  @override
  String get reminderStep => 'Erinnerung';

  @override
  String get reminderLabel => 'Vor dem Showup erinnern';

  @override
  String get reminderNone => 'Keine Erinnerung';

  @override
  String get reminderAtStart => 'Beim Start';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes Min. vorher';
  }

  @override
  String get summaryHabit => 'Gewohnheit';

  @override
  String get summaryDuration => 'Paktdauer';

  @override
  String get summaryShowupDuration => 'Showup-Dauer';

  @override
  String get summarySchedule => 'Zeitplan';

  @override
  String get summaryReminder => 'Erinnerung';

  @override
  String get commitmentStep => 'Verpflichtung';

  @override
  String get commitmentWarning =>
      'Ein verpasstes Showup zählt als Misserfolg. Es gibt keine Ausnahmen und keine Pausen. Mit der Erstellung dieses Pakts verpflichtest du dich, jedes Mal zu erscheinen.';

  @override
  String get commitmentAccept => 'Ich verstehe und verpflichte mich';

  @override
  String get createPactConfirm => 'Pakt erstellen';

  @override
  String get next => 'Weiter';

  @override
  String get back => 'Zurück';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get tooManyPactsTitle => 'Zu viele aktive Pakte';

  @override
  String tooManyPactsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Du hast bereits $count aktive Pakte. Möchtest du wirklich mehr erstellen?',
      one:
          'Du hast bereits 1 aktiven Pakt. Möchtest du wirklich einen weiteren erstellen?',
    );
    return '$_temp0';
  }

  @override
  String get tooManyPactsConfirm => 'Ja, weiteren erstellen';

  @override
  String get pactDetailTitle => 'Pakt-Details';

  @override
  String get statsDone => 'Erledigt';

  @override
  String get statsFailed => 'Verpasst';

  @override
  String get statsRemaining => 'Ausstehend';

  @override
  String get statsStreak => 'Serie';

  @override
  String statsShowups(int count) {
    return '$count Showups';
  }

  @override
  String get pactStartDate => 'Beginn';

  @override
  String get pactEndDate => 'Ende';

  @override
  String daysRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Tage verbleibend',
      one: '1 Tag verbleibend',
    );
    return '$_temp0';
  }

  @override
  String get pactStatusActive => 'Aktiv';

  @override
  String get pactStatusStopped => 'Gestoppt';

  @override
  String get pactStatusCompleted => 'Abgeschlossen';

  @override
  String get stopPact => 'Pakt beenden';

  @override
  String get stopPactTitle => 'Diesen Pakt beenden?';

  @override
  String get stopPactBody =>
      'Diese Aktion kann nicht rückgängig gemacht werden. Du kannst den Pakt-Verlauf danach noch einsehen.';

  @override
  String get stopPactReasonHint => 'Grund (optional)';

  @override
  String get stopPactConfirm => 'Beenden';
}
