// Flow tests for the iOS Keychain persistence bug fix (HAB-71).
//
// On iOS, Firebase Auth credentials survive app uninstall/reinstall in the
// Keychain. main.dart calls clearStaleKeychainIfFirstLaunch() before
// authService.initialize() to sign out any stale user when no device ID key
// is present in SharedPreferences (= true fresh install).
//
// Run with: flutter test integration_test/fresh_install_flow_test.dart -d <device>
// Run on host: flutter test integration_test/fresh_install_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/infrastructure/auth/data/first_launch_auth_fix.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/sync_ui_state.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Fresh install Keychain fix flow', () {
    late AppHarness h;
    tearDown(() {
      h.dispose();
      SharedPreferences.resetStatic();
    });

    testWidgets(
      'stale_keychain_auth_signs_out: fresh install with stale Keychain auth signs out and shows not-linked state',
      (tester) async {
        // No launched key → first launch after reinstall on iOS.
        SharedPreferences.setMockInitialValues({});

        h = await AppHarness.create(
          tester,
          // Simulate a stale Google-linked user from the iOS Keychain.
          initiallyAnonymous: false,
          extraOverrides: [noAutoAdvance],
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
      'returning_user_with_device_id_stays_logged_in: returning user with a device ID is not affected by the stale-Keychain fix and stays logged in',
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
        expect(find.byIcon(syncIconFor(SyncUiState.notLinked)), findsNothing);
      },
    );
  });
}
