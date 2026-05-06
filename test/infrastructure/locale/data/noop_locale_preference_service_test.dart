import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/locale/data/noop_locale_preference_service.dart';

void main() {
  group('NoopLocalePreferenceService', () {
    late NoopLocalePreferenceService service;

    setUp(() {
      service = NoopLocalePreferenceService();
    });

    test('getSavedLocale returns null', () async {
      final result = await service.getSavedLocale();
      expect(result, isNull);
    });

    test('saveLocale is a no-op and does not throw', () async {
      await expectLater(service.saveLocale(const Locale('en')), completes);
    });

    test('clearLocale is a no-op and does not throw', () async {
      await expectLater(service.clearLocale(), completes);
    });

    test('getSavedLocale still returns null after saveLocale is called', () async {
      await service.saveLocale(const Locale('fr'));
      final result = await service.getSavedLocale();
      expect(result, isNull);
    });
  });
}
