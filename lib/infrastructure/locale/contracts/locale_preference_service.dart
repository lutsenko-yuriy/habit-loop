import 'package:flutter/widgets.dart';

/// Abstract interface for persisting and retrieving the user's locale preference.
///
/// Inject via Riverpod (`localePreferenceServiceProvider`) so call sites are
/// decoupled from the concrete storage implementation. Tests can override with
/// [FakeLocalePreferenceService].
///
/// **No-throw contract:** all implementations must swallow exceptions
/// internally. Call sites may call any method without wrapping in try/catch.
abstract interface class LocalePreferenceService {
  /// Returns the saved [Locale], or `null` if none has been saved or the
  /// stored value is not a supported locale.
  ///
  /// Never throws — implementations swallow failures silently.
  Future<Locale?> getSavedLocale();

  /// Persists [locale] as the user's preferred locale.
  ///
  /// Subsequent calls to [getSavedLocale] will return [locale].
  /// Never throws — implementations swallow failures silently.
  Future<void> saveLocale(Locale locale);

  /// Clears the saved locale preference.
  ///
  /// After this call, [getSavedLocale] returns `null` and the app falls back
  /// to the system locale.
  /// Never throws — implementations swallow failures silently.
  Future<void> clearLocale();
}
