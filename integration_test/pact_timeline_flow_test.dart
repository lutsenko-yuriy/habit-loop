// Integration tests for the pact timeline screen (HAB-116).
//
// Run on host:   flutter test integration_test/pact_timeline_flow_test.dart
// Run on device: flutter test integration_test/pact_timeline_flow_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Pact timeline — navigation and anchors', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
      'opens_timeline_from_active_pact_detail: entry button visible; pact-created and current-state anchors shown; screen view analytics fires',
      (tester) async {
        h = await AppHarness.create(tester);
        // TODO: 1. Seed an active pact with a few done showups using h.pactRepo and h.showupRepo.
        // TODO: 2. Open pact detail via showup tile → showup detail → "View pact details" link.
        // TODO: 3. Find the "View timeline" button and assert it is visible.
        // TODO: 4. Tap "View timeline" and wait for the timeline screen to appear.
        // TODO: 5. Assert the pact-created anchor is visible (habit name and creation date present).
        // TODO: 6. Assert the current-state anchor is visible (next showup date and showups remaining present).
        // TODO: 7. Assert h.analytics contains a pact_timeline screen view with the correct pact_id and pact_status=active.
      },
    );

    testWidgets(
      'shows_pact_concluded_for_stopped_pact: pact-concluded anchor shown; current-state anchor absent',
      (tester) async {
        h = await AppHarness.create(tester);
        // TODO: 1. Seed a stopped pact (no showups required) using h.pactRepo.
        // TODO: 2. Open pact detail from the inactive pacts panel (expand pacts panel, tap pact row).
        // TODO: 3. Tap "View timeline" and wait for the timeline screen.
        // TODO: 4. Assert the pact-created anchor is visible.
        // TODO: 5. Assert the pact-concluded anchor shows the stop date and "stopped" status.
        // TODO: 6. Assert the current-state anchor is absent (pact is not active).
      },
    );
  });

  group('Pact timeline — grouping algorithm', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
      'noted_showup_shown_individually_and_tappable: noted showup not grouped; tapping opens showup detail; analytics fires',
      (tester) async {
        h = await AppHarness.create(tester);
        // TODO: 1. Seed a pact with several consecutive done showups; one showup in the middle carries a note.
        // TODO: 2. Open timeline via pact detail.
        // TODO: 3. Assert the noted showup appears as an individual event (its note text is visible).
        // TODO: 4. Tap the noted showup event item.
        // TODO: 5. Assert showup detail screen opens.
        // TODO: 6. Assert h.analytics contains a pact_timeline_milestone_tapped event with item_type=noted_showup.
      },
    );

    testWidgets(
      'short_mixed_run_shown_as_group_item: run below threshold collapses into a group item with done/failed/total counts',
      (tester) async {
        h = await AppHarness.create(tester);
        // TODO: 1. Override the tail-zone size RC param to 0 (so no showups are in the tail) and the
        //         grouping threshold to its default (10) via extraOverrides on RemoteConfigService.
        // TODO: 2. Seed a pact with a mixed run of done + failed showups totalling < 10, no notes.
        // TODO: 3. Open timeline.
        // TODO: 4. Assert a group item is visible showing total, done, and failed counts
        //         (e.g. "5 showups — 3 done, 2 missed").
        // TODO: 5. Assert no individual showup rows exist for that run.
      },
    );

    testWidgets(
      'long_same_outcome_run_shown_as_streak_item: run >= threshold shown as streak, not a group',
      (tester) async {
        h = await AppHarness.create(tester);
        // TODO: 1. Override tail-zone size to 0 via extraOverrides.
        // TODO: 2. Seed a pact with >= 10 consecutive done showups (>= default threshold), no notes.
        // TODO: 3. Open timeline.
        // TODO: 4. Assert a streak item is visible (e.g. "10 showups done in a row").
        // TODO: 5. Assert no group item is shown for that run.
      },
    );

    testWidgets(
      'tail_zone_showups_always_shown_individually: last N showups not grouped regardless of grouping rules',
      (tester) async {
        h = await AppHarness.create(tester);
        // TODO: 1. Override first-page size via extraOverrides to fit all showups on one page.
        // TODO: 2. Seed a pact with 20 consecutive done showups (10 older, 10 as tail zone by default).
        // TODO: 3. Open timeline.
        // TODO: 4. Assert the last 10 showups (tail) appear as individual or single-showup events
        //         (not collapsed into a single group/streak covering all 10).
        // TODO: 5. Assert the older 10 showups are shown as a single streak item
        //         (>= threshold, single outcome, outside tail).
      },
    );
  });

  group('Pact timeline — pagination', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
      'load_more_reveals_older_events: tapping Load More shows older events and fires analytics',
      (tester) async {
        h = await AppHarness.create(tester);
        // TODO: 1. Override first-page size to 3 via extraOverrides to keep test data small.
        // TODO: 2. Seed a pact with more than 3 showups.
        // TODO: 3. Open timeline; assert only the most recent 3 events (plus anchors) are visible.
        // TODO: 4. Trigger the "Load more" control (scroll up or tap button).
        // TODO: 5. Assert older events appear above the previously visible ones.
        // TODO: 6. Assert h.analytics contains a pact_timeline_load_more event with page_number=2.
      },
    );
  });

  group('Pact timeline — tappable events', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
      'single_showup_in_tail_zone_is_tappable: lone done/failed in tail opens showup detail; analytics fires',
      (tester) async {
        h = await AppHarness.create(tester);
        // TODO: 1. Seed a pact with exactly one done showup (no note), within the tail zone.
        // TODO: 2. Open timeline.
        // TODO: 3. Assert the single-showup event item is visible.
        // TODO: 4. Tap the single-showup event item.
        // TODO: 5. Assert showup detail screen opens.
        // TODO: 6. Assert h.analytics contains a pact_timeline_milestone_tapped event with item_type=single_showup.
      },
    );
  });

  group('Pact timeline — feature flag', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
      'flag_off_hides_timeline_entry_point: pact_timeline_enabled=false removes View Timeline button from pact detail',
      (tester) async {
        h = await AppHarness.create(tester);
        // TODO: 1. Override the pact_timeline_enabled Remote Config key to 'false' via extraOverrides
        //         on FakeRemoteConfigService.
        // TODO: 2. Seed an active pact and open pact detail.
        // TODO: 3. Assert the "View timeline" button is absent.
      },
    );
  });
}
