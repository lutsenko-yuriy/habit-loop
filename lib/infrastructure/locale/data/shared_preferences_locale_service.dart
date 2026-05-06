import 'package:flutter/widgets.dart';
import 'package:habit_loop/infrastructure/locale/contracts/locale_preference_service.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Production [LocalePreferenceService] backed by [SharedPreferences].
///
/// Stores the user's locale preference as a language code string (e.g. `"fr"`)
/// under [localeKey]. On read, the stored value is validated against
/// [AppLocalizations.supportedLocales]; an unrecognised code returns `null`
/// rather than throwing, honouring the no-throw contract.
///
/// **No-throw contract:** all methods swallow exceptions internally so that a
/// SharedPreferences failure can never crash the app.
final class SharedPreferencesLocaleService implements LocalePreferenceService {
  /// The [SharedPreferences] instance injected at construction time.
  ///
  /// Accepting a pre-constructed instance (rather than calling
  /// `SharedPreferences.getInstance()` inside each method) makes the class
  /// testable with [SharedPreferences.setMockInitialValues].
  final SharedPreferences _prefs;

  /// The key used to store the locale language code in [SharedPreferences].
  static const String localeKey = 'habit_loop_locale';

  /// Creates a [SharedPreferencesLocaleService] backed by [prefs].
  const SharedPreferencesLocaleService(this._prefs);

  @override
  Future<Locale?> getSavedLocale() async {
    try {
      final code = _prefs.getString(localeKey);
      if (code == null) return null;
      // Validate against supported locales — reject codes from other apps or
      // older app versions that may have stored unsupported values.
      const supported = AppLocalizations.supportedLocales;
      final match = supported.where((l) => l.languageCode == code).firstOrNull;
      return match;
    } catch (_) {
      return null;
    }
  }

  /// Persists [locale] so it can be restored on the next app launch.
  ///
  /// **Only [Locale.languageCode] is stored** — the country/script subtag is
  /// intentionally discarded. This is correct for the current supported locale
  /// set (`de`, `en`, `fr`, `ru`), where each language has exactly one variant.
  /// If regional variants such as `zh-TW` / `zh-CN` are ever added, this method
  /// would need to be updated to persist the full BCP 47 tag instead.
  @override
  Future<void> saveLocale(Locale locale) async {
    try {
      await _prefs.setString(localeKey, locale.languageCode);
    } catch (_) {}
  }

  @override
  Future<void> clearLocale() async {
    try {
      await _prefs.remove(localeKey);
    } catch (_) {}
  }
}
