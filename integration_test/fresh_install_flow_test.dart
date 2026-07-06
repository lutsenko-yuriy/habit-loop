// Flow tests for the iOS Keychain persistence bug fix (HAB-71).
//
// On iOS, Firebase Auth credentials survive app uninstall/reinstall in the
// Keychain. main.dart calls clearStaleKeychainIfFirstLaunch() before
// authService.initialize() to sign out any stale user when no device ID key
// is present in SharedPreferences (= true fresh install).
//
// Run with: flutter test integration_test/fresh_install_flow_test.dart -d <device>
// Run on host: flutter test integration_test/fresh_install_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/auth/data/first_launch_auth_fix.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import 'harness.dart';

/// Disables the onboarding auto-advance timer (RC value < _minAutoAdvanceSeconds=5).
final _noAutoAdvance = remoteConfigServiceProvider.overrideWithValue(
  FakeRemoteConfigService(overrides: {'onboarding_auto_advance_seconds': 0}),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Fresh install Keychain fix flow', () {
    late AppHarness h;
    tearDown(() async {
      await h.dispose();
      SharedPreferences.resetStatic();
    });

    testWidgets(
      'fresh install with stale Keychain auth: signs out and shows not-linked state',
      (tester) async {
        // No launched key → first launch after reinstall on iOS.
        SharedPreferences.setMockInitialValues({});

        h = await AppHarness.create(
          tester,
          // Simulate a stale Google-linked user from the iOS Keychain.
          initiallyAnonymous: false,
          extraOverrides: [_noAutoAdvance],
          beforePump: (h) async {
            // Mirror what main.dart does: clear stale auth before initialize().
            final prefs = await SharedPreferences.getInstance();
            await clearStaleKeychainIfFirstLaunch(authService: h.auth, prefs: prefs);
          },
        );

        // After clearStaleKeychainIfFirstLaunch(), auth is anonymous.
        // No pacts exist, so the onboarding carousel is shown. The carousel
        // renders "Sign in with Google" only when isAnonymous is true —
        // confirming the stale auth was cleared.
        final strings = l10n(tester);
        await waitFor(tester, find.text(strings.signInWithGoogle));
        expect(find.text(strings.signInWithGoogle), findsOneWidget);
      },
    );

    testWidgets(
      'returning user with device ID is not affected: stays logged in',
      (tester) async {
        // Launched key present → returning user, not a fresh install.
        SharedPreferences.setMockInitialValues({firstLaunchHandledKey: true});

        h = await AppHarness.create(
          tester,
          initiallyAnonymous: false, // Google-linked user
          beforePump: (h) async {
            final prefs = await SharedPreferences.getInstance();
            // clearStaleKeychainIfFirstLaunch is a no-op when launched key exists.
            await clearStaleKeychainIfFirstLaunch(authService: h.auth, prefs: prefs);
          },
        );

        // User stays Google-linked → cloud_off (notLinked) must not appear.
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.byIcon(Icons.cloud_off_outlined), findsNothing);
      },
    );
  });
}
