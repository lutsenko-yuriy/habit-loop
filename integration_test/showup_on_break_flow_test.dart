// Integration tests for showup on-break polish (HAB-213): calendar strip
// overflow-dot color when only some of a day's showups are on break.
//
// Run on host:   flutter test integration_test/showup_on_break_flow_test.dart
// Run on device: flutter test integration_test/showup_on_break_flow_test.dart -d <device>
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Calendar strip overflow dot', () {
    // TODO: declare `late AppHarness h;` and `tearDown(() => h.dispose());` when filling in stubs.

    testWidgets('overflow_dot_not_blue_when_only_some_showups_on_break', (tester) async {
      // TODO: 1. Seed 4 pacts ("Meditate", "Jog", "Read", "Swim"), each with one
      //          showup scheduled on the same day (2099-06-15), later in the day
      //          than testNow so all resolve to the `planned` UI state before any
      //          break is applied.
      // TODO: 2. Seed an active PactBreak for the "Meditate" pact covering
      //          2099-06-15, so only that pact's showup resolves to
      //          ShowupUiState.onBreak; the other three stay `planned`.
      // TODO: 3. Boot the harness with todayProvider/pactListNowProvider pinned to
      //          a time on 2099-06-15 before the showups' scheduled time, and
      //          pact_breaks_enabled on.
      // TODO: 4. Locate the calendar strip's overflow dot for that day via
      //          find.byKey(Key('status-dot-overflow-2099-06-15')) and wait for it.
      // TODO: 5. Read the dot's Container decoration color and the current
      //          ColorScheme from the widget tree.
      // TODO: 6. Assert the dot's color equals colorScheme.onSurfaceVariant (the
      //          pending/grey fallback), and explicitly assert it does NOT equal
      //          HabitLoopColors.onBreak (blue) — proving the "only some on
      //          break" case no longer forces blue.
    });
  });
}
