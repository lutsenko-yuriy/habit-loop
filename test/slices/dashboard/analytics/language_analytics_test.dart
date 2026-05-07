import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_event.dart';
import 'package:habit_loop/infrastructure/analytics/contracts/analytics_screen.dart';
import 'package:habit_loop/slices/dashboard/analytics/language_analytics_events.dart';

void main() {
  group('LanguagePickerAnalyticsScreen', () {
    test('implements AnalyticsScreen', () {
      expect(const LanguagePickerAnalyticsScreen(), isA<AnalyticsScreen>());
    });

    test('screen_name is language_picker', () {
      expect(const LanguagePickerAnalyticsScreen().name, 'language_picker');
    });
  });

  group('LanguageChangeRequestedEvent', () {
    test('implements AnalyticsEvent', () {
      expect(LanguageChangeRequestedEvent(), isA<AnalyticsEvent>());
    });

    test('event name is language_change_requested', () {
      expect(LanguageChangeRequestedEvent().name, 'language_change_requested');
    });

    test('parameters contain source=dashboard', () {
      final params = LanguageChangeRequestedEvent().toParameters();
      expect(params['source'], 'dashboard');
    });

    test('parameters contain exactly one key', () {
      expect(LanguageChangeRequestedEvent().toParameters().length, 1);
    });
  });

  group('LanguageChangedEvent', () {
    test('implements AnalyticsEvent', () {
      expect(
        LanguageChangedEvent(fromLanguage: 'en', toLanguage: 'fr'),
        isA<AnalyticsEvent>(),
      );
    });

    test('event name is language_changed', () {
      expect(LanguageChangedEvent(fromLanguage: 'en', toLanguage: 'fr').name, 'language_changed');
    });

    test('parameters contain from_language', () {
      final event = LanguageChangedEvent(fromLanguage: 'en', toLanguage: 'de');
      expect(event.toParameters()['from_language'], 'en');
    });

    test('parameters contain to_language', () {
      final event = LanguageChangedEvent(fromLanguage: 'en', toLanguage: 'de');
      expect(event.toParameters()['to_language'], 'de');
    });

    test('parameters contain source=dashboard', () {
      final event = LanguageChangedEvent(fromLanguage: 'ru', toLanguage: 'en');
      expect(event.toParameters()['source'], 'dashboard');
    });

    test('parameters contain exactly three keys', () {
      expect(LanguageChangedEvent(fromLanguage: 'en', toLanguage: 'fr').toParameters().length, 3);
    });

    test('supports all four language codes as fromLanguage', () {
      for (final code in ['en', 'fr', 'de', 'ru']) {
        final event = LanguageChangedEvent(fromLanguage: code, toLanguage: 'en');
        expect(event.toParameters()['from_language'], code);
      }
    });

    test('supports all four language codes as toLanguage', () {
      for (final code in ['en', 'fr', 'de', 'ru']) {
        final event = LanguageChangedEvent(fromLanguage: 'en', toLanguage: code);
        expect(event.toParameters()['to_language'], code);
      }
    });
  });
}
