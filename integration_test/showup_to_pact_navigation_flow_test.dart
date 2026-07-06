// Integration test: navigation from showup detail to pact detail and back.
//
// Run on host:   flutter test integration_test/showup_to_pact_navigation_flow_test.dart
// Run on device: flutter test integration_test/showup_to_pact_navigation_flow_test.dart -d <device>
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

// Fixed clock: 5 minutes before the 08:00 showup window so auto-fail never
// triggers during the test.
final _testNow = DateTime(2099, 6, 15, 7, 55);
final _testToday = DateTime(2099, 6, 15);

const _pactId = 'pact-nav-test-1';
const _showupId = '${_pactId}_20990615T080000_0';

final _pact = Pact(
  id: _pactId,
  habitName: 'Morning Run',
  startDate: _testToday,
  endDate: DateTime(2099, 12, 31),
  showupDuration: const Duration(minutes: 30),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
  createdAt: _testToday,
);

final _showup = Showup(
  id: _showupId,
  pactId: _pactId,
  scheduledAt: DateTime(2099, 6, 15, 8, 0),
  duration: const Duration(minutes: 30),
  status: ShowupStatus.pending,
);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Showup → Pact navigation flow', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
      'tapping habit name on showup detail opens pact detail, back returns to showup detail',
      (tester) async {
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
        await waitFor(tester, find.text('Morning Run'));
        expect(find.text('Morning Run'), findsOneWidget);

        // ── 2. Tap showup tile → navigate to showup detail ───────────────
        await tester.tap(find.text('Morning Run'));
        await waitFor(tester, find.text(strings.markDone));
        expect(find.text(strings.markDone), findsOneWidget);

        // ── 3. Showup detail is visible with plain habit name and link ───
        // After navigation, 'Morning Run' appears in both the dashboard tile
        // (offscreen, still mounted below in the navigator stack) and the
        // showup detail content header as plain non-tappable text.
        expect(find.text('Morning Run'), findsWidgets);
        // The "View pact details" link is rendered below the habit name.
        expect(find.text(strings.showupViewPactDetails), findsOneWidget);

        // ── 4. Tap "View pact details" → navigate to pact detail ─────────
        await tester.tap(find.text(strings.showupViewPactDetails));

        // ── 5. Pact detail screen is shown ───────────────────────────────
        // sectionStats is near the top of _PactDetailContent and only rendered
        // after the VM finishes loading — reliable on any screen size.
        await waitFor(tester, find.text(strings.sectionStats));
        // Stop Pact lives at the bottom of the ListView; scroll to build + reveal it.
        await tester.scrollUntilVisible(
          find.text(strings.stopPact),
          200.0,
          scrollable: find.ancestor(
            of: find.text(strings.sectionStats),
            matching: find.byType(Scrollable),
          ),
        );
        expect(find.text(strings.stopPact), findsOneWidget);
        // Note: markDone is still in the widget tree (showup detail is kept
        // alive below pact detail in the navigator stack) — don't assert it's
        // gone. What matters is that pact detail content is visible.

        // Let the page-transition slide-in animation fully complete before
        // navigating back; otherwise the back button may not yet be in the
        // tree. pumpAndSettle() is safe here — the pact detail VM has already
        // loaded (confirmed by waitFor(sectionStats) above), so no spinner is running.
        await tester.pumpAndSettle();

        // ── 6. Navigate back → return to showup detail ───────────────────
        await tester.pageBack();
        await waitFor(tester, find.text(strings.markDone));
        expect(find.text(strings.markDone), findsOneWidget);
        // Pact detail was popped from the stack — wait for its exit animation
        // to complete before asserting stopPact is gone.
        // pumpAndSettle() is safe: the showup detail VM was never disposed
        // (its route remained in the stack while pact detail was on top), so
        // no reload spinner is running at this point.
        await tester.pumpAndSettle();
        expect(find.text(strings.stopPact), findsNothing);

        // ── 7. Navigate back again → return to dashboard ─────────────────
        await tester.pageBack();
        // waitFor 'Morning Run' confirms we're on the dashboard (the habit
        // name appears in the today's showup tile). We don't assert
        // findsOneWidget because the pacts panel may have also loaded by now
        // and shows the same name in its pact entry row.
        await waitFor(tester, find.text('Morning Run'));
        // Pump multiple frames to ensure the back-navigation animation fully
        // completes and the showup detail route is removed from the widget tree.
        // A single pump(500ms) is not sufficient because waitFor may have
        // returned early (during the animation) and the route is still live.
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        // Neither screen-specific button should be visible on the dashboard.
        expect(find.text(strings.markDone), findsNothing);
        expect(find.text(strings.stopPact), findsNothing);
      },
    );

    testWidgets(
      'habit name is not tappable when pact is deleted — no navigation occurs',
      (tester) async {
        // Seed only the showup — no corresponding pact in the repository.
        // habitName will resolve to null in ShowupDetailViewModel.load().
        //
        // To reach the showup detail screen without a pact tile on the
        // dashboard (which shows active pacts), we seed a second pact that
        // carries the showup. After load the pact is removed, simulating
        // deletion.
        final carrierPact = Pact(
          id: _pactId,
          habitName: 'Deleted Habit',
          startDate: _testToday,
          endDate: DateTime(2099, 12, 31),
          showupDuration: const Duration(minutes: 30),
          schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
          status: PactStatus.active,
          createdAt: _testToday,
        );

        h = await AppHarness.create(
          tester,
          extraOverrides: [
            todayProvider.overrideWithValue(_testNow),
            showupDetailNowProvider.overrideWithValue(_testNow),
          ],
          beforePump: (h) async {
            await h.pactRepo.savePact(carrierPact);
            await h.showupRepo.saveShowups([_showup]);
          },
        );

        final strings = l10n(tester);

        // ── 1. Dashboard shows the showup tile ────────────────────────────
        await waitFor(tester, find.text('Deleted Habit'));

        // ── 2. Remove the pact BEFORE opening showup detail to simulate
        //       a deletion racing with the detail screen open. ──────────────
        await h.pactRepo.deletePact(_pactId);

        // ── 3. Tap the showup tile ────────────────────────────────────────
        await tester.tap(find.text('Deleted Habit'));
        await waitFor(tester, find.text(strings.showupHabitDeleted));

        // ── 4. Habit name shows the "deleted" fallback; link is absent ───
        expect(find.text(strings.showupHabitDeleted), findsOneWidget);
        // "View pact details" must not appear — pact no longer exists.
        expect(find.text(strings.showupViewPactDetails), findsNothing);

        // ── 5. Tapping the fallback label does nothing ────────────────────
        await tester.tap(find.text(strings.showupHabitDeleted));
        await tester.pump(const Duration(milliseconds: 200));

        // No navigation — stopPact button must not appear.
        expect(find.text(strings.stopPact), findsNothing);
        // markDone is still visible (we're still on showup detail).
        expect(find.text(strings.markDone), findsOneWidget);
      },
    );
  });
}
