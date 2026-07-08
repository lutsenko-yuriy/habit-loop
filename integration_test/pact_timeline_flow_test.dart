// Integration tests for the pact timeline screen (HAB-116).
//
// Run on host:   flutter test integration_test/pact_timeline_flow_test.dart
// Run on device: flutter test integration_test/pact_timeline_flow_test.dart -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_view_model.dart';
import 'package:integration_test/integration_test.dart';

import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import 'harness.dart';

final _testNow = DateTime(2099, 6, 15, 7, 55);

// Pact used by grouping / tail-zone scenarios. Starts June 1 so that showups
// seeded as far back as May 30 are within a plausible pact window.
const _groupingPactId = 'timeline-grouping-test';
final _groupingPact = buildPact(
  id: _groupingPactId,
  habitName: 'Exercise',
  startDate: DateTime(2099, 6, 1),
  showupDuration: const Duration(minutes: 30),
);

Showup _showup(String id, DateTime scheduledAt, {ShowupStatus status = ShowupStatus.done}) => buildShowup(
      id: id,
      pactId: _groupingPactId,
      scheduledAt: scheduledAt,
      duration: const Duration(minutes: 30),
      status: status,
    );

/// RC overrides used for grouping / tail-zone tests: disables the tail zone
/// and raises the grouping threshold so the algorithm can collapse runs.
FakeRemoteConfigService _rcGrouping({
  int tailPeriodInDays = 0,
  int groupingThreshold = 10,
}) =>
    FakeRemoteConfigService(overrides: {
      'pact_timeline_no_grouping_tail_period_in_days': tailPeriodInDays,
      'pact_timeline_milestone_grouping_threshold': groupingThreshold,
    });

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _activePactId = 'timeline-test-active';
const _stoppedPactId = 'timeline-test-stopped';

final _activePact = buildPact(
  id: _activePactId,
  habitName: 'Meditate',
  startDate: DateTime(2099, 6, 13),
);

final _stoppedPact = buildPact(
  id: _stoppedPactId,
  habitName: 'Evening Walk',
  startDate: DateTime(2099, 1, 1),
  showupDuration: const Duration(minutes: 20),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 18)),
  status: PactStatus.stopped,
  stoppedAt: DateTime(2099, 3, 1),
);

final _todayShowup = buildShowup(
  id: '${_activePactId}_pending',
  pactId: _activePactId,
  scheduledAt: DateTime(2099, 6, 15, 8, 0),
);

final _notedShowup = buildShowup(
  id: '${_activePactId}_noted',
  pactId: _activePactId,
  scheduledAt: DateTime(2099, 6, 13, 8, 0),
  status: ShowupStatus.done,
  note: 'Great session today!',
);

final _singleShowup = buildShowup(
  id: '${_activePactId}_single',
  pactId: _activePactId,
  scheduledAt: DateTime(2099, 6, 14, 8, 0),
  status: ShowupStatus.done,
);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Pact timeline — navigation and anchors', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
      'opens_timeline_from_active_pact_detail: entry button visible; pact-created and current-state anchors shown; screen view analytics fires',
      (tester) async {
        h = await AppHarness.create(
          tester,
          extraOverrides: [
            todayProvider.overrideWithValue(_testNow),
            pactDetailNowProvider.overrideWithValue(_testNow),
            pactTimelineNowProvider.overrideWithValue(_testNow),
          ],
          beforePump: (h) async {
            await h.pactRepo.savePact(_activePact);
            await h.showupRepo.saveShowup(_todayShowup);
          },
        );

        final strings = l10n(tester);

        await openPactsPanel(tester);
        await openPactDetail(tester, 'Meditate');

        // ── 1. "View Timeline" button is present and tappable ─────────────────
        await waitFor(tester, find.byKey(const Key('pact-detail-timeline-button')));
        await tester.ensureVisible(find.byKey(const Key('pact-detail-timeline-button')));
        expect(find.byKey(const Key('pact-detail-timeline-button')), findsOneWidget);

        // ── 2. Tap "View Timeline" ────────────────────────────────────────────
        await openTimeline(tester);

        await waitFor(tester, find.textContaining(strings.pactTimelineTitle));
        await waitFor(tester, find.text(strings.timelinePactCreated));

        // ── 3. Pact-created anchor is visible ─────────────────────────────────
        expect(find.text(strings.timelinePactCreated), findsOneWidget);
        expect(find.text('Meditate'), findsAtLeastNWidgets(1));

        // ── 4. Current-state anchor is visible ────────────────────────────────
        // timelineCurrentState and pactStatusActive both resolve to "Active";
        // the pact detail page remains in the nav stack, so two matches are expected.
        expect(find.text(strings.timelineCurrentState), findsAtLeastNWidgets(1));

        // ── 5. Screen view analytics fired ───────────────────────────────────
        expect(
          h.analytics.loggedScreens.any((s) => s.name == 'pact_timeline'),
          isTrue,
        );
      },
    );

    testWidgets(
      'shows_pact_concluded_for_stopped_pact: pact-concluded anchor shown; current-state anchor absent',
      (tester) async {
        h = await AppHarness.create(
          tester,
          extraOverrides: [
            todayProvider.overrideWithValue(_testNow),
            pactDetailNowProvider.overrideWithValue(_testNow),
            pactTimelineNowProvider.overrideWithValue(_testNow),
          ],
          beforePump: (h) async {
            await h.pactRepo.savePact(_stoppedPact);
          },
        );

        final strings = l10n(tester);

        await openPactsPanel(tester);
        await openPactDetail(tester, 'Evening Walk');

        // ── 1. Tap "View Timeline" ────────────────────────────────────────────
        await openTimeline(tester);

        await waitFor(tester, find.textContaining(strings.pactTimelineTitle));

        // ── 2. Pact-concluded anchor is visible ───────────────────────────────
        await waitFor(tester, find.text(strings.timelinePactConcludedStopped));
        expect(find.text(strings.timelinePactConcludedStopped), findsOneWidget);

        // ── 3. Current-state anchor is absent (pact is stopped, not active) ───
        expect(find.text(strings.timelineCurrentState), findsNothing);
      },
    );
  });

  group('Pact timeline — grouping algorithm', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
      'noted_showup_shown_individually_and_tappable: noted showup not grouped; tapping opens showup detail; analytics fires',
      (tester) async {
        h = await AppHarness.create(
          tester,
          extraOverrides: [
            todayProvider.overrideWithValue(_testNow),
            pactDetailNowProvider.overrideWithValue(_testNow),
            pactTimelineNowProvider.overrideWithValue(_testNow),
          ],
          beforePump: (h) async {
            await h.pactRepo.savePact(_activePact);
            await h.showupRepo.saveShowup(_notedShowup);
            await h.showupRepo.saveShowup(_todayShowup);
          },
        );

        final strings = l10n(tester);

        await openPactsPanel(tester);
        await openPactDetail(tester, 'Meditate');
        await openTimeline(tester);

        await waitFor(tester, find.textContaining(strings.pactTimelineTitle));

        // ── 1. Note text is visible (noted showup rendered individually) ───────
        await waitFor(tester, find.text('Great session today!'));
        expect(find.text('Great session today!'), findsOneWidget);

        // ── 2. Tap the noted showup tile ──────────────────────────────────────
        final tileKey = Key('timeline-milestone-${_notedShowup.id}');
        await waitFor(tester, find.byKey(tileKey));
        await tester.tap(find.byKey(tileKey));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 100));

        // ── 3. Showup detail screen opens ─────────────────────────────────────
        await waitFor(tester, find.text(strings.showupDetailTitle));

        // ── 4. Analytics event fired ──────────────────────────────────────────
        expect(
          h.analytics.loggedEvents.any(
            (e) => e.name == 'pact_timeline_milestone_tapped' && e.toParameters()['item_type'] == 'noted_showup',
          ),
          isTrue,
        );
      },
    );

    testWidgets(
      'short_mixed_run_shown_as_group_item: run below threshold collapses into a group item with done/failed/total counts',
      (tester) async {
        // threshold=10, tail=0 (all showups are non-tail): 3 done + 4 failed = 7 total < 10 → group.
        // Seeding June 8–14 (7 days) with no gaps so the gap-filler adds nothing.
        h = await AppHarness.create(
          tester,
          extraOverrides: [
            remoteConfigServiceProvider.overrideWithValue(_rcGrouping()),
            todayProvider.overrideWithValue(_testNow),
            pactDetailNowProvider.overrideWithValue(_testNow),
            pactTimelineNowProvider.overrideWithValue(_testNow),
          ],
          beforePump: (h) async {
            await h.pactRepo.savePact(_groupingPact);
            for (var i = 0; i < 3; i++) {
              await h.showupRepo.saveShowup(_showup('gm-d$i', DateTime(2099, 6, 8 + i, 8)));
            }
            for (var i = 0; i < 4; i++) {
              await h.showupRepo
                  .saveShowup(_showup('gm-f$i', DateTime(2099, 6, 11 + i, 8), status: ShowupStatus.failed));
            }
          },
        );

        final strings = l10n(tester);

        await openPactsPanel(tester);
        await openPactDetail(tester, 'Exercise');
        await openTimeline(tester);

        await waitFor(tester, find.textContaining(strings.pactTimelineTitle));

        // ── 1. Group item shows total, done, and failed counts ─────────────────
        await waitFor(tester, find.text(strings.timelineGroup(7, 3, 4)));
        expect(find.text(strings.timelineGroup(7, 3, 4)), findsOneWidget);

        // ── 2. No individual tile keys exist for those showups ─────────────────
        for (var i = 0; i < 3; i++) {
          expect(find.byKey(Key('timeline-milestone-gm-d$i')), findsNothing);
        }
        for (var i = 0; i < 4; i++) {
          expect(find.byKey(Key('timeline-milestone-gm-f$i')), findsNothing);
        }
      },
    );

    testWidgets(
      'long_same_outcome_run_shown_as_streak_item: run >= threshold shown as streak, not a group',
      (tester) async {
        // threshold=10, tail=0: 12 consecutive done showups (Jun 3–14, no gaps) >= threshold → streak.
        // Seeding through June 14 so gap-filler adds nothing before _testNow.
        h = await AppHarness.create(
          tester,
          extraOverrides: [
            remoteConfigServiceProvider.overrideWithValue(_rcGrouping()),
            todayProvider.overrideWithValue(_testNow),
            pactDetailNowProvider.overrideWithValue(_testNow),
            pactTimelineNowProvider.overrideWithValue(_testNow),
          ],
          beforePump: (h) async {
            await h.pactRepo.savePact(_groupingPact);
            for (var i = 0; i < 12; i++) {
              await h.showupRepo.saveShowup(_showup('gs-streak-$i', DateTime(2099, 6, 3 + i, 8)));
            }
          },
        );

        final strings = l10n(tester);

        await openPactsPanel(tester);
        await openPactDetail(tester, 'Exercise');
        await openTimeline(tester);

        await waitFor(tester, find.textContaining(strings.pactTimelineTitle));

        // ── 1. Streak item is shown with all 12 showups ────────────────────────
        await waitFor(tester, find.text(strings.timelineDoneInARow(12)));
        expect(find.text(strings.timelineDoneInARow(12)), findsOneWidget);
      },
    );

    testWidgets(
      'tail_zone_shows_showups_from_last_n_days_individually: showups within the last N days shown individually; older showups grouped',
      (tester) async {
        // tail=7, now=Jun 15, cutoff=Jun 8 midnight (default threshold=1).
        // Non-tail: Jun 5–7 (3 done, same outcome → streak = 1 milestone).
        // Tail:     Jun 8–14 (7 done → 7 individual SingleShowupMilestone tiles).
        h = await AppHarness.create(
          tester,
          extraOverrides: [
            remoteConfigServiceProvider.overrideWithValue(_rcGrouping(tailPeriodInDays: 7, groupingThreshold: 1)),
            todayProvider.overrideWithValue(_testNow),
            pactDetailNowProvider.overrideWithValue(_testNow),
            pactTimelineNowProvider.overrideWithValue(_testNow),
          ],
          beforePump: (h) async {
            await h.pactRepo.savePact(_groupingPact);
            for (var i = 0; i < 3; i++) {
              await h.showupRepo.saveShowup(_showup('gs-old-$i', DateTime(2099, 6, 5 + i, 8)));
            }
            for (var i = 0; i < 7; i++) {
              await h.showupRepo.saveShowup(_showup('gs-tail-$i', DateTime(2099, 6, 8 + i, 8)));
            }
          },
        );

        final strings = l10n(tester);

        await openPactsPanel(tester);
        await openPactDetail(tester, 'Exercise');
        await openTimeline(tester);

        await waitFor(tester, find.textContaining(strings.pactTimelineTitle));

        // ── 1. Each of the 7 tail showups has its own tappable tile ───────────
        for (var i = 0; i < 7; i++) {
          await waitFor(tester, find.byKey(Key('timeline-milestone-gs-tail-$i')));
          expect(find.byKey(Key('timeline-milestone-gs-tail-$i')), findsOneWidget);
        }

        // ── 2. The 3 older showups are collapsed into one streak item ──────────
        await waitFor(tester, find.text(strings.timelineDoneInARow(3)));
        expect(find.text(strings.timelineDoneInARow(3)), findsOneWidget);
        for (var i = 0; i < 3; i++) {
          expect(find.byKey(Key('timeline-milestone-gs-old-$i')), findsNothing);
        }
      },
    );

    testWidgets(
      'tail_zone_section_header_shows_configured_days: header reads "Showups from the last N days" using RC value',
      (tester) async {
        // tail=14, now=Jun 15, cutoff=Jun 1 (default threshold=1).
        // Non-tail: May 30 (1 done → SingleShowupMilestone, tailStartIndex=1).
        // Tail:     Jun 10 (1 done → SingleShowupMilestone) → header visible.
        h = await AppHarness.create(
          tester,
          extraOverrides: [
            remoteConfigServiceProvider.overrideWithValue(_rcGrouping(tailPeriodInDays: 14, groupingThreshold: 1)),
            todayProvider.overrideWithValue(_testNow),
            pactDetailNowProvider.overrideWithValue(_testNow),
            pactTimelineNowProvider.overrideWithValue(_testNow),
          ],
          beforePump: (h) async {
            await h.pactRepo.savePact(_groupingPact);
            await h.showupRepo.saveShowup(_showup('gs-hdr-old', DateTime(2099, 5, 30, 8)));
            await h.showupRepo.saveShowup(_showup('gs-hdr-tail', DateTime(2099, 6, 10, 8)));
          },
        );

        final strings = l10n(tester);

        await openPactsPanel(tester);
        await openPactDetail(tester, 'Exercise');
        await openTimeline(tester);

        await waitFor(tester, find.textContaining(strings.pactTimelineTitle));

        // ── Section header shows the configured number of days ─────────────────
        await waitFor(tester, find.text(strings.timelineRecentSection(14)));
        expect(find.text(strings.timelineRecentSection(14)), findsOneWidget);
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
        h = await AppHarness.create(
          tester,
          extraOverrides: [
            todayProvider.overrideWithValue(_testNow),
            pactDetailNowProvider.overrideWithValue(_testNow),
            pactTimelineNowProvider.overrideWithValue(_testNow),
          ],
          beforePump: (h) async {
            await h.pactRepo.savePact(_activePact);
            await h.showupRepo.saveShowup(_singleShowup);
            await h.showupRepo.saveShowup(_todayShowup);
          },
        );

        final strings = l10n(tester);

        await openPactsPanel(tester);
        await openPactDetail(tester, 'Meditate');
        await openTimeline(tester);

        await waitFor(tester, find.textContaining(strings.pactTimelineTitle));

        // ── 1. Single-showup tile is visible ──────────────────────────────────
        final tileKey = Key('timeline-milestone-${_singleShowup.id}');
        await waitFor(tester, find.byKey(tileKey));

        // ── 2. Tap it ─────────────────────────────────────────────────────────
        await tester.tap(find.byKey(tileKey));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 100));

        // ── 3. Showup detail screen opens ─────────────────────────────────────
        await waitFor(tester, find.text(strings.showupDetailTitle));

        // ── 4. Analytics event fired ──────────────────────────────────────────
        expect(
          h.analytics.loggedEvents.any(
            (e) => e.name == 'pact_timeline_milestone_tapped' && e.toParameters()['item_type'] == 'single_showup',
          ),
          isTrue,
        );
      },
    );
  });

  group('Pact timeline — feature flag', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
      'flag_off_hides_timeline_entry_point: pact_timeline_enabled=false removes View Timeline button from pact detail',
      (tester) async {
        h = await AppHarness.create(
          tester,
          extraOverrides: [
            todayProvider.overrideWithValue(_testNow),
            pactDetailNowProvider.overrideWithValue(_testNow),
            remoteConfigServiceProvider.overrideWithValue(
              FakeRemoteConfigService(overrides: {'pact_timeline_enabled': false}),
            ),
          ],
          beforePump: (h) async {
            await h.pactRepo.savePact(_activePact);
            await h.showupRepo.saveShowup(_todayShowup);
          },
        );

        await openPactsPanel(tester);
        await openPactDetail(tester, 'Meditate');

        // Scroll through the pact detail to ensure the button area is reached.
        await tester.drag(find.byType(ListView).last, const Offset(0, -300));
        await tester.pump();

        // ── "View Timeline" button is absent ──────────────────────────────────
        expect(find.byKey(const Key('pact-detail-timeline-button')), findsNothing);
      },
    );
  });
}
