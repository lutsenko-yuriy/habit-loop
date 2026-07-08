// Integration tests for the dashboard kebab menu (HAB-150).
//
// Run on host:   flutter test integration_test/dashboard_kebab_menu_flow_test.dart
// Run on device: flutter test integration_test/dashboard_kebab_menu_flow_test.dart -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/analytics/kebab_analytics_events.dart';
import 'package:integration_test/integration_test.dart';

import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Dashboard kebab menu', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
        'kebab_menu_tapped_shows_all_items_and_fires_analytics: tapping the kebab menu shows About, Language, and Debug items and fires KebabMenuOpenedEvent',
        (tester) async {
      h = await AppHarness.create(tester);

      await waitFor(tester, find.text(l10n(tester).dashboardTitle));
      await tester.tap(find.byKey(const Key('kebab-menu-button')));
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).aboutTitle), findsOneWidget);
      expect(find.text(l10n(tester).languagePickerTitle), findsOneWidget);
      expect(find.text(l10n(tester).dashboardDebugMenuItem), findsOneWidget);
      expect(h.analytics.loggedEvents.whereType<KebabMenuOpenedEvent>(), isNotEmpty);
    });

    testWidgets(
        'kebab_menu_about_item_opens_about_screen: tapping the About item in the kebab menu opens the About screen',
        (tester) async {
      h = await AppHarness.create(tester);

      await waitFor(tester, find.text(l10n(tester).dashboardTitle));
      await tester.tap(find.byKey(const Key('kebab-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('about-button')));
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).aboutTitle), findsOneWidget);
    });

    testWidgets(
        'kebab_menu_language_item_opens_language_picker: tapping the Language item in the kebab menu opens the language picker with all four locales',
        (tester) async {
      h = await AppHarness.create(tester);

      await waitFor(tester, find.text(l10n(tester).dashboardTitle));
      await tester.tap(find.byKey(const Key('kebab-menu-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('language-picker-button')));
      await tester.pumpAndSettle();

      expect(find.text(l10n(tester).languageEnglish), findsOneWidget);
      expect(find.text(l10n(tester).languageFrench), findsOneWidget);
      expect(find.text(l10n(tester).languageGerman), findsOneWidget);
      expect(find.text(l10n(tester).languageRussian), findsOneWidget);
    });

    testWidgets(
        'single_item_shortcut_skips_kebab_and_shows_standalone_button: with only the debug item enabled, the kebab menu is skipped in favor of a standalone debug button',
        (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [
          remoteConfigServiceProvider.overrideWithValue(
            FakeRemoteConfigService(overrides: {
              'about_screen_enabled': false,
              'language_selection_enabled': false,
            }),
          ),
        ],
      );

      await waitFor(tester, find.text(l10n(tester).dashboardTitle));

      expect(find.byKey(const Key('kebab-menu-button')), findsNothing);
      expect(find.byKey(const Key('remote-config-debug-button')), findsOneWidget);

      await tester.tap(find.byKey(const Key('remote-config-debug-button')));
      await tester.pumpAndSettle();

      expect(find.text('Remote Config'), findsOneWidget);
    });
  });
}
