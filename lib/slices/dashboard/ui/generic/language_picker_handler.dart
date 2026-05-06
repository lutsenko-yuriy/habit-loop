import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
import 'package:habit_loop/infrastructure/locale/contracts/locale_preference_service.dart';
import 'package:habit_loop/slices/dashboard/analytics/language_analytics_events.dart';

/// Shared orchestration logic for the language picker.
///
/// Called by both [DashboardPageIos] and [DashboardPageAndroid] after the
/// platform-specific picker UI has returned a user selection.
///
/// Parameters:
/// - [selectedLocale] — the locale the user chose, or `null` to revert to the
///   system locale.
/// - [currentOverride] — the current value of `localeOverrideProvider` (read
///   *before* the picker is shown so that `fromCode` is not captured after an
///   `await`).
/// - [systemLocaleCode] — the ISO 639-1 code of the resolved system locale,
///   used as `from_language` when the current override is `null`.
/// - [analyticsService] — used to fire [LanguageChangedEvent].
/// - [localeService] — used to persist or clear the selected locale.
/// - [updateLocaleOverride] — callback to write the new value back into the
///   Riverpod `localeOverrideProvider.notifier`.
///
/// Guard rules (no-op conditions):
/// - If [selectedLocale] is non-null and its language code equals
///   [currentOverride]'s language code, the selection is the same → skip.
/// - If [selectedLocale] is `null` (system) and [currentOverride] is already
///   `null`, nothing has changed → skip.
Future<void> applyLanguageSelection({
  required Locale? selectedLocale,
  required Locale? currentOverride,
  required String systemLocaleCode,
  required AnalyticsService analyticsService,
  required LocalePreferenceService localeService,
  required void Function(Locale?) updateLocaleOverride,
}) async {
  if (selectedLocale == null) {
    // User chose "Use system language".
    if (currentOverride == null) return; // already on system — no-op

    await localeService.clearLocale();
    updateLocaleOverride(null);
  } else {
    // User chose a specific language.
    if (selectedLocale.languageCode == currentOverride?.languageCode) return; // same language — no-op

    final fromCode = currentOverride?.languageCode ?? systemLocaleCode;

    await localeService.saveLocale(selectedLocale);
    updateLocaleOverride(selectedLocale);

    unawaited(
      analyticsService.logEvent(
        LanguageChangedEvent(fromLanguage: fromCode, toLanguage: selectedLocale.languageCode),
      ),
    );
  }
}
