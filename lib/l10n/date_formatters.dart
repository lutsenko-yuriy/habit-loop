import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

// Uses the platform's regional locale for date ordering (dd/MM vs MM/dd) rather than
// the app's display locale, which often lacks a country code (e.g. "en" vs "en_GB").
// Falls back to Platform.localeName (which includes the OS Region setting) when the
// app language locale carries no country code.
String formatLocaleDate(DateTime date) => DateFormat.yMd(_effectiveLocale()).format(date);

String _effectiveLocale() {
  final primary = WidgetsBinding.instance.platformDispatcher.locale;
  if (primary.countryCode?.isNotEmpty == true) return primary.toString();
  // Language-only locale (e.g. "en"): use the OS system locale which includes the
  // Region setting (e.g. "en_DE") so date ordering matches the user's region.
  return Platform.localeName.split('.').first;
}
