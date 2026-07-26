// Integration tests for pact breaks (HAB-195): pausing a pact without
// failing showups.
//
// Run on host:   flutter test integration_test/break_flow_test.dart
// Run on device: flutter test integration_test/break_flow_test.dart -d <device>
import 'package:flutter/material.dart' show Navigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_break.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Start break flow', () {
    // TODO: declare `late AppHarness h;` and `tearDown(() => h.dispose());` when filling in stubs.

    testWidgets('start_break_fixed_end_marks_inwindow_showups_onbreak', (tester) async {
      // TODO: 1. Seed an active pact with daily showups spanning several future days.
      // TODO: 2. Open Pact Detail for the pact.
      // TODO: 3. Tap the break entry point; pick start date = today, end date = a fixed
      //          future date, and enter a rationale.
      // TODO: 4. Submit the break.
      // TODO: 5. Verify the banner reads "In a break until <date>" with the rationale shown.
      // TODO: 6. Verify showups scheduled inside the window render as "on break" (blue,
      //          pause glyph) on the dashboard/calendar strip and in showup detail.
      // TODO: 7. Verify a showup scheduled after the window is unaffected (normal pending
      //          state).
    });

    testWidgets('start_break_until_pact_ends_marks_future_showups_onbreak', (tester) async {
      // TODO: 1. Seed an active pact.
      // TODO: 2. Open the break flow from Pact Detail; pick start date = today, select
      //          "until pact ends", enter a rationale, submit.
      // TODO: 3. Verify the banner reads "In a break" with no end date shown.
      // TODO: 4. Verify a showup scheduled far in the future is marked "on break".
    });

    testWidgets('start_break_requires_rationale', (tester) async {
      // TODO: 1. Seed an active pact, open the break flow, pick valid start/end dates.
      // TODO: 2. Leave rationale empty and attempt to submit.
      // TODO: 3. Verify submission is blocked (disabled action / validation message) and
      //          no break is persisted.
      // TODO: 4. Enter rationale text.
      // TODO: 5. Verify submit becomes available and the break is created successfully.
    });

    testWidgets('start_break_from_tailzone_showup_defaults_to_today', (tester) async {
      // TODO: 1. Seed a pact with an unresolved/auto-failed showup dated a few days in
      //          the past (inside the tail-zone period).
      // TODO: 2. Open that showup's detail screen; verify the break entry-point button
      //          is present.
      // TODO: 3. Tap it — verify the break flow opens with start date defaulted to today
      //          (not the showup's past date).
      // TODO: 4. Pick a future end date, enter a rationale, submit.
      // TODO: 5. Verify the triggering (past) showup's status is unchanged.
      // TODO: 6. Verify a different, later showup that does fall inside the new window
      //          is marked "on break".
    });

    testWidgets('start_break_blocked_while_break_active', (tester) async {
      // TODO: 1. Seed a pact with an already-active break (seeded directly via the
      //          break repository).
      // TODO: 2. Open Pact Detail.
      // TODO: 3. Verify the "start a new break" entry point is unavailable
      //          (hidden/disabled) — only "Resume pact" is offered.
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
      // Note: the "on break" visual marking (blue/pause glyph) lands in WU5.1
      // — this asserts the underlying auto-fail suppression only.
      await tester.tap(find.text('Meditate').first);
      final strings = l10n(tester);
      await waitFor(tester, find.text(strings.showupPending));
      expect(find.text(strings.showupPending), findsOneWidget,
          reason: 'On-break showup must display as Pending (not Failed) on a late open');

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
    // TODO: declare `late AppHarness h;` and `tearDown(() => h.dispose());` when filling in stubs.

    testWidgets('resume_pact_stops_break_future_resumes_past_stays_onbreak', (tester) async {
      // TODO: 1. Seed a pact with an active break whose window already covers one
      //          past-relative showup and extends into the future.
      // TODO: 2. Open Pact Detail; tap "Resume pact" in the banner and confirm.
      // TODO: 3. Verify the banner disappears and the pact returns to normal display.
      // TODO: 4. Verify the earlier showup (already inside the window before
      //          cancellation) still shows "on break".
      // TODO: 5. Before advancing the clock, verify h.notifications.scheduledReminders
      //          now contains a fresh scheduleShowupReminder call for that later
      //          showup — confirming the reminder-scheduling sweep actually restored
      //          it, not just that auto-fail resumes later.
      // TODO: 6. Advance the clock past that showup's window — verify it now
      //          auto-fails normally, since scheduling has resumed.
    });
  });

  group('Pact list Break filter', () {
    // TODO: declare `late AppHarness h;` and `tearDown(() => h.dispose());` when filling in stubs.

    testWidgets('pact_list_break_chip_filters_to_onbreak_pacts', (tester) async {
      // TODO: 1. Seed three pacts: one active pact with an active break, one plain
      //          active pact (no break), one stopped pact.
      // TODO: 2. Open the pacts panel/list.
      // TODO: 3. Tap the "Break" chip — verify only the on-break pact is listed.
      // TODO: 4. Tap the "Active" chip — verify both active pacts (on-break + plain)
      //          are listed, confirming Break is a subset, not a separate status.
    });
  });
}
