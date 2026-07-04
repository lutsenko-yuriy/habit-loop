// Integration tests for the About screen (HAB-149).
//
// Run on host:   flutter test integration_test/about_screen_flow_test.dart
// Run on device: flutter test integration_test/about_screen_flow_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:integration_test/integration_test.dart';

import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('About screen', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('about_button_opens_about_screen', (tester) async {
      // TODO: Create harness with no pacts (standard dashboard state).
      // TODO: Wait for dashboard to load (waitFor dashboard title).
      // TODO: Find the About icon button in the dashboard nav bar (top-right) and tap it.
      // TODO: Pump frames.
      // TODO: Assert the About screen title (l10n(tester).aboutTitle) is visible.
    });

    testWidgets('about_screen_shows_app_info', (tester) async {
      // TODO: Create harness; override packageInfoProvider to return a stub PackageInfo
      //       with version: '1.0.0' and buildNumber: '42'.
      // TODO: Navigate to the About screen (tap About icon button on dashboard).
      // TODO: Pump frames.
      // TODO: Assert "Habit Loop" is visible.
      // TODO: Assert the version/build string (e.g. "Version 1.0.0 (build 42)") is visible.
      // TODO: Assert the copyright text "© 2026 Iurii Lutsenko" is visible.
    });

    testWidgets('feedback_tapped_fires_analytics_event', (tester) async {
      // TODO: Create harness.
      // TODO: Navigate to the About screen (tap About icon button on dashboard).
      // TODO: Pump frames.
      // TODO: Tap the "Send feedback" row (l10n(tester).aboutSendFeedback).
      // TODO: Pump frames.
      // TODO: Assert h.analytics.loggedEvents contains one event with name 'feedback_tapped'.
    });

    testWidgets('licences_row_opens_licence_page', (tester) async {
      // TODO: Create harness.
      // TODO: Navigate to the About screen (tap About icon button on dashboard).
      // TODO: Pump frames.
      // TODO: Tap the "Licences" row (l10n(tester).aboutLicences).
      // TODO: Pump frames.
      // TODO: Assert a widget with text "Licenses" (Flutter's LicensePage title) is visible.
    });

    testWidgets('about_button_hidden_when_flag_disabled', (tester) async {
      // TODO: Create harness with extraOverrides: [
      //         remoteConfigServiceProvider.overrideWithValue(
      //           FakeRemoteConfigService(overrides: {'about_screen_enabled': false}),
      //         ),
      //       ]
      // TODO: Wait for dashboard to load.
      // TODO: Assert the About icon button is NOT present in the widget tree.
    });
  });
}
