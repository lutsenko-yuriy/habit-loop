// Integration test: stopping a pact via the pact detail screen.
//
// Run on host:   flutter test integration_test/stop_pact_flow_test.dart
// Run on device: flutter test integration_test/stop_pact_flow_test.dart -d <device>
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

// Fixed clock: 5 minutes before the showup window so auto-fail never triggers.
final _testNow = DateTime(2099, 6, 15, 7, 55);
final _testToday = DateTime(2099, 6, 15);

const _pactId = 'stop-pact-flow-test-1';
const _showupId = '${_pactId}_20990615T080000_0';

final _pact = buildPact(
  id: _pactId,
  habitName: 'Evening Walk',
  startDate: _testToday,
  showupDuration: const Duration(minutes: 30),
);

final _showup = buildShowup(
  id: _showupId,
  pactId: _pactId,
  scheduledAt: DateTime(2099, 6, 15, 8, 0),
  duration: const Duration(minutes: 30),
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Stop pact flow', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets('stopping a pact from pact detail marks it stopped and cancels notifications', (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [
          todayProvider.overrideWithValue(_testNow),
          showupDetailNowProvider.overrideWithValue(_testNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(_pact);
          await h.showupRepo.saveShowups([_showup]);
        },
      );

      final strings = l10n(tester);

      // ── 1. Dashboard shows today's showup tile ────────────────────────
      await waitFor(tester, find.text('Evening Walk'));

      // ── 2. Tap showup tile → showup detail ───────────────────────────
      await tester.tap(find.text('Evening Walk'));
      await waitFor(tester, find.text(strings.markDone));

      // ── 3. Navigate to pact detail ────────────────────────────────────
      await tester.tap(find.text(strings.showupViewPactDetails));
      // sectionStats is near the top of _PactDetailContent and only rendered
      // after the VM finishes loading — reliable on any screen size.
      await waitFor(tester, find.text(strings.sectionStats.toUpperCase()));
      // Stop Pact is at the bottom of the ListView; scroll to build + reveal it.
      await tester.scrollUntilVisible(
        find.text(strings.stopPact),
        200.0,
        scrollable: find.ancestor(
          of: find.text(strings.sectionStats.toUpperCase()),
          matching: find.byType(Scrollable),
        ),
      );

      // ── 4. Tap Stop Pact → dialog appears ────────────────────────────
      await tester.tap(find.text(strings.stopPact));
      await tester.pumpAndSettle();

      expect(find.text(strings.stopPactTitle), findsOneWidget);

      // ── 5. Confirm stop ───────────────────────────────────────────────
      await tester.tap(find.text(strings.stopPactConfirm));
      await tester.pumpAndSettle();

      // ── 6. Pact is marked stopped in the repository ───────────────────
      final allPacts = await h.pactRepo.getAllPacts();
      final stoppedPact = allPacts.firstWhere((p) => p.id == _pactId);
      expect(stoppedPact.status, PactStatus.stopped);

      // ── 7. Notification cancellation was requested for the pact ───────
      // Verifies the HAB-100 fix: cancelAllRemindersForPact must be called
      // with the pact ID so pending notifications are cleared even after a
      // cold restart when the in-memory registry is empty.
      expect(h.notifications.cancelledPactIds, contains(_pactId));
    });
  });
}
