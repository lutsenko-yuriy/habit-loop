// Integration tests for pact chaining (HAB-202): creating a new pact from a
// finished one via "Adjust and start again", with Previous/Next navigation
// links between predecessor and successor.
//
// Run on host:   flutter test integration_test/pact_chain_test.dart
// Run on device: flutter test integration_test/pact_chain_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Pact chain — adjust and start again', () {
    // TODO: declare `late AppHarness h;` and `tearDown(() => h.dispose());` when filling in stubs.

    testWidgets('adjust_and_start_again_creates_chained_pact_with_prefill_and_backlink', (tester) async {
      // TODO: 1. Seed a stopped pact "Vibe coding" with a known schedule, showup
      //          duration, and reminder offset.
      // TODO: 2. Open its pact detail screen; scroll to the bottom action area;
      //          verify "Adjust and start again" is visible.
      // TODO: 3. Tap it — wizard opens.
      // TODO: 4. Verify the habit-name field is pre-filled with "Vibe coding (v2)".
      // TODO: 5. Swipe through the wizard to the summary step and confirm creation
      //          (handle the commitment dialog if shown).
      // TODO: 6. Wait for the pact-created signal, then verify in the repository:
      //          new pact's habitName is "Vibe coding (v2)", predecessorPactId
      //          equals the original pact's id, schedule/showupDuration/
      //          reminderOffset match the predecessor, and startDate is today
      //          (not carried over from the predecessor).
      // TODO: 7. Navigate to the new pact's detail screen; verify
      //          "Previous Pact: 'Vibe coding'" link appears under the habit
      //          name/status badge.
      // TODO: 8. Tap the link — navigates to the predecessor's detail screen.
      // TODO: 9. On the predecessor's detail screen, verify "Adjust and start
      //          again" is gone, replaced by "Next Pact: 'Vibe coding (v2)'" in
      //          the bottom action area.
      // TODO: 10. Tap that link — navigates back to the successor's detail screen.
    });
  });

  group('Pact chain — navigation stack', () {
    // TODO: declare `late AppHarness h;` and `tearDown(() => h.dispose());` when filling in stubs.
    // Both scenarios below use P_p (predecessor / "parent") and P_c (successor
    // / "child"): P_c.predecessorPactId == P_p.id. They verify that bouncing
    // between "Previous Pact"/"Next Pact" links pops back to the existing page
    // instance instead of pushing a duplicate — so the back stack never grows
    // past however deep the user has actually gone in one direction.

    testWidgets('chain_navigation_previous_then_next_returns_to_same_page_instance', (tester) async {
      // TODO: 1. Seed predecessor/parent pact P_p (stopped, "Vibe coding") and
      //          successor/child pact P_c ("Vibe coding (v2)",
      //          predecessorPactId=P_p.id), saved directly via the repo.
      // TODO: 2. Open Pacts List; tap P_c.
      // TODO: 3. Verify P_c's detail screen is shown.
      // TODO: 4. Tap "Previous Pact" — verify P_p's detail screen is shown
      //          (pushed on top of P_c).
      // TODO: 5. Tap "Next Pact" — verify P_c's detail screen is shown again.
      // TODO: 6. tester.pageBack() once — verify Pacts List is shown directly
      //          (proves step 5 popped back to the original P_c page instance
      //          rather than pushing a second copy of it).
    });

    testWidgets('chain_navigation_next_then_previous_returns_to_same_page_instance', (tester) async {
      // TODO: 1. Seed the same P_p (predecessor/parent) / P_c (successor/child)
      //          pair as above, saved directly via the repo.
      // TODO: 2. Open Pacts List; tap P_p.
      // TODO: 3. Verify P_p's detail screen is shown.
      // TODO: 4. Tap "Next Pact" — verify P_c's detail screen is shown (pushed
      //          on top of P_p).
      // TODO: 5. Tap "Previous Pact" — verify P_p's detail screen is shown
      //          again.
      // TODO: 6. tester.pageBack() once — verify Pacts List is shown directly
      //          (proves step 5 popped back to the original P_p page instance
      //          rather than pushing a second copy of it).
    });
  });

  group('Pact chain — default naming', () {
    // TODO: declare `late AppHarness h;` and `tearDown(() => h.dispose());` when filling in stubs.

    testWidgets('chained_default_name_uses_root_habit_name_not_immediate_predecessor', (tester) async {
      // TODO: 1. Seed a chain: root pact "Vibe coding" (id A, stopped), successor
      //          pact renamed to "Focus Sessions" (id B, stopped,
      //          predecessorPactId=A).
      // TODO: 2. Open pact detail for "Focus Sessions".
      // TODO: 3. Tap "Adjust and start again".
      // TODO: 4. Verify the habit-name field is pre-filled with "Vibe coding (v3)"
      //          (derived from the root's name, not "Focus Sessions").
      // TODO: 5. Swipe to summary and confirm creation.
      // TODO: 6. Verify in the repository: new pact's habitName is
      //          "Vibe coding (v3)", predecessorPactId equals B's id.
    });
  });

  group('Pact chain — completed pact eligibility', () {
    // TODO: declare `late AppHarness h;` and `tearDown(() => h.dispose());` when filling in stubs.

    testWidgets('adjust_and_start_again_available_from_completed_pact', (tester) async {
      // TODO: 1. Seed a completed pact "Morning Run".
      // TODO: 2. Open its pact detail screen; scroll to the bottom action area.
      // TODO: 3. Verify "Adjust and start again" is visible.
    });
  });

  group('Pact chain — feature flag', () {
    // TODO: declare `late AppHarness h;` and `tearDown(() => h.dispose());` when filling in stubs.

    testWidgets('flag_off_hides_adjust_button_and_chain_links', (tester) async {
      // TODO: 1. Seed a chain: predecessor "Old Habit" (stopped, id A) and
      //          successor "New Habit" (predecessorPactId=A) saved directly via
      //          the repo.
      // TODO: 2. Override remote config with pact_chaining_enabled: false.
      // TODO: 3. Open predecessor's detail screen — verify "Adjust and start
      //          again" is absent and "Next Pact" link is absent.
      // TODO: 4. Navigate back; open successor's detail screen — verify
      //          "Previous Pact" link is absent.
    });
  });

  group('Pact chain — cancelled wizard', () {
    // TODO: declare `late AppHarness h;` and `tearDown(() => h.dispose());` when filling in stubs.

    testWidgets('abandoning_adjust_wizard_leaves_predecessor_unchanged', (tester) async {
      // TODO: 1. Seed a stopped pact "Evening Walk".
      // TODO: 2. Open its pact detail screen; tap "Adjust and start again" —
      //          wizard opens pre-filled.
      // TODO: 3. Back out of the wizard without confirming (system/back-button
      //          pop).
      // TODO: 4. Verify navigation returns to the predecessor's pact detail
      //          screen.
      // TODO: 5. Verify the repository still contains only the original pact (no
      //          new pact, no predecessorPactId link created).
      // TODO: 6. Verify "Adjust and start again" is still visible on the
      //          predecessor's detail screen.
    });
  });
}
