// Integration tests for the About screen (HAB-149).
//
// Run on host:   flutter test integration_test/about_screen_flow_test.dart
// Run on device: flutter test integration_test/about_screen_flow_test.dart -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import 'harness.dart';

Future<void> _openAboutScreen(WidgetTester tester) async {
  await waitFor(tester, find.byKey(const Key('about-button')));
  await tester.tap(find.byKey(const Key('about-button')));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('About screen', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('about_button_opens_about_screen', (tester) async {
      h = await AppHarness.create(tester);

      await waitFor(tester, find.text(l10n(tester).dashboardTitle));
      await _openAboutScreen(tester);

      expect(find.text(l10n(tester).aboutTitle), findsOneWidget);
    });

    testWidgets('about_screen_shows_app_info', (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [
          packageInfoProvider.overrideWith((_) async => PackageInfo(
                appName: 'Habit Loop',
                packageName: 'com.example.habit_loop',
                version: '1.0.0',
                buildNumber: '42',
              )),
        ],
      );

      await waitFor(tester, find.text(l10n(tester).dashboardTitle));
      await _openAboutScreen(tester);

      expect(find.text('Habit Loop'), findsWidgets);
      expect(find.text('Version 1.0.0 (build 42)'), findsOneWidget);
      expect(find.text('© 2026 Iurii Lutsenko'), findsOneWidget);
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
      h = await AppHarness.create(
        tester,
        extraOverrides: [
          remoteConfigServiceProvider.overrideWithValue(
            FakeRemoteConfigService(overrides: {
              'about_screen_enabled': false,
            }),
          ),
        ],
      );

      await waitFor(tester, find.text(l10n(tester).dashboardTitle));

      expect(find.byKey(const Key('about-button')), findsNothing);
    });
  });
}
