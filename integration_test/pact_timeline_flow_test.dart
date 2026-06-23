// Integration tests for the pact timeline screen (HAB-116).
//
// Run on host:   flutter test integration_test/pact_timeline_flow_test.dart
// Run on device: flutter test integration_test/pact_timeline_flow_test.dart -d <device>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
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

// ── Fixtures ──────────────────────────────────────────────────────────────────

const _activePactId = 'timeline-test-active';
const _stoppedPactId = 'timeline-test-stopped';

final _activePact = Pact(
  id: _activePactId,
  habitName: 'Meditate',
  startDate: DateTime(2099, 6, 13),
  endDate: DateTime(2099, 12, 31),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
  createdAt: DateTime(2099, 6, 13),
);

final _stoppedPact = Pact(
  id: _stoppedPactId,
  habitName: 'Evening Walk',
  startDate: DateTime(2099, 1, 1),
  endDate: DateTime(2099, 12, 31),
  showupDuration: const Duration(minutes: 20),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 18)),
  status: PactStatus.stopped,
  stoppedAt: DateTime(2099, 3, 1),
  createdAt: DateTime(2099, 1, 1),
);

final _todayShowup = Showup(
  id: '${_activePactId}_pending',
  pactId: _activePactId,
  scheduledAt: DateTime(2099, 6, 15, 8, 0),
  duration: const Duration(minutes: 10),
  status: ShowupStatus.pending,
);

final _notedShowup = Showup(
  id: '${_activePactId}_noted',
  pactId: _activePactId,
  scheduledAt: DateTime(2099, 6, 13, 8, 0),
  duration: const Duration(minutes: 10),
  status: ShowupStatus.done,
  note: 'Great session today!',
);

final _singleShowup = Showup(
  id: '${_activePactId}_single',
  pactId: _activePactId,
  scheduledAt: DateTime(2099, 6, 14, 8, 0),
  duration: const Duration(minutes: 10),
  status: ShowupStatus.done,
);

// ── Helpers ───────────────────────────────────────────────────────────────────

Future<void> _openPactsPanel(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('pacts-panel-drag-handle')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _openPactDetail(WidgetTester tester, String habitName) async {
  await waitFor(tester, find.text(habitName));
  await tester.tap(find.text(habitName).last);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _openTimeline(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('pact-detail-timeline-button')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('pact-detail-timeline-button')));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 100));
}

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

        await _openPactsPanel(tester);
        await _openPactDetail(tester, 'Meditate');

        // ── 1. "View Timeline" button is present and tappable ─────────────────
        await tester.ensureVisible(find.byKey(const Key('pact-detail-timeline-button')));
        expect(find.byKey(const Key('pact-detail-timeline-button')), findsOneWidget);

        // ── 2. Tap "View Timeline" ────────────────────────────────────────────
        await _openTimeline(tester);

        await waitFor(tester, find.text(strings.pactTimelineTitle));
        await waitFor(tester, find.text(strings.timelinePactCreated));

        // ── 3. Pact-created anchor is visible ─────────────────────────────────
        expect(find.text(strings.timelinePactCreated), findsOneWidget);
        expect(find.text('Meditate'), findsAtLeastNWidgets(1));

        // ── 4. Current-state anchor is visible ────────────────────────────────
        expect(find.text(strings.timelineCurrentState), findsOneWidget);

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

        await _openPactsPanel(tester);
        await _openPactDetail(tester, 'Evening Walk');

        // ── 1. Tap "View Timeline" ────────────────────────────────────────────
        await _openTimeline(tester);

        await waitFor(tester, find.text(strings.pactTimelineTitle));

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

        await _openPactsPanel(tester);
        await _openPactDetail(tester, 'Meditate');
        await _openTimeline(tester);

        await waitFor(tester, find.text(strings.pactTimelineTitle));

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

        await _openPactsPanel(tester);
        await _openPactDetail(tester, 'Meditate');
        await _openTimeline(tester);

        await waitFor(tester, find.text(strings.pactTimelineTitle));

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

        await _openPactsPanel(tester);
        await _openPactDetail(tester, 'Meditate');

        // Scroll through the pact detail to ensure the button area is reached.
        await tester.drag(find.byType(ListView).last, const Offset(0, -300));
        await tester.pump();

        // ── "View Timeline" button is absent ──────────────────────────────────
        expect(find.byKey(const Key('pact-detail-timeline-button')), findsNothing);
      },
    );
  });
}
