// On-device entry point for the language-change flow test.
//
// Run with: flutter test integration_test/language_change_flow_test.dart -d <device>
// Run on host: flutter test integration_test/language_change_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Language change flow (Android)', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('selecting Russian re-renders dashboard in Russian', (tester) async {
      h = await AppHarness.create(tester);

      // ── 1. Dashboard is in English ──────────────────────────────────────
      expect(find.text('Dashboard'), findsOneWidget);

      // ── 2. Open language picker ─────────────────────────────────────────
      await tester.tap(find.byKey(const Key('language-picker-button')));
      await tester.pumpAndSettle();

      // Android language picker renders a SimpleDialog.
      expect(find.byType(SimpleDialog), findsOneWidget);

      // ── 3. Select Russian ───────────────────────────────────────────────
      final strings = l10n(tester);
      await tester.tap(find.text(strings.languageRussian));
      await tester.pumpAndSettle();

      // ── 4. Dashboard title is now in Russian ────────────────────────────
      // The Russian translation of "Dashboard" from app_ru.arb.
      expect(find.text('Главная'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);

      // ── 5. Locale was persisted ─────────────────────────────────────────
      expect(h.localeService.savedLocale?.languageCode, equals('ru'));
    });
  });
}
