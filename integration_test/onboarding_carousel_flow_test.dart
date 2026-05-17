// On-device entry point for the onboarding carousel flow tests.
//
// Run with: flutter test integration_test/onboarding_carousel_flow_test.dart -d <device>
// Run on host: flutter test integration_test/onboarding_carousel_flow_test.dart
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:integration_test/integration_test.dart';

import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import 'harness.dart';

/// Override that disables auto-advance (RC value < _minAutoAdvanceSeconds=5).
final _noAutoAdvance = remoteConfigServiceProvider.overrideWithValue(
  FakeRemoteConfigService(overrides: {'onboarding_auto_advance_seconds': 0}),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Onboarding carousel flow (Android)', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('carousel is shown on first launch when there are no pacts', (tester) async {
      h = await AppHarness.create(tester, initiallyAnonymous: true, extraOverrides: [_noAutoAdvance]);
      final strings = l10n(tester);

      expect(find.text(strings.onboardingSlide0Title), findsOneWidget);
      expect(find.text(strings.createPact), findsOneWidget);
      // Regular dashboard chrome is not visible.
      expect(find.byKey(const Key('language-picker-button')), findsNothing);
    });

    testWidgets('swiping left advances to slide 1', (tester) async {
      h = await AppHarness.create(tester, initiallyAnonymous: true, extraOverrides: [_noAutoAdvance]);
      final strings = l10n(tester);

      // timedDrag gives the gesture a release velocity, which PageScrollPhysics
      // uses to determine whether to advance the page.
      await tester.timedDrag(
        find.text(strings.onboardingSlide0Title),
        const Offset(-400, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      expect(find.text(strings.onboardingSlide1Title), findsOneWidget);
      expect(find.text(strings.onboardingSlide0Title), findsNothing);
    });

    testWidgets('swiping right returns to slide 0', (tester) async {
      h = await AppHarness.create(tester, initiallyAnonymous: true, extraOverrides: [_noAutoAdvance]);
      final strings = l10n(tester);

      // Advance to slide 1.
      await tester.timedDrag(
        find.text(strings.onboardingSlide0Title),
        const Offset(-400, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      expect(find.text(strings.onboardingSlide1Title), findsOneWidget);

      // Swipe back to slide 0.
      await tester.timedDrag(
        find.text(strings.onboardingSlide1Title),
        const Offset(400, 0),
        const Duration(milliseconds: 300),
      );
      await waitFor(tester, find.text(strings.onboardingSlide0Title));

      expect(find.text(strings.onboardingSlide0Title), findsOneWidget);
    });

    testWidgets('tapping "Language" opens language picker and saving a locale persists it', (tester) async {
      h = await AppHarness.create(tester, initiallyAnonymous: true, extraOverrides: [_noAutoAdvance]);
      final strings = l10n(tester);

      // The carousel has a single "Language" button (dialog not yet open).
      await tester.tap(find.text(strings.languagePickerTitle));
      await tester.pumpAndSettle();

      // Platform-specific picker dialog type.
      if (Platform.isAndroid) {
        expect(find.byType(SimpleDialog), findsOneWidget);
      } else {
        expect(find.byType(CupertinoActionSheet), findsOneWidget);
      }
      expect(find.text(strings.languageFrench), findsOneWidget);

      await tester.tap(find.text(strings.languageFrench));
      await tester.pumpAndSettle();

      // Locale was persisted via the locale preference service.
      expect(h.localeService.savedLocale?.languageCode, equals('fr'));
    });
  });
}
