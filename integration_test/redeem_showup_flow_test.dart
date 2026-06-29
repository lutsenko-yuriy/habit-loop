// Integration tests for the showup redemption flow (HAB-139).
//
// Run on host:   flutter test integration_test/redeem_showup_flow_test.dart
// Run on device: flutter test integration_test/redeem_showup_flow_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Redeem showup flow', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
      'redeem_auto_failed_showup_with_note_succeeds: redemption marks showup done, updates stats, and fires showup_redeemed',
      (tester) async {
        h = await AppHarness.create(tester);
        // TODO: 1. Seed an active pact and a showup with status=failed, redeemable=true,
        //          scheduled 2 days ago (within 7-day tail zone), with a non-empty saved note.
        // TODO: 2. Boot the app with the clock pinned to _testNow (today = June 15 2099);
        //          override todayProvider, pactDetailNowProvider, pactTimelineNowProvider,
        //          and showupDetailNowProvider.
        // TODO: 3. Open the pacts panel, navigate to pact detail, tap "View Timeline".
        // TODO: 4. Tap the tail-zone showup tile (Key('timeline-milestone-{showupId}')).
        // TODO: 5. Verify the redemption button is visible and enabled.
        // TODO: 6. Tap the redemption button.
        // TODO: 7. Verify the status chip now shows "Done".
        // TODO: 8. Verify h.analytics contains a showup_redeemed event with the correct pact_id.
        // TODO: 9. Navigate back to pact detail and verify done count increased and failed count decreased.
      },
    );

    testWidgets(
      'redemption_button_disabled_when_note_is_empty: button visible but disabled with explanatory label; fires showup_redemption_blocked on screen load',
      (tester) async {
        h = await AppHarness.create(tester);
        // TODO: 1. Seed an active pact and a showup with status=failed, redeemable=true,
        //          scheduled 2 days ago (within tail zone), with no note.
        // TODO: 2. Boot the app with the clock pinned to _testNow; override time providers.
        // TODO: 3. Open the pacts panel, navigate to pact detail, tap "View Timeline".
        // TODO: 4. Tap the tail-zone showup tile to open showup detail.
        // TODO: 5. Verify the redemption button is visible but disabled
        //          (Key('showup-redeem-button') found but not tappable).
        // TODO: 6. Verify the button label indicates a non-empty note is required.
        // TODO: 7. Verify h.analytics contains a showup_redemption_blocked event with the correct pact_id.
        // TODO: 8. Verify the status chip still shows "Failed".
      },
    );

    testWidgets(
      'no_redemption_action_for_manually_failed_showup: redeemable=false hides the redemption button entirely',
      (tester) async {
        h = await AppHarness.create(tester);
        // TODO: 1. Seed an active pact and a showup with status=failed, redeemable=false,
        //          scheduled 2 days ago (within tail zone).
        // TODO: 2. Boot the app with the clock pinned to _testNow; override time providers.
        // TODO: 3. Open the pacts panel, navigate to pact detail, tap "View Timeline".
        // TODO: 4. Tap the tail-zone showup tile to open showup detail.
        // TODO: 5. Verify Key('showup-redeem-button') is absent.
      },
    );

    testWidgets(
      'no_redemption_action_for_out_of_tail_zone_showup: showup older than N days hides the redemption button',
      (tester) async {
        h = await AppHarness.create(tester);
        // TODO: 1. Seed an active pact and a showup with status=failed, redeemable=true,
        //          scheduled 30 days ago (well outside the 7-day default tail zone).
        // TODO: 2. Boot the app with the clock pinned to _testNow; override time providers.
        // TODO: 3. Open the pacts panel, navigate to pact detail, tap "View Timeline";
        //          use "Load more" if needed to reveal the older showup.
        // TODO: 4. Navigate to the showup detail screen for the old failed showup.
        // TODO: 5. Verify Key('showup-redeem-button') is absent.
      },
    );
  });
}
