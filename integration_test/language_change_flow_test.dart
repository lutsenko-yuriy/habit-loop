// On-device entry point for the language-change flow test.
//
// Run with: flutter test integration_test/language_change_flow_test.dart -d <device>
// Run on host: flutter test integration_test/language_change_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:integration_test/integration_test.dart';

import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import 'harness.dart';

/// Disables the auto-advance timer so pumpAndSettle() can settle cleanly.
final _noAutoAdvance = remoteConfigServiceProvider.overrideWithValue(
  FakeRemoteConfigService(overrides: {'onboarding_auto_advance_seconds': 0}),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Language change flow (Android)', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('selecting Russian re-renders carousel in Russian', (tester) async {
      h = await AppHarness.create(tester, extraOverrides: [_noAutoAdvance]);
      final strings = l10n(tester);

      // ── 1. Carousel is shown in English (first launch, no pacts) ──────────
      expect(find.text(strings.onboardingSlide0Title), findsOneWidget);

      // ── 2. Open language picker via the carousel footer button ────────────
      await tester.tap(find.text(strings.languagePickerTitle));
      await tester.pumpAndSettle();

      // Android language picker renders a SimpleDialog.
      expect(find.byType(SimpleDialog), findsOneWidget);

      // ── 3. Select Russian ─────────────────────────────────────────────────
      await tester.tap(find.text(strings.languageRussian));
      await tester.pumpAndSettle();

      // ── 4. Carousel title is now in Russian ───────────────────────────────
      expect(find.text(strings.onboardingSlide0Title), findsNothing); // English gone
      expect(find.text('Строй привычку. По-настоящему.'), findsOneWidget); // Russian title

      // ── 5. Locale was persisted ───────────────────────────────────────────
      expect(h.localeService.savedLocale?.languageCode, equals('ru'));
    });
  });
}
