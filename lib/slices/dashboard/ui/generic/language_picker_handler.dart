import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_service.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/infrastructure/locale/contracts/locale_preference_service.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:habit_loop/slices/dashboard/analytics/language_analytics_events.dart';

// Shared between iOS and Android dashboard. Captures state before any await; guards on mounted.
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
  }) showPicker, // null return = "Use system language" or dismissed
}) async {
  final analytics = ref.read(analyticsServiceProvider);
  final localeService = ref.read(localePreferenceServiceProvider);

  // Capture before any await — async-gap reads would be stale after auth state changes.
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

  final changed = await applyLanguageSelection(
    selectedLocale: selectedLocale,
    currentOverride: currentOverride,
    systemLocaleCode: systemLocaleCode,
    analyticsService: analytics,
    localeService: localeService,
    updateLocaleOverride: (locale) => ref.read(localeOverrideProvider.notifier).state = locale,
  );

  // Pending notifications were scheduled with the old locale's text and the
  // OS payload can't be edited in place — re-schedule them (HAB-157).
  if (changed) await _rescheduleAllPendingReminders(ref);
}

Future<void> _rescheduleAllPendingReminders(WidgetRef ref) async {
  final pactRepository = ref.read(pactRepositoryProvider);
  final showupRepository = ref.read(showupRepositoryProvider);
  final schedulingService = ref.read(reminderSchedulingServiceProvider);

  final activePacts = await pactRepository.getActivePacts();
  for (final pact in activePacts) {
    if (pact.reminderOffset == null) continue;

    final showups = await showupRepository.getShowupsForPact(pact.id);
    final showupIds = showups.map((s) => s.id).toList();

    await schedulingService.cancelAllRemindersForPact(pact.id, showupIds: showupIds);
    unawaited(schedulingService.scheduleRemindersForShowups(pact: pact, showups: showups));
  }
}

// Persists + fires analytics. No-op when same language or both null (already on system).
// Returns whether a change was actually applied — callers use this to decide
// whether pending notifications need re-scheduling (HAB-157).
Future<bool> applyLanguageSelection({
  required Locale? selectedLocale,
  required Locale? currentOverride,
  required String systemLocaleCode,
  required AnalyticsService analyticsService,
  required LocalePreferenceService localeService,
  required void Function(Locale?) updateLocaleOverride,
}) async {
  if (selectedLocale == null) {
    if (currentOverride == null) return false; // already on system — no-op

    await localeService.clearLocale();
    updateLocaleOverride(null);
    return true;
  } else {
    if (selectedLocale.languageCode == currentOverride?.languageCode) return false; // same language — no-op

    final fromCode = currentOverride?.languageCode ?? systemLocaleCode;

    await localeService.saveLocale(selectedLocale);
    updateLocaleOverride(selectedLocale);

    unawaited(
      analyticsService.logEvent(
        LanguageChangedEvent(fromLanguage: fromCode, toLanguage: selectedLocale.languageCode),
      ),
    );
    return true;
  }
}
