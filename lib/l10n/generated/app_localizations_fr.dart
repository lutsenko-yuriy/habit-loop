// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Habit Loop';

  @override
  String get dashboardTitle => 'Tableau de bord';

  @override
  String get todayShowups => 'Rendez-vous du jour';

  @override
  String get noPactsYet => 'Aucun pacte';

  @override
  String get noPactsDescription =>
      'Créez votre premier pacte pour commencer à construire une habitude.';

  @override
  String get createPact => 'Créer un pacte';

  @override
  String get noShowupsForDay => 'Aucun rendez-vous ce jour';

  @override
  String get showupDone => 'Fait';

  @override
  String get showupFailed => 'Échoué';

  @override
  String get showupPending => 'En attente';

  @override
  String get pactCreationTitle => 'Nouveau pacte';

  @override
  String get habitNameLabel => 'Nom de l\'habitude';

  @override
  String get habitNameHint => 'ex. Méditer, Courir, Lire…';

  @override
  String get pactDurationStep => 'Durée du pacte';

  @override
  String get startDateLabel => 'Date de début';

  @override
  String get endDateLabel => 'Date de fin';

  @override
  String get showupDurationStep => 'Durée du rendez-vous';

  @override
  String get showupDurationLabel =>
      'Combien de temps dure chaque rendez-vous ?';

  @override
  String showupDurationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get scheduleStep => 'Horaire';

  @override
  String get scheduleTypeLabel => 'Quand voulez-vous vous présenter ?';

  @override
  String get scheduleDaily => 'Tous les jours';

  @override
  String get scheduleWeekday => 'Jours spécifiques';

  @override
  String get scheduleMonthlyByWeekday => 'Mensuel par jour de semaine';

  @override
  String get scheduleMonthlyByDate => 'Mensuel par date';

  @override
  String get timeOfDayLabel => 'Heure';

  @override
  String get addEntry => 'Ajouter un autre';

  @override
  String get removeEntry => 'Supprimer';

  @override
  String get weekdayMon => 'Lun';

  @override
  String get weekdayTue => 'Mar';

  @override
  String get weekdayWed => 'Mer';

  @override
  String get weekdayThu => 'Jeu';

  @override
  String get weekdayFri => 'Ven';

  @override
  String get weekdaySat => 'Sam';

  @override
  String get weekdaySun => 'Dim';

  @override
  String get occurrenceFirst => '1er';

  @override
  String get occurrenceSecond => '2e';

  @override
  String get occurrenceThird => '3e';

  @override
  String get occurrenceFourth => '4e';

  @override
  String get dayOfMonthLabel => 'Jour du mois';

  @override
  String get reminderStep => 'Rappel';

  @override
  String get reminderLabel => 'Me rappeler avant le rendez-vous';

  @override
  String get reminderNone => 'Pas de rappel';

  @override
  String get reminderAtStart => 'Au début';

  @override
  String reminderMinutesBefore(int minutes) {
    return '$minutes min avant';
  }

  @override
  String get summaryHabit => 'Habitude';

  @override
  String get summaryDuration => 'Durée du pacte';

  @override
  String get summaryShowupDuration => 'Durée du rendez-vous';

  @override
  String get summarySchedule => 'Horaire';

  @override
  String get summaryReminder => 'Rappel';

  @override
  String get commitmentStep => 'Engagement';

  @override
  String get commitmentWarning =>
      'Manquer un rendez-vous compte comme un échec. Il n\'y a aucune exception et aucune pause possible. En créant ce pacte, vous vous engagez à vous présenter à chaque fois.';

  @override
  String get commitmentAccept => 'Je comprends et m\'engage';

  @override
  String get createPactConfirm => 'Créer le pacte';

  @override
  String get next => 'Suivant';

  @override
  String get back => 'Retour';

  @override
  String get cancel => 'Annuler';

  @override
  String get tooManyPactsTitle => 'Trop de pactes actifs';

  @override
  String tooManyPactsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Vous avez déjà $count pactes actifs. Voulez-vous vraiment en créer davantage ?',
      one:
          'Vous avez déjà 1 pacte actif. Voulez-vous vraiment en créer un autre ?',
    );
    return '$_temp0';
  }

  @override
  String get tooManyPactsConfirm => 'Oui, créer un autre';

  @override
  String get pactDetailTitle => 'Détails du pacte';

  @override
  String get statsDone => 'Réalisés';

  @override
  String get statsFailed => 'Échoués';

  @override
  String get statsRemaining => 'Restants';

  @override
  String get statsCancelled => 'Arrêtés';

  @override
  String get statsStreak => 'Série';

  @override
  String statsShowups(int count) {
    return '$count rendez-vous';
  }

  @override
  String get pactStartDate => 'Début';

  @override
  String get pactEndDate => 'Fin';

  @override
  String get pactEndedDate => 'Terminé';

  @override
  String daysRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours restants',
      one: '1 jour restant',
    );
    return '$_temp0';
  }

  @override
  String get pactStatusActive => 'Actif';

  @override
  String get pactStatusStopped => 'Arrêté';

  @override
  String get pactStatusCompleted => 'Terminé';

  @override
  String get stopPact => 'Arrêter le pacte';

  @override
  String get stopPactTitle => 'Arrêter ce pacte ?';

  @override
  String get stopPactBody =>
      'Cette action est irréversible. Vous pourrez toujours consulter l\'historique du pacte.';

  @override
  String get stopPactReasonHint => 'Raison (facultatif)';

  @override
  String get stopPactConfirm => 'Arrêter';

  @override
  String pactsActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pactes actifs',
      one: '1 pacte actif',
      zero: 'Aucun pacte actif',
    );
    return '$_temp0';
  }

  @override
  String pactsDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pactes terminés',
      one: '1 pacte terminé',
      zero: 'Aucun pacte terminé',
    );
    return '$_temp0';
  }

  @override
  String pactsCancelled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pactes arrêtés',
      one: '1 pacte arrêté',
      zero: 'Aucun pacte arrêté',
    );
    return '$_temp0';
  }

  @override
  String get addPact => 'Ajouter un pacte';

  @override
  String get pactListTitle => 'Pactes';

  @override
  String get filterActive => 'Actifs';

  @override
  String get filterDone => 'Terminés';

  @override
  String get filterCancelled => 'Arrêtés';

  @override
  String pactNextShowup(String date) {
    return 'Prochain : $date';
  }

  @override
  String pactEndedOn(String date) {
    return 'Terminé le $date';
  }

  @override
  String pactCancelledOn(String date) {
    return 'Arrêté le $date';
  }
}
