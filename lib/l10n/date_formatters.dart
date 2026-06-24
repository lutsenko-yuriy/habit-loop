import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

// Uses the platform's regional locale for date ordering (dd/MM vs MM/dd) rather than
// the app's display locale, which often lacks a country code (e.g. "en" vs "en_GB").
String formatLocaleDate(DateTime date) =>
    DateFormat.yMd(WidgetsBinding.instance.platformDispatcher.locale.toString()).format(date);
