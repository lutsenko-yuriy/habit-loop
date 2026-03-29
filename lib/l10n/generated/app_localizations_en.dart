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
}
