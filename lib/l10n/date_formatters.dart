import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

// Uses the platform's regional locale for date ordering (dd/MM vs MM/dd) rather than
// the app's display locale, which often lacks a country code (e.g. "en" vs "en_GB").
// Falls back to Platform.localeName (which includes the OS Region setting) when the
// app language locale carries no country code.
String formatLocaleDate(DateTime date) => DateFormat.yMd(_effectiveLocale()).format(date);

/// Formats a full, screen-reader-friendly date (weekday + month + day + year) using
/// the app's display locale, e.g. "Tuesday, July 21, 2026" — used for Semantics labels
/// where a compact numeric date (`formatLocaleDate`) would be ambiguous when spoken aloud.
String formatAccessibleDate(BuildContext context, DateTime date) =>
    DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toString()).format(date);

/// Formats the full, localized weekday name (e.g. "Monday") for a `DateTime.weekday`
/// value (1=Monday..7=Sunday), for Semantics labels where a short display abbreviation
/// (e.g. "Mon") would be ambiguous when spoken aloud. Uses Jan 1-7 2024 (a Monday) as an
/// arbitrary reference week purely to resolve the localized weekday name via `intl`.
String formatWeekdayName(BuildContext context, int weekday) =>
    DateFormat.EEEE(Localizations.localeOf(context).toString()).format(DateTime(2024, 1, weekday));

String _effectiveLocale() {
  final primary = WidgetsBinding.instance.platformDispatcher.locale;
  if (primary.countryCode?.isNotEmpty == true) return primary.toString();
  // Language-only locale (e.g. "en"): use the OS system locale which includes the
  // Region setting (e.g. "en_DE") so date ordering matches the user's region.
  return Platform.localeName.split('.').first;
}
