import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Formats [date] as a locale-aware short date (e.g. `3/30/2026` in en-US,
/// `30/03/2026` in fr, `30.03.2026` in de) using the ambient [BuildContext]
/// locale.
///
/// This is a thin wrapper around `DateFormat.yMd` that resolves the locale
/// from [context] automatically, providing a single definition of the
/// `yMd`-format pattern so all call sites remain consistent. Changing the
/// format (e.g. to `yMMMd` for more readable output) requires editing only
/// this function.
String formatLocaleDate(BuildContext context, DateTime date) =>
    DateFormat.yMd(Localizations.localeOf(context).toString()).format(date);
