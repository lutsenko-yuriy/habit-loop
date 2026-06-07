import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

// Locale-aware yMd short date. Single definition so all call sites stay consistent.
String formatLocaleDate(BuildContext context, DateTime date) =>
    DateFormat.yMd(Localizations.localeOf(context).toString()).format(date);
