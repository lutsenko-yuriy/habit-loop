// On-device entry point for the mark-showup-done flow test.
//
// Run with: flutter test integration_test/mark_showup_done_flow_test.dart -d <device>
// Run on host: flutter test integration_test/mark_showup_done_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

// Fixed clock: 5 minutes before the 08:00 showup window, so auto-fail
// never triggers during the test.
final _testNow = DateTime(2099, 6, 15, 7, 55);
final _testToday = DateTime(2099, 6, 15);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Mark showup done flow', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
        'mark_as_done_updates_status_and_fires_analytics: tapping Mark as Done updates status and fires analytics',
        (tester) async {
      // ── Seed: one pact + one pending showup starting today ───────────────
      const pactId = 'test-pact-1';
      final pact = buildPact(
        id: pactId,
        habitName: 'Daily Yoga',
        startDate: _testToday,
      );
      // Deterministic ID matching ShowupGenerator's output:
      // {pactId}_{yyyyMMdd}T{HHmmss}_{seq}
      const showupId = '${pactId}_20990615T080000_0';
      final showup = buildShowup(
        id: showupId,
        pactId: pactId,
        scheduledAt: DateTime(2099, 6, 15, 8, 0),
      );

      h = await AppHarness.create(
        tester,
        // Pin the clock to 07:55 on the pact's start date so:
        //  • dashboard calendar strip centres on June 15 2099
        //  • auto-fail check (now > scheduledAt + duration) is false
        //  • showup detail screen also sees the same frozen clock
        extraOverrides: [
          todayProvider.overrideWithValue(_testNow),
          showupDetailNowProvider.overrideWithValue(_testNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(pact);
          await h.showupRepo.saveShowups([showup]);
        },
      );

      // ── 1. Dashboard shows today's showup ───────────────────────────────
      await waitFor(tester, find.text('Daily Yoga'));
      expect(find.text('Daily Yoga'), findsOneWidget);

      // ── 2. Tap the showup tile ───────────────────────────────────────────
      await tester.tap(find.text('Daily Yoga'));
      // showup detail starts with isLoading = true → CircularProgressIndicator.
      // pumpAndSettle() would loop on that spinner; use waitFor() instead.
      final strings = l10n(tester);
      await waitFor(tester, find.text(strings.markDone));
      expect(find.text(strings.markDone), findsOneWidget);
      await tester.tap(find.text(strings.markDone));
      await tester.pumpAndSettle();

      // ── 4. Status chip shows "Done" ──────────────────────────────────────
      expect(find.text(strings.showupDone), findsOneWidget);

      // ── 5. showup_marked_done analytics event was fired ──────────────────
      expect(
        h.analytics.loggedEvents.any((e) => e.name == 'showup_marked_done'),
        isTrue,
      );
    });
  });
}
