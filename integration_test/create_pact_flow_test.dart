// On-device entry point for the create-pact flow test.
//
// Run with: flutter test integration_test/create_pact_flow_test.dart -d <device>
// Run on host: flutter test integration_test/create_pact_flow_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Create pact flow (Android)', () {
    late AppHarness h;

    setUp(() async {});
    tearDown(() => h.dispose());

    testWidgets('full wizard creates a pact and showup appears on dashboard', (tester) async {
      h = await AppHarness.create(tester);
      final strings = l10n(tester);

      // ── 1. Dashboard is empty ────────────────────────────────────────────
      expect(find.text(strings.noPactsYet), findsOneWidget);
      expect(find.text(strings.createPact), findsOneWidget);

      // ── 2. Open pact creation wizard ────────────────────────────────────
      await tester.tap(find.text(strings.createPact));
      await waitFor(tester, find.text(strings.pactCreationTitle));
      expect(find.text(strings.pactCreationTitle), findsOneWidget);

      // ── 3. Enter habit name ──────────────────────────────────────────────
      await tester.enterText(
        find.byWidgetPredicate((w) => w is TextField),
        'Meditate',
      );
      await tester.pump();

      // ── 4. Step 0 – pact duration: defaults are valid, tap Next ─────────
      await tester.tap(find.text(strings.next));
      await tester.pumpAndSettle();

      // ── 5. Step 1 – showup duration: auto-set to 10 min, tap Next ───────
      await tester.tap(find.text(strings.next));
      await tester.pumpAndSettle();

      // ── 6. Step 2 – schedule: select "Every day" ────────────────────────
      await tester.tap(find.text(strings.scheduleDaily));
      await tester.pump();
      await tester.tap(find.text(strings.next));
      await tester.pumpAndSettle();

      // ── 7. Step 3 – reminder: optional, skip ────────────────────────────
      await tester.tap(find.text(strings.next));
      await tester.pumpAndSettle();

      // ── 8. Step 4 – commitment: tick checkbox ───────────────────────────
      // The CheckboxListTile is below the fold in the commitment step's
      // ListView. Multiple Scrollable widgets exist in the tree (the dashboard
      // route stays mounted behind the wizard), so target the last one which
      // belongs to the current commitment-step ListView.
      await tester.scrollUntilVisible(
        find.byType(CheckboxListTile),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text(strings.createPactConfirm));
      // Do not pumpAndSettle here: after submit the wizard pops and the
      // dashboard reloads (isLoading = true → CircularProgressIndicator), which
      // blocks pumpAndSettle indefinitely. Let waitFor() below drive the pumps
      // until the new pact name appears on the dashboard.

      // ── 9. Dashboard shows pact name and today's showup ─────────────────
      await waitFor(tester, find.text('Meditate'));
      // At least one showup tile is present for the current day.
      expect(find.text('Meditate'), findsWidgets);

      // ── 10. pact_created analytics event was fired ───────────────────────
      expect(
        h.analytics.loggedEvents.any((e) => e.name == 'pact_created'),
        isTrue,
      );
    });
  });
}
