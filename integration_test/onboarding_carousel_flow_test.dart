// On-device entry point for the onboarding carousel flow tests.
//
// Run with: flutter test integration_test/onboarding_carousel_flow_test.dart -d <device>
// Run on host: flutter test integration_test/onboarding_carousel_flow_test.dart
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Onboarding carousel flow', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
        'carousel_shown_on_first_launch_with_no_pacts: onboarding carousel is shown on first launch when there are no pacts',
        (tester) async {
      h = await AppHarness.create(tester, initiallyAnonymous: true, remoteConfigOverrides: noAutoAdvance);
      final strings = l10n(tester);

      expect(find.text(strings.onboardingSlide0Title), findsOneWidget);
      expect(find.text(strings.createPact), findsOneWidget);
      // Regular dashboard chrome is not visible.
      expect(h.dashboard.languagePickerButton, findsNothing);
    });

    testWidgets('swipe_left_advances_to_slide_1: swiping left advances the carousel to slide 1', (tester) async {
      h = await AppHarness.create(tester, initiallyAnonymous: true, remoteConfigOverrides: noAutoAdvance);
      final strings = l10n(tester);

      await h.onboarding.swipeToSlide1();

      expect(find.text(strings.onboardingSlide1Title), findsOneWidget);
      expect(find.text(strings.onboardingSlide0Title), findsNothing);
    });

    testWidgets('swipe_right_returns_to_slide_0: swiping right after advancing returns the carousel to slide 0',
        (tester) async {
      h = await AppHarness.create(tester, initiallyAnonymous: true, remoteConfigOverrides: noAutoAdvance);
      final strings = l10n(tester);

      await h.onboarding.swipeToSlide1();
      expect(find.text(strings.onboardingSlide1Title), findsOneWidget);

      // Swipe back to slide 0.
      await h.onboarding.swipeBackToSlide0();

      expect(find.text(strings.onboardingSlide0Title), findsOneWidget);
    });

    testWidgets(
        'tap_language_opens_picker_and_persists_locale: tapping "Language" opens the language picker and saving a locale persists it',
        (tester) async {
      h = await AppHarness.create(tester, initiallyAnonymous: true, remoteConfigOverrides: noAutoAdvance);
      final strings = l10n(tester);

      // The carousel has a single "Language" button (dialog not yet open).
      await h.onboarding.openLanguagePicker();

      // Platform-specific picker dialog type.
      if (Platform.isAndroid) {
        expect(find.byType(SimpleDialog), findsOneWidget);
      } else {
        expect(find.byType(CupertinoActionSheet), findsOneWidget);
      }
      expect(find.text(strings.languageFrench), findsOneWidget);

      await h.onboarding.selectLanguage(strings.languageFrench);

      // Locale was persisted via the locale preference service.
      expect(h.localeService.savedLocale?.languageCode, equals('fr'));
    });
  });
}
