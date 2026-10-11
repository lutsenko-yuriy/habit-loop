// Scenario stubs for GH-464: linking a Checklister checklist to a pact.
//
// Run with: flutter test integration_test/checklist_link_flow_test.dart -d <device>
// Run on host: flutter test integration_test/checklist_link_flow_test.dart
//
// Harness hooks these scenarios need (added to AppHarness when the production
// types exist, see GH-464 plan): h.checklister (FakeChecklisterGateway),
// h.incomingLinks (FakeIncomingLinkService), h.checklistLinkRepo,
// h.checklistRunRepo, simulateResume(tester).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Checklist link flow', () {
    testWidgets('select_checklist_links_checklist_to_pact: a selected callback shows the linked checklist on the pact',
        (tester) async {
      // TODO: 1. Seed an active pact with no link; Checklister installed.
      // TODO: 2. Open pact detail: Checklist section shows only "Select checklist".
      // TODO: 3. Tap it: launchedUrls has checklister://select whose callbackUrl is
      //          habitloop://checklist/selected?pactId=<id>.
      // TODO: 4. incomingLinks.emit the callback with status=selected&checklistId=c1&checklistName=Morning.
      // TODO: 5. Section shows "Morning", Change and Remove.
      // TODO: 6. Link repo holds c1/Morning for the pact.
      // TODO: 7. Analytics has pact_checklist_selection_started and pact_checklist_linked.
    });

    testWidgets(
        'selection_cancelled_or_error_leaves_pact_unlinked: cancelled changes nothing, error asks to select something',
        (tester) async {
      // TODO: 1. Seed an active pact with no link; open pact detail and tap "Select checklist".
      // TODO: 2. Emit status=cancelled: still "Select checklist", no error message, link repo empty.
      // TODO: 3. Tap "Select checklist" again and emit status=error.
      // TODO: 4. L10n error copy is shown, "Select checklist" still shown, link repo empty.
    });

    testWidgets(
        'change_replaces_link_and_remove_clears_it: Change swaps the checklist, Remove unlinks without relocking',
        (tester) async {
      // TODO: 1. Seed a pact linked to c1/Morning, plus a pending showup with a finished run (already unlocked).
      // TODO: 2. Open pact detail; tap Change; select URL launched; emit selected for c2/Evening.
      // TODO: 3. Section shows "Evening"; link repo holds c2.
      // TODO: 4. Tap Remove: no confirmation dialog.
      // TODO: 5. Section shows "Select checklist"; link repo empty; pact_checklist_unlinked fired.
      // TODO: 6. Open the unlocked showup: "Mark as done" is still shown (no relock).
    });

    testWidgets('no_checklist_section_for_inactive_pact: stopped and completed pacts have no Checklist section',
        (tester) async {
      // TODO: 1. Seed one stopped pact and one completed pact.
      // TODO: 2. Open pact detail for each.
      // TODO: 3. No Checklist section or button is present in either.
    });
  });
}
