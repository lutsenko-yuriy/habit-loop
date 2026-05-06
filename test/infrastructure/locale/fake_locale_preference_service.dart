import 'package:flutter/widgets.dart';
import 'package:habit_loop/infrastructure/locale/contracts/locale_preference_service.dart';

/// In-memory fake [LocalePreferenceService] for tests.
///
/// Backed by a simple nullable field. Does not touch [SharedPreferences].
/// Use this in test [ProviderContainer] overrides wherever locale persistence
/// behaviour is not the subject under test.
///
/// Exposes [savedLocale] and [clearedLocale] for assertion in widget tests.
final class FakeLocalePreferenceService implements LocalePreferenceService {
  Locale? _stored;

  /// The locale most recently passed to [saveLocale], or `null` if never called.
  Locale? get savedLocale => _stored;

  /// Whether [clearLocale] has been called at least once.
  bool get clearedLocale => _cleared;
  bool _cleared = false;

  @override
  Future<Locale?> getSavedLocale() async => _stored;

  @override
  Future<void> saveLocale(Locale locale) async {
    _stored = locale;
  }

  @override
  Future<void> clearLocale() async {
    _stored = null;
    _cleared = true;
  }
}
