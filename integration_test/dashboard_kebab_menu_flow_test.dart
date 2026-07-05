// Integration tests for the dashboard kebab menu (HAB-150).
//
// Run on host:   flutter test integration_test/dashboard_kebab_menu_flow_test.dart
// Run on device: flutter test integration_test/dashboard_kebab_menu_flow_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Dashboard kebab menu', () {
    // TODO: restore late AppHarness h; tearDown(() => h.dispose());

    testWidgets('kebab_menu_tapped_shows_all_items_and_fires_analytics', (tester) async {
      // TODO: Boot harness with default RC flags (About enabled; debug build so Debug always visible)
      // TODO: Wait for dashboard title
      // TODO: Tap Key('kebab-menu-button')
      // TODO: pumpAndSettle
      // TODO: Verify About, Language, and Debug menu item labels are visible
      // TODO: Verify h.analytics.loggedEvents contains a KebabMenuOpenedEvent
    });

    testWidgets('kebab_menu_about_item_opens_about_screen', (tester) async {
      // TODO: Boot harness with default RC flags
      // TODO: Wait for dashboard title
      // TODO: Tap Key('kebab-menu-button') → pumpAndSettle
      // TODO: Tap Key('about-button') (About item inside the menu) → pumpAndSettle
      // TODO: Verify l10n(tester).aboutTitle is visible on screen
    });

    testWidgets('kebab_menu_language_item_opens_language_picker', (tester) async {
      // TODO: Boot harness with default RC flags
      // TODO: Wait for dashboard title
      // TODO: Tap Key('kebab-menu-button') → pumpAndSettle
      // TODO: Tap Key('language-picker-button') (Language item inside the menu) → pumpAndSettle
      // TODO: Verify language option labels (e.g. l10n(tester).languageEnglish) are visible
    });

    testWidgets('single_item_shortcut_skips_kebab_and_shows_standalone_button', (tester) async {
      // TODO: Boot harness with about_screen_enabled: false and language_selection_enabled: false
      //       RC overrides (leaves only Debug as the sole eligible item)
      // TODO: Wait for dashboard title
      // TODO: Verify Key('kebab-menu-button') is not found
      // TODO: Verify Key('remote-config-debug-button') is found as a standalone button
      // TODO: Tap Key('remote-config-debug-button') → pumpAndSettle
      // TODO: Verify the RC overrides screen is visible
    });
  });
}
