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
}
