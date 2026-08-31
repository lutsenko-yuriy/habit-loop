// Integration tests for merging break runs into a single timeline milestone,
// tail zone included (HAB-216).
//
// Run on host:   flutter test integration_test/break_timeline_flow_test.dart
// Run on device: flutter test integration_test/break_timeline_flow_test.dart -d <device>
import 'package:flutter/material.dart' show Key;
import 'package:flutter_test/flutter_test.dart';
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

const _pactId = 'break-timeline-test';
final _pact = buildPact(
  id: _pactId,
  habitName: 'Exercise',
  startDate: DateTime(2099, 6, 1),
  showupDuration: const Duration(minutes: 30),
);

Showup _showup(String id, DateTime scheduledAt, {ShowupStatus status = ShowupStatus.pending}) => buildShowup(
      id: id,
      pactId: _pactId,
      scheduledAt: scheduledAt,
      duration: const Duration(minutes: 30),
      status: status,
    );

/// RC overrides for the merged-break-milestone scenarios: a 7-day tail zone
/// (cutoff = Jun 8, relative to [_testNow] = Jun 15) plus breaks enabled.
FakeRemoteConfigService _rc({int tailPeriodInDays = 7}) => FakeRemoteConfigService(overrides: {
      'pact_timeline_no_grouping_tail_period_in_days': tailPeriodInDays,
      'pact_breaks_enabled': true,
      'display_name_personalization_enabled': false,
    });

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Pact timeline — merged break milestones (HAB-216)', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('break_inside_tailzone_renders_as_one_milestone', (tester) async {
      final onBreak = buildBreak(
        id: 'brk-1',
        pactId: _pactId,
        startDate: DateTime(2099, 6, 10),
        plannedEndDate: DateTime(2099, 6, 13),
        rationale: 'Feeling sick',
      );

      h = await AppHarness.create(
        tester,
        extraOverrides: [
          remoteConfigServiceProvider.overrideWithValue(_rc()),
          todayProvider.overrideWithValue(_testNow),
          pactDetailNowProvider.overrideWithValue(_testNow),
          pactTimelineNowProvider.overrideWithValue(_testNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(_pact);
          await h.pactBreakRepo.saveBreak(onBreak);
          for (var i = 0; i < 4; i++) {
            await h.showupRepo.saveShowup(_showup('brk1-$i', DateTime(2099, 6, 10 + i, 8)));
          }
          // Unrelated, non-tail showup so the section header actually renders —
          // an all-tail timeline shows no header at all (tailStartIndex == 0).
          await h.showupRepo.saveShowup(_showup('brk1-unrelated', DateTime(2099, 6, 1, 8), status: ShowupStatus.done));
        },
      );

      final strings = l10n(tester);

      await openPactsPanel(tester);
      await openPactDetail(tester, 'Exercise');
      await tester.pumpAndSettle();
      await openTimeline(tester);
      await waitFor(tester, find.textContaining(strings.pactTimelineTitle));

      // ── 1. Rationale appears exactly once — one merged entry, not 4 ────────
      await waitFor(tester, find.text('Feeling sick'));
      expect(find.text('Feeling sick'), findsOneWidget);

      // ── 2. No individual milestone tile for any of the 4 covered showups ───
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(Key('timeline-milestone-brk1-$i')), findsNothing);
      }

      // ── 3. The merged entry sits below the tail-zone section header ────────
      await waitFor(tester, find.text(strings.timelineRecentSection(7)));
      final headerDy = tester.getTopLeft(find.text(strings.timelineRecentSection(7))).dy;
      final rationaleDy = tester.getTopLeft(find.text('Feeling sick')).dy;
      expect(rationaleDy, greaterThan(headerDy));
    });

    testWidgets('break_spanning_tailzone_boundary_renders_as_one_milestone_below_header', (tester) async {
      final onBreak = buildBreak(
        id: 'brk-2',
        pactId: _pactId,
        startDate: DateTime(2099, 6, 5),
        plannedEndDate: DateTime(2099, 6, 10),
        rationale: 'Travel',
      );

      h = await AppHarness.create(
        tester,
        extraOverrides: [
          remoteConfigServiceProvider.overrideWithValue(_rc()),
          todayProvider.overrideWithValue(_testNow),
          pactDetailNowProvider.overrideWithValue(_testNow),
          pactTimelineNowProvider.overrideWithValue(_testNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(_pact);
          await h.pactBreakRepo.saveBreak(onBreak);
          for (var i = 0; i < 6; i++) {
            await h.showupRepo.saveShowup(_showup('brk2-$i', DateTime(2099, 6, 5 + i, 8)));
          }
          // Unrelated, non-tail showup before the break so the section header
          // actually renders above the (boundary-spanning) merged entry.
          await h.showupRepo.saveShowup(_showup('brk2-unrelated', DateTime(2099, 6, 1, 8), status: ShowupStatus.done));
        },
      );

      final strings = l10n(tester);

      await openPactsPanel(tester);
      await openPactDetail(tester, 'Exercise');
      await tester.pumpAndSettle();
      await openTimeline(tester);
      await waitFor(tester, find.textContaining(strings.pactTimelineTitle));

      // ── 1. "Travel" appears exactly once — not split into a grouped part
      //         plus individual tail entries ────────────────────────────────
      await waitFor(tester, find.text('Travel'));
      expect(find.text('Travel'), findsOneWidget);

      // ── 2. No individual milestone tile for any of the 6 covered showups ───
      for (var i = 0; i < 6; i++) {
        expect(find.byKey(Key('timeline-milestone-brk2-$i')), findsNothing);
      }

      // ── 3. Part of the run touches the tail, so the merged entry sits below
      //         the section header ───────────────────────────────────────────
      await waitFor(tester, find.text(strings.timelineRecentSection(7)));
      final headerDy = tester.getTopLeft(find.text(strings.timelineRecentSection(7))).dy;
      final rationaleDy = tester.getTopLeft(find.text('Travel')).dy;
      expect(rationaleDy, greaterThan(headerDy));
    });

    testWidgets('break_outside_tailzone_stays_above_header', (tester) async {
      final onBreak = buildBreak(
        id: 'brk-3',
        pactId: _pactId,
        startDate: DateTime(2099, 6, 1),
        plannedEndDate: DateTime(2099, 6, 3),
        rationale: 'Feeling sick',
      );

      h = await AppHarness.create(
        tester,
        extraOverrides: [
          remoteConfigServiceProvider.overrideWithValue(_rc()),
          todayProvider.overrideWithValue(_testNow),
          pactDetailNowProvider.overrideWithValue(_testNow),
          pactTimelineNowProvider.overrideWithValue(_testNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(_pact);
          await h.pactBreakRepo.saveBreak(onBreak);
          for (var i = 0; i < 3; i++) {
            await h.showupRepo.saveShowup(_showup('brk3-$i', DateTime(2099, 6, 1 + i, 8)));
          }
          // Unrelated, non-break showup inside the tail zone so the section
          // header actually renders — otherwise there'd be nothing to compare against.
          await h.showupRepo.saveShowup(_showup('brk3-unrelated', DateTime(2099, 6, 10, 8), status: ShowupStatus.done));
        },
      );

      final strings = l10n(tester);

      await openPactsPanel(tester);
      await openPactDetail(tester, 'Exercise');
      await tester.pumpAndSettle();
      await openTimeline(tester);
      await waitFor(tester, find.textContaining(strings.pactTimelineTitle));

      // ── 1. Rationale appears exactly once (regression: still merges) ───────
      await waitFor(tester, find.text('Feeling sick'));
      expect(find.text('Feeling sick'), findsOneWidget);

      // ── 2. The merged entry sits above the tail-zone section header ────────
      await waitFor(tester, find.text(strings.timelineRecentSection(7)));
      final headerDy = tester.getTopLeft(find.text(strings.timelineRecentSection(7))).dy;
      final rationaleDy = tester.getTopLeft(find.text('Feeling sick')).dy;
      expect(rationaleDy, lessThan(headerDy));
    });

    testWidgets('explicit_mark_inside_break_does_not_split_break_milestone', (tester) async {
      final onBreak = buildBreak(
        id: 'brk-4',
        pactId: _pactId,
        startDate: DateTime(2099, 6, 10),
        plannedEndDate: DateTime(2099, 6, 13),
        rationale: 'Feeling sick',
      );

      h = await AppHarness.create(
        tester,
        extraOverrides: [
          remoteConfigServiceProvider.overrideWithValue(_rc()),
          todayProvider.overrideWithValue(_testNow),
          pactDetailNowProvider.overrideWithValue(_testNow),
          pactTimelineNowProvider.overrideWithValue(_testNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(_pact);
          await h.pactBreakRepo.saveBreak(onBreak);
          await h.showupRepo.saveShowup(_showup('brk4-0', DateTime(2099, 6, 10, 8)));
          // Explicitly resolved (done) mid-break — must not split the merged entry.
          await h.showupRepo.saveShowup(_showup('brk4-1', DateTime(2099, 6, 11, 8), status: ShowupStatus.done));
          await h.showupRepo.saveShowup(_showup('brk4-2', DateTime(2099, 6, 12, 8)));
          await h.showupRepo.saveShowup(_showup('brk4-3', DateTime(2099, 6, 13, 8)));
        },
      );

      final strings = l10n(tester);

      await openPactsPanel(tester);
      await openPactDetail(tester, 'Exercise');
      await tester.pumpAndSettle();
      await openTimeline(tester);
      await waitFor(tester, find.textContaining(strings.pactTimelineTitle));

      // ── 1. One merged entry spanning all 4 days, not two around the done mark ──
      await waitFor(tester, find.text('Feeling sick'));
      expect(find.text('Feeling sick'), findsOneWidget);

      // ── 2. No individual milestone tile for the explicitly-done showup ─────
      expect(find.byKey(const Key('timeline-milestone-brk4-1')), findsNothing);

      // ── 3. The done mark still counts in the pact's stats — the merge is a
      //         rendering-only change ────────────────────────────────────────
      await tester.pageBack();
      await tester.pumpAndSettle();
      // openTimeline scrolled pact detail's own ListView down to reveal the
      // timeline button, and pageBack() preserves that scroll offset — the stats
      // section (near the top) is now off the realized extent. Reset to the top
      // the same way openTimeline resets before scrolling down, rather than
      // dragUntilVisible: the stats Row has no key and its text repeats across
      // cards, so there's no single unambiguous, always-non-empty target finder
      // to drive dragUntilVisible with.
      final listViewFinder = find.byKey(const Key('pact-detail-scroll-view-$_pactId'));
      for (var i = 0; i < 15; i++) {
        await tester.drag(listViewFinder, const Offset(0, 100));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text(strings.statsShowups(1)), findsWidgets);
    });

    testWidgets('two_adjacent_breaks_render_as_two_milestones', (tester) async {
      final breakA = buildBreak(
        id: 'brk-5a',
        pactId: _pactId,
        startDate: DateTime(2099, 6, 10),
        plannedEndDate: DateTime(2099, 6, 11),
        rationale: 'Feeling sick',
      );
      final breakB = buildBreak(
        id: 'brk-5b',
        pactId: _pactId,
        startDate: DateTime(2099, 6, 12),
        plannedEndDate: DateTime(2099, 6, 13),
        rationale: 'Travel',
      );

      h = await AppHarness.create(
        tester,
        extraOverrides: [
          remoteConfigServiceProvider.overrideWithValue(_rc()),
          todayProvider.overrideWithValue(_testNow),
          pactDetailNowProvider.overrideWithValue(_testNow),
          pactTimelineNowProvider.overrideWithValue(_testNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(_pact);
          await h.pactBreakRepo.saveBreak(breakA);
          await h.pactBreakRepo.saveBreak(breakB);
          for (var i = 0; i < 4; i++) {
            await h.showupRepo.saveShowup(_showup('brk5-$i', DateTime(2099, 6, 10 + i, 8)));
          }
        },
      );

      final strings = l10n(tester);

      await openPactsPanel(tester);
      await openPactDetail(tester, 'Exercise');
      await tester.pumpAndSettle();
      await openTimeline(tester);
      await waitFor(tester, find.textContaining(strings.pactTimelineTitle));

      // ── Both rationales appear exactly once — two separate milestones ──────
      await waitFor(tester, find.text('Feeling sick'));
      expect(find.text('Feeling sick'), findsOneWidget);
      expect(find.text('Travel'), findsOneWidget);
    });
  });
}
