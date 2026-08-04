// Integration tests for pact breaks (HAB-195): pausing a pact without
// failing showups.
//
// Run on host:   flutter test integration_test/break_flow_test.dart
// Run on device: flutter test integration_test/break_flow_test.dart -d <device>
import 'package:flutter/material.dart' show FilterChip, Key, Navigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_break_creation_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_list_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_timeline_view_model.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';
import 'package:integration_test/integration_test.dart';

import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import 'harness.dart';

// pact_breaks_enabled now defaults to true (HAB-195 WU6) — this override is
// kept for explicitness/determinism, independent of the production default.
final _breaksEnabled = remoteConfigServiceProvider.overrideWithValue(
  FakeRemoteConfigService(overrides: {'pact_breaks_enabled': true}),
);

Future<void> _openShowupDetailFromTimeline(WidgetTester tester, String showupId) async {
  final tileKey = Key('timeline-milestone-$showupId');
  await waitFor(tester, find.byKey(tileKey));
  await tester.tap(find.byKey(tileKey));
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Types [rationale] into the break-rationale field and submits.
///
/// The keyboard-inset relayout must settle *before* `ensureVisible` computes
/// its scroll target — a bare `pump()` doesn't advance time, so on a
/// still-growing inset `ensureVisible` under-scrolls and the submit button
/// ends up back under the keyboard once the inset finishes animating in,
/// causing tap() to miss it (HAB-199: confirmed via CI diagnostic — the
/// button's unscrolled rect was identical between a passing and a failing
/// run, only the scroll offset differed).
Future<void> _enterRationaleAndSubmit(WidgetTester tester, String rationale) async {
  await tester.enterText(find.byKey(const Key('break-rationale-field')), rationale);
  await tester.pump(const Duration(milliseconds: 450));
  await tester.ensureVisible(find.byKey(const Key('break-submit-button')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('break-submit-button')));
  await tester.pump(const Duration(milliseconds: 450));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Start break flow', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('start_break_fixed_end_marks_inwindow_showups_onbreak', (tester) async {
      const pactId = 'test-pact-start-break-fixed';
      final pact = buildPact(id: pactId, habitName: 'Meditate', startDate: DateTime(2099, 6, 15));
      final testNow = DateTime(2099, 6, 15, 7, 0);

      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(testNow),
          pactListNowProvider.overrideWithValue(testNow),
          pactBreakCreationNowProvider.overrideWithValue(testNow),
          _breaksEnabled,
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
        },
      );

      await openPactsPanel(tester);
      await openPactDetail(tester, 'Meditate');

      await scrollToPactDetailStartBreakButton(tester);
      await tester.pump();
      await tester.tap(find.byKey(const Key('pact-detail-start-break-button')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 100));

      // Accept the flow's default dates (today .. today+7) — consistent with
      // how create_pact_flow_test.dart never drives the native date picker —
      // and only fill in the mandatory rationale.
      await _enterRationaleAndSubmit(tester, 'Feeling sick');

      // Back on Pact Detail: the break was persisted and blocks a new one.
      expect(find.byKey(const Key('pact-detail-start-break-button')), findsNothing);

      // The break-creation screen fired its own screen view (it's a full
      // screen, not a dialog, so unlike stop-pact it's tracked separately).
      expect(h.analytics.loggedScreens.any((s) => s.name == 'pact_break_creation'), isTrue);

      final breaks = await h.pactBreakRepo.getBreaksForPact(pactId);
      expect(breaks, hasLength(1));
      expect(breaks.first.startDate, DateTime(2099, 6, 15));
      expect(breaks.first.plannedEndDate, DateTime(2099, 6, 22));
      expect(breaks.first.rationale, 'Feeling sick');

      // A showup inside the window is not auto-failed even once its window
      // elapses — the underlying suppression is already covered by WU3's own
      // scenario; here we only assert the break was created with the
      // in-window showups it's meant to cover.
      final allShowups = await h.showupRepo.getShowupsForPact(pactId);
      final inWindow = allShowups.where((s) => breaks.first.contains(s.scheduledAt));
      final outOfWindow = allShowups.where((s) => !breaks.first.contains(s.scheduledAt));
      expect(inWindow, isNotEmpty);
      expect(outOfWindow, isNotEmpty);
    });

    testWidgets('start_break_until_pact_ends_marks_future_showups_onbreak', (tester) async {
      const pactId = 'test-pact-start-break-open-ended';
      final pact = buildPact(id: pactId, habitName: 'Jog', startDate: DateTime(2099, 6, 15));
      final testNow = DateTime(2099, 6, 15, 7, 0);

      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(testNow),
          pactListNowProvider.overrideWithValue(testNow),
          pactBreakCreationNowProvider.overrideWithValue(testNow),
          _breaksEnabled,
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
        },
      );

      await openPactsPanel(tester);
      await openPactDetail(tester, 'Jog');

      await scrollToPactDetailStartBreakButton(tester);
      await tester.pump();
      await tester.tap(find.byKey(const Key('pact-detail-start-break-button')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const Key('break-until-pact-ends-switch')));
      await tester.pumpAndSettle(); // let the end-date row's AnimatedSwitcher collapse finish
      expect(find.byKey(const Key('break-end-date-row')), findsNothing);

      await _enterRationaleAndSubmit(tester, 'Travel');

      final breaks = await h.pactBreakRepo.getBreaksForPact(pactId);
      expect(breaks, hasLength(1));
      expect(breaks.first.plannedEndDate, isNull, reason: 'The open-ended toggle must persist a null planned end date');

      // A far-future showup is still covered by an open-ended window.
      final farFuture = DateTime(2099, 12, 1);
      expect(breaks.first.contains(farFuture), isTrue);
    });

    testWidgets('start_break_requires_rationale', (tester) async {
      const pactId = 'test-pact-start-break-rationale-gate';
      final pact = buildPact(id: pactId, habitName: 'Read', startDate: DateTime(2099, 6, 15));
      final testNow = DateTime(2099, 6, 15, 7, 0);

      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(testNow),
          pactListNowProvider.overrideWithValue(testNow),
          pactBreakCreationNowProvider.overrideWithValue(testNow),
          _breaksEnabled,
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
        },
      );

      await openPactsPanel(tester);
      await openPactDetail(tester, 'Read');

      await scrollToPactDetailStartBreakButton(tester);
      await tester.pump();
      await tester.tap(find.byKey(const Key('pact-detail-start-break-button')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 100));

      // Rationale left empty — submit is a no-op and no break is persisted.
      await tester.tap(find.byKey(const Key('break-submit-button')));
      await tester.pump(const Duration(milliseconds: 350));
      expect(await h.pactBreakRepo.getBreaksForPact(pactId), isEmpty);
      // Still on the break-creation screen, not popped back to Pact Detail.
      expect(find.byKey(const Key('break-submit-button')), findsOneWidget);

      await _enterRationaleAndSubmit(tester, 'Busy week');

      final breaks = await h.pactBreakRepo.getBreaksForPact(pactId);
      expect(breaks, hasLength(1));
      expect(breaks.first.rationale, 'Busy week');
    });

    testWidgets('start_break_from_tailzone_showup_defaults_to_today', (tester) async {
      const pactId = 'test-pact-tailzone-break';
      final pact = buildPact(id: pactId, habitName: 'Read', startDate: DateTime(2099, 6, 1));

      // 1 day before testNow — within the 7-day tail zone. The dashboard's
      // gap-fill sweep generates June 15+ only (mirrors redeem_showup_flow_test.dart's
      // approach), so this stays the sole showup and auto-fails nothing else.
      const showupId = 'tailzone-break-showup';
      final showupAt = DateTime(2099, 6, 14, 8, 0);
      final testNow = DateTime(2099, 6, 15, 7, 55);
      final showup = buildShowup(id: showupId, pactId: pactId, scheduledAt: showupAt, status: ShowupStatus.failed);

      // A later showup (outside this seeded pair) that will fall inside the
      // break window created below, to verify it gets marked on-break.
      const laterShowupId = 'tailzone-break-later-showup';
      final laterShowupAt = DateTime(2099, 6, 16, 8, 0);
      final laterShowup = buildShowup(id: laterShowupId, pactId: pactId, scheduledAt: laterShowupAt);

      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(testNow),
          pactListNowProvider.overrideWithValue(testNow),
          pactDetailNowProvider.overrideWithValue(testNow),
          pactTimelineNowProvider.overrideWithValue(testNow),
          showupDetailNowProvider.overrideWithValue(testNow),
          pactBreakCreationNowProvider.overrideWithValue(testNow),
          _breaksEnabled,
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
          await h.showupRepo.saveShowup(showup);
          await h.showupRepo.saveShowup(laterShowup);
        },
      );

      // ── 1. Open the tail-zone (auto-failed, past) showup's detail via the timeline ──
      await openPactsPanel(tester);
      await openPactDetail(tester, 'Read');
      await openTimeline(tester);
      await _openShowupDetailFromTimeline(tester, showupId);

      // ── 2. The break entry point is present ───────────────────────────────
      await waitFor(tester, find.byKey(const Key('showup-detail-start-break-button')));

      // ── 3. Tap it and submit — defaults are accepted (today .. today+7) ────
      await tester.tap(find.byKey(const Key('showup-detail-start-break-button')));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 100));

      await _enterRationaleAndSubmit(tester, 'Feeling sick');

      // ── 4. Start date defaults to today (testNow's date), not the past
      //         triggering showup's own (June 14) date ─────────────────────
      final breaks = await h.pactBreakRepo.getBreaksForPact(pactId);
      expect(breaks, hasLength(1));
      expect(breaks.first.startDate, DateTime(2099, 6, 15));

      // ── 5. The triggering showup is unaffected — still failed, unchanged ──
      final triggering = await h.showupRepo.getShowupById(showupId);
      expect(triggering?.status, ShowupStatus.failed);
      expect(breaks.first.contains(showupAt), isFalse,
          reason: 'The break starts today (June 15), so it must not retroactively cover the June 14 showup');

      // ── 6. A later showup that does fall inside the new window is on-break ──
      expect(breaks.first.contains(laterShowupAt), isTrue);

      // ── 7. pact_break_started fired with source=tail_zone_showup ──────────
      final started = h.analytics.loggedEvents.firstWhere((e) => e.name == 'pact_break_started');
      expect(started.toParameters()['source'], 'tail_zone_showup');
    });

    testWidgets('start_break_blocked_while_break_active', (tester) async {
      const pactId = 'test-pact-start-break-blocked';
      final pact = buildPact(id: pactId, habitName: 'Stretch', startDate: DateTime(2099, 6, 1));
      final existingBreak = buildBreak(
        id: 'brk-existing',
        pactId: pactId,
        startDate: DateTime(2099, 6, 10),
        plannedEndDate: DateTime(2099, 6, 20),
        rationale: 'Already on break',
      );
      final testNow = DateTime(2099, 6, 15, 7, 0);

      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(testNow),
          pactListNowProvider.overrideWithValue(testNow),
          pactBreakCreationNowProvider.overrideWithValue(testNow),
          _breaksEnabled,
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
          await h.pactBreakRepo.saveBreak(existingBreak);
        },
      );

      // The Break chip defaults to selected (HAB-212), so the on-break pact's
      // tile already renders in the panel — no chip interaction needed before
      // tapping it by habit name (previously masked by HAB-211's
      // PactListViewModel bug, which made onBreak evaluate against real
      // wall-clock time instead of this test's overridden todayProvider, so
      // it never actually hit the on-break filter path here).
      await openPactsPanel(tester);
      await waitFor(tester, find.text('Stretch'));
      await openPactDetail(tester, 'Stretch');
      await waitFor(tester, find.text('Stretch'));

      // The pact is active but already has an unresolved break — the
      // entry point to start a new one must not be offered.
      expect(find.byKey(const Key('pact-detail-start-break-button')), findsNothing);
    });
  });

  group('Break suppresses auto-fail and notifications', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('onbreak_showup_not_autofailed_by_sweep_or_late_open', (tester) async {
      const pactId = 'test-pact-onbreak-suppression';
      final pact = buildPact(id: pactId, habitName: 'Meditate', startDate: DateTime(2099, 6, 1));
      // Deterministic ID matching ShowupGenerator's output, seeded exactly on
      // "today" so the gap-fill sweep has no earlier gap to backfill.
      const showupId = '${pactId}_20990615T080000_0';
      final showup = buildShowup(id: showupId, pactId: pactId, scheduledAt: DateTime(2099, 6, 15, 8, 0));
      final onBreak = buildBreak(
        id: 'brk-1',
        pactId: pactId,
        startDate: DateTime(2099, 6, 10),
        plannedEndDate: DateTime(2099, 6, 20),
        rationale: 'Sick',
      );

      // Clock well past the showup's window end (08:00 + 10 min default
      // duration) — would normally trigger auto-fail on both the dashboard
      // sweep and a late showup-detail open.
      final testNow = DateTime(2099, 6, 15, 12, 0);

      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(testNow),
          pactListNowProvider.overrideWithValue(testNow),
          showupDetailNowProvider.overrideWithValue(testNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
          await h.showupRepo.saveShowups([showup]);
          await h.pactBreakRepo.saveBreak(onBreak);
        },
      );

      // ── 1. Dashboard load's sweep must not auto-fail the on-break showup ──
      await waitFor(tester, find.text('Meditate'));
      final afterDashboardLoad = await h.showupRepo.getShowupById(showupId);
      expect(afterDashboardLoad?.status, ShowupStatus.pending,
          reason: 'On-break showup must not be auto-failed by the dashboard sweep');

      // ── 2. Opening showup detail directly must also not auto-fail it ─────
      // The status badge shows "On break" (WU5.1's on-break visual
      // treatment), not the plain "Pending" label — this still asserts the
      // underlying auto-fail suppression, just via the correct post-WU5.1 text.
      await tester.tap(find.text('Meditate').first);
      final strings = l10n(tester);
      await waitFor(tester, find.text(strings.showupOnBreak));
      expect(find.text(strings.showupOnBreak), findsOneWidget,
          reason: 'On-break showup must display as On break (not Failed) on a late open');

      final persisted = await h.showupRepo.getShowupById(showupId);
      expect(persisted?.status, ShowupStatus.pending);
    });

    testWidgets('onbreak_showup_detail_hides_done_failed_actions', (tester) async {
      const pactId = 'test-pact-onbreak-hides-actions';
      final pact = buildPact(id: pactId, habitName: 'Meditate', startDate: DateTime(2099, 6, 1));
      const showupId = '${pactId}_20990615T080000_0';
      final showup = buildShowup(id: showupId, pactId: pactId, scheduledAt: DateTime(2099, 6, 15, 8, 0));
      final onBreak = buildBreak(
        id: 'brk-hides-actions',
        pactId: pactId,
        startDate: DateTime(2099, 6, 10),
        plannedEndDate: DateTime(2099, 6, 20),
        rationale: 'Sick',
      );

      final testNow = DateTime(2099, 6, 15, 8, 30);

      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(testNow),
          pactListNowProvider.overrideWithValue(testNow),
          showupDetailNowProvider.overrideWithValue(testNow),
          _breaksEnabled,
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
          await h.showupRepo.saveShowups([showup]);
          await h.pactBreakRepo.saveBreak(onBreak);
        },
      );

      // ── 1. Open the on-break showup's detail from the dashboard ──────────
      await waitFor(tester, find.text('Meditate'));
      await tester.tap(find.text('Meditate').first);
      final strings = l10n(tester);
      await waitFor(tester, find.text(strings.showupOnBreak));

      // ── 2. Mark Done / Mark Failed must not be shown at all ──────────────
      expect(find.text(strings.markDone), findsNothing);
      expect(find.text(strings.markFailed), findsNothing);

      // ── 3. Regression guard: buttons are hidden, not because the showup
      //         got auto-resolved behind the scenes. ───────────────────────
      final persisted = await h.showupRepo.getShowupById(showupId);
      expect(persisted?.status, ShowupStatus.pending);
    });

    testWidgets('break_window_suppresses_reminders_and_resumes_after_end', (tester) async {
      const pactId = 'test-pact-reminder-suppression';
      // Pact starts "today" — no historical gap to fill, so nothing but the
      // forward-generated 6/15..6/25 showups exist (avoids unrelated
      // auto-fail-cancel noise from gap-filled past days).
      final pact = buildPact(
        id: pactId,
        habitName: 'Jog',
        startDate: DateTime(2099, 6, 15),
        reminderOffset: const Duration(minutes: 15),
      );

      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(DateTime(2099, 6, 15, 7, 0)),
          pactListNowProvider.overrideWithValue(DateTime(2099, 6, 15, 7, 0)),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
        },
      );

      // ── 1. Dashboard load generates showups forward and schedules reminders ──
      await waitFor(tester, find.text('Jog'));
      expect(h.notifications.scheduledReminders, isNotEmpty,
          reason: 'Dashboard load must schedule reminders for the forward-generated showups');

      final allShowups = await h.showupRepo.getShowupsForPact(pactId);

      // The break-creation flow (WU4.1) hasn't landed yet — drive PactBreakService
      // directly, the same way its own already-shipped unit tests do.
      final container = ProviderScope.containerOf(tester.element(find.byType(Navigator).first));
      final breakService = container.read(pactBreakServiceProvider);

      // ── 2. Start a break covering only the 6/16 and 6/17 showups ─────────
      final PactBreak onBreak = await breakService.startBreak(
        id: 'brk-1',
        pactId: pactId,
        startDate: DateTime(2099, 6, 16),
        plannedEndDate: DateTime(2099, 6, 18),
        rationale: 'Sick',
        now: DateTime(2099, 6, 15, 7, 0),
      );

      final inWindow = allShowups.where((s) => onBreak.contains(s.scheduledAt)).toList();
      final outOfWindow = allShowups.where((s) => !onBreak.contains(s.scheduledAt)).toList();
      expect(inWindow, isNotEmpty);
      expect(outOfWindow, isNotEmpty);

      // ── 3. Reminders for in-window showups were cancelled ────────────────
      for (final s in inWindow) {
        expect(h.notifications.cancelledShowupIds, contains(s.id),
            reason: 'Showup ${s.id} falls inside the break window and must have its reminder cancelled');
      }

      // ── 4. A showup scheduled after the break's end date is untouched ────
      for (final s in outOfWindow) {
        expect(h.notifications.cancelledShowupIds, isNot(contains(s.id)),
            reason: 'Showup ${s.id} falls outside the break window and must keep its reminder');
      }

      // ── 5. Resume the pact mid-break (before the planned end elapses) ────
      // The 6/16 showup is already before this instant — it stays on break
      // permanently, per spec. The 6/17 showup is released.
      h.notifications.reset();
      final stopNow = DateTime(2099, 6, 16, 20, 0);
      final stopped = await breakService.stopBreak(onBreak.id, now: stopNow);

      final released = inWindow.where((s) => !stopped.contains(s.scheduledAt)).toList();
      final stillOnBreak = inWindow.where((s) => stopped.contains(s.scheduledAt)).toList();
      expect(released, isNotEmpty);
      expect(stillOnBreak, isNotEmpty);

      // ── 6. The released showups get a fresh scheduleShowupReminder call ──
      // (not just something downstream implying it — the call itself re-fires).
      final rescheduledIds = h.notifications.scheduledReminders.map((r) => r.showup.id).toSet();
      for (final s in released) {
        expect(rescheduledIds, contains(s.id),
            reason: 'Resuming the pact must re-invoke scheduleShowupReminder for the released showup ${s.id}');
      }
      for (final s in stillOnBreak) {
        expect(rescheduledIds, isNot(contains(s.id)),
            reason: 'Showup ${s.id} is still on break after the resume and must not get a reminder yet');
      }

      // Step 4 above already confirms the out-of-window showups' reminders
      // were never cancelled by the break in the first place. A genuinely
      // *new* showup entering the generation window still getting a normal
      // reminder is the standard forward-generation path — already covered
      // by dashboard_view_model_test.dart's "notification scheduling on
      // dashboard load" unit tests, and not re-derived here since it would
      // require advancing todayProvider mid-test to force new generation.
    });
  });

  group('Break stats and streak', () {
    // TODO: declare `late AppHarness h;` and `tearDown(() => h.dispose());` when filling in stubs.

    testWidgets('onbreak_showup_does_not_affect_streak_and_increments_skipped_stat', (tester) async {
      // TODO: 1. Seed a pact with an established streak of consecutive done showups.
      // TODO: 2. Start a break covering the next scheduled showup.
      // TODO: 3. Open Pact Detail — verify the current streak stat is unchanged
      //          (neither broken nor advanced).
      // TODO: 4. Verify the "Skipped on break" stat shows the on-break showup counted.
    });
  });

  group('Resume pact (stop break)', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('resume_pact_stops_break_future_resumes_past_stays_onbreak', (tester) async {
      const pactId = 'test-pact-resume';
      final pact = buildPact(
        id: pactId,
        habitName: 'Swim',
        startDate: DateTime(2099, 6, 1),
        reminderOffset: const Duration(minutes: 15),
      );
      // Break window [6/10, 6/20] straddles testNow (6/16) — the 6/12 showup
      // is already "in the past" relative to now, the 6/18 one is ahead of it.
      final onBreak = buildBreak(
        id: 'brk-1',
        pactId: pactId,
        startDate: DateTime(2099, 6, 10),
        plannedEndDate: DateTime(2099, 6, 20),
        rationale: 'Recovering',
      );
      final testNow = DateTime(2099, 6, 16, 9, 0);
      final pastShowupAt = DateTime(2099, 6, 12, 8, 0);
      final futureShowupAt = DateTime(2099, 6, 18, 8, 0);

      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(testNow),
          pactListNowProvider.overrideWithValue(testNow),
          pactDetailNowProvider.overrideWithValue(testNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
          await h.pactBreakRepo.saveBreak(onBreak);
        },
      );

      // ── 1. Dashboard load generates the schedule (past gap-fill + forward
      //         generation), skipping reminders for the in-window showups ────
      await waitFor(tester, find.text('Swim'));
      final allShowups = await h.showupRepo.getShowupsForPact(pactId);
      final pastShowup = allShowups.firstWhere((s) => s.scheduledAt == pastShowupAt);
      final futureShowup = allShowups.firstWhere((s) => s.scheduledAt == futureShowupAt);

      // ── 2. Open Pact Detail — the "In a break" banner is shown ───────────
      // The Break chip defaults to selected (HAB-212), so the on-break
      // pact's tile already renders in the panel — no chip interaction
      // needed before tapping it by habit name.
      await openPactsPanel(tester);
      await openPactDetail(tester, 'Swim');
      await waitFor(tester, find.byKey(const Key('pact-detail-break-banner')));

      // ── 3. Tap "Resume pact" and confirm ──────────────────────────────────
      h.notifications.reset();
      await tester.ensureVisible(find.byKey(const Key('pact-detail-resume-pact-button')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('pact-detail-resume-pact-button')));
      await tester.pumpAndSettle();

      final strings = l10n(tester);
      await tester.tap(find.text(strings.resumePactConfirm));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 100));

      // ── 4. The banner disappears — the pact returns to normal display ────
      expect(find.byKey(const Key('pact-detail-break-banner')), findsNothing);

      final stopped = (await h.pactBreakRepo.getBreaksForPact(pactId)).first;
      expect(stopped.stoppedAt, isNotNull);

      // ── 5. The earlier showup (already inside the window before the
      //         resume) stays on break permanently; the later one is released ──
      expect(stopped.contains(pastShowup.scheduledAt), isTrue,
          reason: 'Showups already inside the window before the resume stay on break permanently');
      expect(stopped.contains(futureShowup.scheduledAt), isFalse,
          reason: 'The window is clamped at the resume instant, releasing later showups');

      // ── 6. The released showup gets a fresh scheduleShowupReminder call ──
      final rescheduledIds = h.notifications.scheduledReminders.map((r) => r.showup.id).toSet();
      expect(rescheduledIds, contains(futureShowup.id),
          reason: 'Resuming the pact must re-invoke scheduleShowupReminder for the released showup');
      expect(rescheduledIds, isNot(contains(pastShowup.id)),
          reason: 'The still-on-break showup must not get a reminder yet');

      // Whether the released showup then auto-fails once its own window
      // elapses is the pre-existing (pre-HAB-195) auto-fail sweep, already
      // covered by dashboard_view_model_test.dart — not re-derived here since
      // it would require advancing todayProvider mid-test to force a new
      // sweep pass (same scoping decision as the reminder-suppression
      // scenario above).
    });
  });

  group('Pact list Break filter', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('pact_list_break_chip_filters_to_onbreak_pacts', (tester) async {
      // Both active pacts start after testNow (below) so the dashboard's
      // "today" todo list — which also renders habitName text — has nothing
      // to generate yet; otherwise a due-today showup would make the habit
      // name ambiguous between the todo list and the pacts panel tile.
      final onBreakPact = buildPact(
        id: 'test-pact-list-onbreak',
        habitName: 'Swim',
        startDate: DateTime(2099, 7, 1),
      );
      final plainPact = buildPact(
        id: 'test-pact-list-plain',
        habitName: 'Yoga',
        startDate: DateTime(2099, 7, 1),
      );
      final stoppedPact = buildPact(
        id: 'test-pact-list-stopped',
        habitName: 'Cycling',
        startDate: DateTime(2099, 1, 1),
        status: PactStatus.stopped,
        stoppedAt: DateTime(2099, 3, 1),
      );
      final onBreak = buildBreak(
        id: 'brk-list-1',
        pactId: onBreakPact.id,
        startDate: DateTime(2099, 6, 10),
        plannedEndDate: DateTime(2099, 6, 20),
        rationale: 'Recovering',
      );
      final testNow = DateTime(2099, 6, 16, 9, 0);

      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(testNow),
          pactListNowProvider.overrideWithValue(testNow),
          _breaksEnabled,
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(onBreakPact);
          await h.pactRepo.savePact(plainPact);
          await h.pactRepo.savePact(stoppedPact);
          await h.pactBreakRepo.saveBreak(onBreak);
        },
      );

      // ── 0. Break now defaults to selected (HAB-212) — deselect it first so
      //         the rest of this scenario still starts from the "Active
      //         selected, Break not selected" corner of the truth table it's
      //         actually testing ────────────────────────────────────────────
      await openPactsPanel(tester);
      const panelScrollable = Key('pacts-panel-scrollable');
      await tester.dragUntilVisible(
        find.byKey(const Key('break-filter-chip')),
        find.byKey(panelScrollable),
        const Offset(0, -100),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('break-filter-chip')));
      await tester.pump(const Duration(milliseconds: 300));

      // ── 1. Active/Done/Stopped selected, Break deselected — the on-break
      //         pact (Swim) is hidden even though its underlying status is
      //         Active; Break exclusively governs on-break pacts'
      //         visibility, so Active alone never surfaces them ───────────
      // Yoga and Cycling may both be unrealized on a short viewport (CI's
      // Android emulator) — anchor on the panel's own scrollable rather than
      // Yoga's own text, which may not exist yet (HAB-211, same root cause
      // as HAB-196 Fix 4 / HAB-199).
      await tester.dragUntilVisible(find.text('Yoga'), find.byKey(panelScrollable), const Offset(0, -100));
      await tester.dragUntilVisible(find.text('Cycling'), find.byKey(panelScrollable), const Offset(0, -100));
      expect(find.text('Cycling'), findsOneWidget);
      expect(find.text('Swim'), findsNothing);

      // ── 2. Select the "Break" chip on top of the already-selected Active
      //         — the on-break pact now joins the plain active one; Cycling
      //         (stopped) is unaffected, its own chip untouched. ─────────
      final strings = l10n(tester);
      // Step 1 scrolled down to reveal Cycling — the filter-chip row is
      // part of the same CustomScrollView, above the list items, so it
      // scrolled out of view along with the title. Scroll back up (positive
      // offset) before tapping it (HAB-211 — a real CI-only miss: the chip
      // being out of view didn't reproduce on the local emulator's taller
      // viewport).
      await tester.dragUntilVisible(
        find.byKey(const Key('break-filter-chip')),
        find.byKey(panelScrollable),
        const Offset(0, 100),
      );
      // dragUntilVisible's own found-check only confirms the element exists
      // in the tree — a lazy list's cache extent can pre-build an item
      // that isn't actually painted at a stable on-screen position yet, so
      // an immediate tap's hit-test can still miss (CI-only: real device
      // cache-extent/paint timing differs from the local emulator) —
      // settle first (HAB-211).
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('break-filter-chip')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Swim'), findsOneWidget);
      expect(find.text('Yoga'), findsOneWidget);
      // Scrolling back up to reach the chip pushed Cycling (the last item)
      // out of the lazy list's cache extent on CI's short viewport — it's
      // not just off-screen, it's unrealized. Scroll back down to it before
      // asserting, same as step 1 (HAB-211: 3 items is not "small enough to
      // always stay realized" on CI's viewport).
      await tester.dragUntilVisible(find.text('Cycling'), find.byKey(panelScrollable), const Offset(0, -100));
      expect(find.text('Cycling'), findsOneWidget);

      // ── 3. Deselect "Active" — only the on-break pact remains among the
      //         active-status pacts (Break alone now governs it); the plain
      //         active pact (Yoga) disappears; Cycling stays, still
      //         unaffected by the Active/Break axis ─────────────────────
      await tester.dragUntilVisible(
        find.widgetWithText(FilterChip, strings.filterActive),
        find.byKey(panelScrollable),
        const Offset(0, 100),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, strings.filterActive));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Swim'), findsOneWidget);
      expect(find.text('Yoga'), findsNothing);
      await tester.dragUntilVisible(find.text('Cycling'), find.byKey(panelScrollable), const Offset(0, -100));
      expect(find.text('Cycling'), findsOneWidget);
    });
  });
}
