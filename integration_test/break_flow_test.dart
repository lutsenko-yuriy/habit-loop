// Integration tests for pact breaks (HAB-195): pausing a pact without
// failing showups.
//
// Run on host:   flutter test integration_test/break_flow_test.dart
// Run on device: flutter test integration_test/break_flow_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
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
    // TODO: declare `late AppHarness h;` and `tearDown(() => h.dispose());` when filling in stubs.

    testWidgets('onbreak_showup_not_autofailed_by_sweep_or_late_open', (tester) async {
      // TODO: 1. Seed a pact with an active break covering today's showup.
      // TODO: 2. Set the clock past the showup's window end (would normally trigger
      //          auto-fail).
      // TODO: 3. Load the dashboard — verify the showup stays "on break", not failed.
      // TODO: 4. Open that showup's detail screen directly — verify no auto-fail
      //          transition occurs and it displays as "on break".
    });

    testWidgets('break_window_suppresses_reminders_and_resumes_after_end', (tester) async {
      // TODO: 1. Seed a pact with several future showups and their reminders already
      //          scheduled.
      // TODO: 2. Start a break with a fixed end date covering only some of those
      //          showups.
      // TODO: 3. Verify reminders for in-window showups were cancelled
      //          (h.notifications).
      // TODO: 4. Verify the reminder for a showup scheduled after the break's end date
      //          remains scheduled (untouched).
      // TODO: 5. Cancel ("Resume pact") the break or advance the clock past its end.
      // TODO: 6. Verify h.notifications.scheduledReminders now contains a fresh
      //          scheduleShowupReminder call for the showup(s) that were suppressed
      //          in step 3 — confirming the restore actually re-invoked the
      //          scheduling method, not just that something downstream implies it.
      // TODO: 7. Verify a new showup scheduled after that point also gets its
      //          reminder scheduled normally.
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
