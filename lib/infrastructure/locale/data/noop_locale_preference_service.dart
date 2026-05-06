import 'package:flutter/widgets.dart';
import 'package:habit_loop/infrastructure/locale/contracts/locale_preference_service.dart';

/// No-op [LocalePreferenceService] used as the default when no real
/// persistence backend is wired in.
///
/// [getSavedLocale] always returns `null`, meaning the app follows the system
/// locale. [saveLocale] and [clearLocale] are safe no-ops. This ensures tests
/// that do not care about locale persistence work without any setup.
final class NoopLocalePreferenceService implements LocalePreferenceService {
  @override
  Future<Locale?> getSavedLocale() async => null;

  @override
  Future<void> saveLocale(Locale locale) async {}

  @override
  Future<void> clearLocale() async {}
}
