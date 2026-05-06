import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/locale/data/shared_preferences_locale_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPreferencesLocaleService', () {
    setUp(() {
      // Set up an empty mock SharedPreferences before each test.
      SharedPreferences.setMockInitialValues({});
    });

    test('getSavedLocale returns null when no locale is stored', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesLocaleService(prefs);

      final result = await service.getSavedLocale();
      expect(result, isNull);
    });

    test('save and read round-trip for English', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesLocaleService(prefs);

      await service.saveLocale(const Locale('en'));
      final result = await service.getSavedLocale();
      expect(result, equals(const Locale('en')));
    });

    test('save and read round-trip for French', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesLocaleService(prefs);

      await service.saveLocale(const Locale('fr'));
      final result = await service.getSavedLocale();
      expect(result, equals(const Locale('fr')));
    });

    test('save and read round-trip for German', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesLocaleService(prefs);

      await service.saveLocale(const Locale('de'));
      final result = await service.getSavedLocale();
      expect(result, equals(const Locale('de')));
    });

    test('save and read round-trip for Russian', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesLocaleService(prefs);

      await service.saveLocale(const Locale('ru'));
      final result = await service.getSavedLocale();
      expect(result, equals(const Locale('ru')));
    });

    test('clearLocale removes stored value and getSavedLocale returns null', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesLocaleService(prefs);

      await service.saveLocale(const Locale('fr'));
      await service.clearLocale();
      final result = await service.getSavedLocale();
      expect(result, isNull);
    });

    test('invalid stored value returns null gracefully', () async {
      // Pre-populate SharedPreferences with an unsupported locale code.
      SharedPreferences.setMockInitialValues({
        SharedPreferencesLocaleService.localeKey: 'xx',
      });
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesLocaleService(prefs);

      final result = await service.getSavedLocale();
      expect(result, isNull);
    });

    test('overwriting locale with a new value is reflected on next read', () async {
      final prefs = await SharedPreferences.getInstance();
      final service = SharedPreferencesLocaleService(prefs);

      await service.saveLocale(const Locale('en'));
      await service.saveLocale(const Locale('de'));
      final result = await service.getSavedLocale();
      expect(result, equals(const Locale('de')));
    });
  });
}
