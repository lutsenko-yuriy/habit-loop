import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/locale/contracts/locale_preference_service.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/analytics/language_analytics_events.dart';

// ---------------------------------------------------------------------------
// openLanguagePicker — shared orchestration for both platforms
// ---------------------------------------------------------------------------

/// Opens the language picker using the provided platform-specific [showPicker]
/// callback, then applies the result via [applyLanguageSelection].
///
/// Shared between [DashboardPageIos] and [DashboardPageAndroid]. Each platform
/// supplies a [showPicker] callback that renders its native UI (a
/// [CupertinoActionSheet] for iOS, a [SimpleDialog] for Android) and returns
/// the selected [Locale], or `null` to indicate either "use system language"
/// or "dismissed".
///
/// The options list passed to [showPicker] uses named-record fields:
/// `({String label, Locale? locale})` where `locale == null` means the system
/// option.
///
/// Steps performed inside [openLanguagePicker]:
/// 1. Snapshot [currentOverride] and [systemLocaleCode] **before** any `await`.
/// 2. Fire [LanguageChangeRequestedEvent] and [LanguagePickerAnalyticsScreen].
/// 3. Guard on [BuildContext.mounted].
/// 4. Build the options list from [AppLocalizations].
/// 5. Delegate to [showPicker] to show the native UI.
/// 6. Guard on [BuildContext.mounted].
/// 7. Delegate to [applyLanguageSelection] with the result.
Future<void> openLanguagePicker({
  required BuildContext context,
  required WidgetRef ref,

  /// Platform-specific picker. Receives the options list and the current
  /// override, shows its native UI, and returns the selected [Locale] (or
  /// `null` for system / dismissed).
  required Future<Locale?> Function({
    required BuildContext context,
    required List<({String label, Locale? locale})> options,
    required Locale? currentOverride,
  }) showPicker,
}) async {
  final analytics = ref.read(analyticsServiceProvider);
  final localeService = ref.read(localePreferenceServiceProvider);

  // Capture before any await to avoid async-gap stale reads.
  final currentOverride = ref.read(localeOverrideProvider);
  final systemLocaleCode = Localizations.localeOf(context).languageCode;

  unawaited(analytics.logEvent(LanguageChangeRequestedEvent()));
  unawaited(analytics.logScreenView(const LanguagePickerAnalyticsScreen()));

  if (!context.mounted) return;

  final l10n = AppLocalizations.of(context)!;
  final options = <({String label, Locale? locale})>[
    (label: l10n.languageEnglish, locale: const Locale('en')),
    (label: l10n.languageFrench, locale: const Locale('fr')),
    (label: l10n.languageGerman, locale: const Locale('de')),
    (label: l10n.languageRussian, locale: const Locale('ru')),
    (label: l10n.languageSystem, locale: null),
  ];

  final selectedLocale = await showPicker(
    context: context,
    options: options,
    currentOverride: currentOverride,
  );

  if (!context.mounted) return;

  await applyLanguageSelection(
    selectedLocale: selectedLocale,
    currentOverride: currentOverride,
    systemLocaleCode: systemLocaleCode,
    analyticsService: analytics,
    localeService: localeService,
    updateLocaleOverride: (locale) => ref.read(localeOverrideProvider.notifier).state = locale,
  );
}

// ---------------------------------------------------------------------------
// applyLanguageSelection — shared persistence + analytics logic
// ---------------------------------------------------------------------------

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
