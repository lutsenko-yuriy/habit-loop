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
}
