import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/language_picker_handler.dart';

import '../../../infrastructure/analytics/fake_analytics_service.dart';
import '../../../infrastructure/locale/fake_locale_preference_service.dart';

void main() {
  group('applyLanguageSelection', () {
    late FakeAnalyticsService analytics;
    late FakeLocalePreferenceService localeService;

    setUp(() {
      analytics = FakeAnalyticsService();
      localeService = FakeLocalePreferenceService();
    });

    test('saves locale and fires analytics when a different language is selected', () async {
      Locale? capturedLocale;

      await applyLanguageSelection(
        selectedLocale: const Locale('fr'),
        currentOverride: const Locale('en'),
        systemLocaleCode: 'en',
        analyticsService: analytics,
        localeService: localeService,
        updateLocaleOverride: (locale) => capturedLocale = locale,
      );

      expect(localeService.savedLocale, const Locale('fr'));
      expect(capturedLocale, const Locale('fr'));
      expect(analytics.loggedEvents.any((e) => e.name == 'language_changed'), isTrue);
      final event = analytics.loggedEvents.firstWhere((e) => e.name == 'language_changed');
      expect(event.toParameters()['from_language'], 'en');
      expect(event.toParameters()['to_language'], 'fr');
    });

    test('no-ops when re-selecting the current language override', () async {
      bool updateCalled = false;

      await applyLanguageSelection(
        selectedLocale: const Locale('fr'),
        currentOverride: const Locale('fr'),
        systemLocaleCode: 'en',
        analyticsService: analytics,
        localeService: localeService,
        updateLocaleOverride: (_) => updateCalled = true,
      );

      // Nothing should have happened
      expect(localeService.savedLocale, isNull);
      expect(updateCalled, isFalse);
      expect(analytics.loggedEvents.any((e) => e.name == 'language_changed'), isFalse);
    });

    test('clears locale when system language is selected and override was set', () async {
      Locale? providerValue = const Locale('de'); // simulate initial state

      await applyLanguageSelection(
        selectedLocale: null, // null = system
        currentOverride: const Locale('de'),
        systemLocaleCode: 'en',
        analyticsService: analytics,
        localeService: localeService,
        updateLocaleOverride: (locale) => providerValue = locale,
      );

      expect(localeService.clearLocaleCallCount, 1);
      expect(providerValue, isNull);
    });

    test('no-ops when system language is selected and override is already null', () async {
      bool updateCalled = false;

      await applyLanguageSelection(
        selectedLocale: null, // null = system
        currentOverride: null, // already on system
        systemLocaleCode: 'en',
        analyticsService: analytics,
        localeService: localeService,
        updateLocaleOverride: (_) => updateCalled = true,
      );

      expect(localeService.clearLocaleCallCount, 0);
      expect(updateCalled, isFalse);
    });

    test('does not fire language_changed when clearing to system language', () async {
      await applyLanguageSelection(
        selectedLocale: null,
        currentOverride: const Locale('de'),
        systemLocaleCode: 'en',
        analyticsService: analytics,
        localeService: localeService,
        updateLocaleOverride: (_) {},
      );

      expect(analytics.loggedEvents.any((e) => e.name == 'language_changed'), isFalse);
    });
  });
}
