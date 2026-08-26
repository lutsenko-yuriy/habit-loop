import 'package:flutter/widgets.dart' show Locale;
import 'package:habit_loop/infrastructure/locale/contracts/locale_preference_service.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

/// Resolves the effective [AppLocalizations] for reminder/reconciliation
/// text: the saved in-app locale override (HAB-157), falling back to the
/// device/OS locale, falling back to English for an unsupported locale
/// (`lookupAppLocalizations` throws for those).
///
/// Extracted so [ReminderSchedulingService] and
/// [NotificationReconciliationService] share one resolution path instead of
/// each carrying its own copy — the exact divergence risk
/// [ReminderPlanContext] was extracted to eliminate on the remote-config
/// side (PR #411 review).
abstract final class ReminderLocaleResolver {
  static Future<AppLocalizations> resolve({
    required LocalePreferenceService localePreference,
    required Locale systemLocale,
  }) async {
    final savedLocale = await localePreference.getSavedLocale() ?? systemLocale;
    try {
      return lookupAppLocalizations(savedLocale);
    } catch (_) {
      return lookupAppLocalizations(const Locale('en'));
    }
  }
}
