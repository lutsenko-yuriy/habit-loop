// Scenario stubs for GH-464: running a linked Checklister checklist before marking a showup done.
//
// Run with: flutter test integration_test/checklist_run_flow_test.dart -d <device>
// Run on host: flutter test integration_test/checklist_run_flow_test.dart
//
// Harness hooks these scenarios need (added to AppHarness when the production
// types exist, see GH-464 plan): h.checklister (FakeChecklisterGateway),
// h.incomingLinks (FakeIncomingLinkService, initialLink + emit), h.checklistLinkRepo,
// h.checklistRunRepo, simulateResume(tester).
// Run callbacks always carry both ids: habitloop://checklist/run-finished?pactId=<id>&showupId=<id>.
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Checklist run flow', () {
    testWidgets(
        'linked_pact_gates_mark_done_behind_run_checklist: linked pact shows Run checklist instead of Mark as done',
        (tester) async {
      // TODO: 1. Seed a pact linked to c1 and a pending showup inside its window; open showup detail.
      // TODO: 2. "Run checklist" and "Mark as failed" shown; "Mark as done" absent.
      // TODO: 3. Tap Run checklist: launchedUrls has checklister://run?checklistId=c1 and its callbackUrl is
      //          habitloop://checklist/run-finished?pactId=<id>&showupId=<id> (assert both ids).
      // TODO: 4. Run repo has an unfinished record; checklist_run_started fired; no callback sent.
      // TODO: 5. Screen still shows "Run checklist", no "Mark as done".
    });

    testWidgets(
        'completed_run_unlocks_mark_done_and_persists: completed callback unlocks Mark as done and survives reopen',
        (tester) async {
      // TODO: 1. Seed as in the gate scenario; tap Run checklist.
      // TODO: 2. Emit run-finished?pactId=<id>&showupId=<id>&status=completed&checklistId=c1&runId=r1.
      // TODO: 3. Showup detail shows "Mark as done", no failure dialog; checklist_run_finished fired.
      // TODO: 4. Navigate back, reopen the showup: "Mark as done" still shown.
      // TODO: 5. Tap Mark as done.
      // TODO: 6. Showup is done; showup_marked_done carries checklist_outcome=success.
    });

    testWidgets('unsuccessful_run_shows_dialog_and_unlocks: cancelled and error both show the dialog and unlock',
        (tester) async {
      // TODO: 1. Seed as in the gate scenario; tap Run checklist.
      // TODO: 2. Emit run-finished?pactId=<id>&showupId=<id>&status=cancelled: unsuccessful-run dialog shown.
      // TODO: 3. Tap OK: "Mark as done" shown.
      // TODO: 4. Reopen the showup: still unlocked, dialog not shown again.
      // TODO: 5. Repeat with a second showup using status=error: dialog shown and unlocked.
      // TODO: 6. Mark one done: showup_marked_done carries checklist_outcome=failure.
    });

    testWidgets('late_finish_within_grace_prevents_auto_fail: run finished within 15 minutes after the window closes',
        (tester) async {
      // TODO: 1. Seed a linked pact and a showup at 08:00 with a 10-minute duration.
      // TODO: 2. Use a mutable showupDetailNowProvider clock at 08:05; open the showup and tap Run checklist.
      // TODO: 3. Advance the clock to 08:20 (window closed 08:10, inside the 15-minute grace).
      // TODO: 4. Emit run-finished?pactId=<id>&showupId=<id>&status=completed&checklistId=c1&runId=r1.
      // TODO: 5. Showup is still pending (not auto-failed); "Mark as done" shown.
      // TODO: 6. Tap Mark as done: showup marked done.
      // TODO: 7. Variant: clock at 08:30 with a started run; reopening the showup auto-fails it (past grace).
    });

    testWidgets('redeeming_auto_failed_showup_ignores_checklist_gate: redemption needs only the note', (tester) async {
      // TODO: 1. Seed a linked pact and an already auto-failed showup.
      // TODO: 2. Open showup detail and start redemption.
      // TODO: 3. No Run checklist button; note field present.
      // TODO: 4. Enter a note and submit.
      // TODO: 5. Showup is redeemed; run repo still empty.
    });

    testWidgets('checklister_install_state_switches_gate_on_resume: install state change on resume toggles the gate',
        (tester) async {
      // TODO: 1. Seed a pact with an existing link and a pending showup; fake installed = false.
      // TODO: 2. Pact detail: no Checklist section.
      // TODO: 3. Showup detail: "Mark as done" shown, "Run checklist" not.
      // TODO: 4. Set installed = true and simulateResume.
      // TODO: 5. Pact detail shows the Checklist section with the linked name; showup detail shows
      //          "Run checklist" and no "Mark as done".
      // TODO: 6. Set installed = false and simulateResume.
      // TODO: 7. Plain "Mark as done" is back; the link is still in the repo.
    });

    testWidgets('cold_start_callback_opens_showup_detail: initial link opens the showup detail screen', (tester) async {
      // TODO: 1. Seed a linked pact, a pending showup and an unfinished run record.
      // TODO: 2. Create the harness with incomingLinks.initialLink =
      //          habitloop://checklist/run-finished?pactId=<id>&showupId=<id>&status=completed&checklistId=c1&runId=r1.
      // TODO: 3. Pump to the first frame.
      // TODO: 4. Showup detail for that showup is on top of the dashboard.
      // TODO: 5. "Mark as done" shown; run marked finished in the repo; back returns to the dashboard.
    });
  });
}
