// Integration tests for the edit-pact wizard end-to-end flows.
//
// Two flows are covered:
//
// Flow 1 — edit directly from the pact overview (pacts panel → pact detail →
//   edit wizard): verifies the new habit name is shown on pact detail after
//   saving.
//
// Flow 2 — edit through the showup detail chain (showup detail → pact detail
//   → edit wizard): verifies the new habit name propagates back to showup
//   detail after saving — confirming the stale-name bug fix.
//
// Run on host:    flutter test integration_test/edit_pact_flow_test.dart
// Run on device:  flutter test integration_test/edit_pact_flow_test.dart -d <device>
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_edit_view_model.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_detail_view_model.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

// Fixed clock: well before the 08:00 showup window so auto-fail never fires.
final _testNow = DateTime(2099, 6, 15, 7, 55);
final _testToday = DateTime(2099, 6, 15);

const _pactId = 'pact-edit-flow-test';
const _showupId = '${_pactId}_20990615T080000_0';

final _pact = buildPact(
  id: _pactId,
  habitName: 'Meditate',
  startDate: _testToday,
);

final _showup = buildShowup(
  id: _showupId,
  pactId: _pactId,
  scheduledAt: DateTime(2099, 6, 15, 8, 0),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Edit pact – flow 1: from pact overview (pacts panel)', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
      'rename_from_pact_detail_updates_displayed_name: renaming pact from pact detail updates the displayed habit name',
      (tester) async {
        h = await AppHarness.create(
          tester,
          extraOverrides: [
            todayProvider.overrideWithValue(_testNow),
            pactDetailNowProvider.overrideWithValue(_testNow),
            showupDetailNowProvider.overrideWithValue(_testNow),
            pactEditTodayProvider.overrideWithValue(_testToday),
          ],
          beforePump: (h) async {
            await h.pactRepo.savePact(_pact);
            await h.showupRepo.saveShowups([_showup]);
          },
        );

        // ── 1. Dashboard loaded — showup tile visible ────────────────────
        await waitFor(tester, find.text('Meditate'));

        // ── 2. Expand the pacts panel and tap the pact tile ──────────────
        await h.dashboard.expandPactsPanelViaSummary('Meditate');

        // The habit name appears in both the showup tile (main content) and
        // the pact tile (DraggableScrollableSheet). The dashboard uses a
        // Stack — the pacts panel is the last child, so its widgets come
        // after the main content widgets in tree order. Use .last to target
        // the pact tile inside the expanded panel.
        await tester.tap(find.text('Meditate').last);
        // _navigateToPact collapses the panel (260 ms delay) before pushing
        // the route; pump past that delay. Do NOT pumpAndSettle — pact detail
        // shows a spinner while its VM loads and that would hang.
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 100));

        // ── 3. Pact detail screen loaded ─────────────────────────────────
        await h.pactDetail.waitLoaded();
        await h.pactDetail.scrollToStopPact();
        expect(h.pactDetail.stopPactButton, findsOneWidget);

        // ── 4. Tap the edit button ───────────────────────────────────────
        await h.pactDetail.openEdit();

        // ── 5. Edit wizard loaded — habit name text field visible ────────
        await h.editWizard.waitForHabitNameField();

        // ── 6. Type the new habit name ───────────────────────────────────
        await h.editWizard.enterHabitName('Morning Run');

        // The AppBar title mirrors state.habitName live — visible now confirms
        // enterText fired onChanged before we swipe away from the name page.
        expect(find.text('Morning Run'), findsWidgets, reason: 'enterText did not fire onChanged');

        // ── 7. Swipe to reminder page, then to summary page ──────────────
        await h.editWizard.swipeForward(); // page 0 → 1 (reminder)
        await h.editWizard.swipeForward(); // page 1 → 2 (summary)

        // ── 8. Tap "Save Changes" ────────────────────────────────────────
        await tester.tap(find.byKey(const Key('pact-edit-save-button')));
        await tester.pump(); // start _onSubmit() async chain
        // Wait for the wizard to fully close: on a real device each pump()
        // renders one frame, so a fixed pump(300ms) is not enough to drive the
        // entire pop animation. Poll until the save button disappears instead —
        // that guarantees the pop animation finished and _onEditPact() resumed.
        // Do NOT use pumpAndSettle here: _onEditPact()'s load() shows a
        // CircularProgressIndicator which pumpAndSettle() would hang on.
        while (find.byKey(const Key('pact-edit-save-button')).evaluate().isNotEmpty) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        // Pop complete. load() ran concurrently with the pop animation and has
        // already updated pactDetailViewModelProvider (pact='Morning Run'). The
        // ListView preserved its scroll position from step 3 (scrolled down to
        // Stop Pact), so the habit name and STATS header are above the viewport
        // and not in the element tree. Scroll back up to reveal them.
        await h.pactDetail.scrollUpTo('Morning Run');

        // ── 9. Pact detail shows the new name; old name is gone ──────────
        expect(find.text('Morning Run'), findsAtLeastNWidgets(1));
        expect(find.text('Meditate'), findsNothing);

        // ── 10. pact_edit_saved analytics event was fired ─────────────────
        expect(
          h.analytics.loggedEvents.any((e) => e.name == 'pact_edit_saved'),
          isTrue,
        );
      },
    );
  });

  group('Edit pact – flow 2: showup detail → pact detail → edit', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    testWidgets(
      'rename_via_showup_detail_updates_shown_name: renaming pact via showup detail → pact detail → edit updates the habit name shown on ShowupDetailScreen',
      (tester) async {
        h = await AppHarness.create(
          tester,
          extraOverrides: [
            todayProvider.overrideWithValue(_testNow),
            pactDetailNowProvider.overrideWithValue(_testNow),
            showupDetailNowProvider.overrideWithValue(_testNow),
            pactEditTodayProvider.overrideWithValue(_testToday),
          ],
          beforePump: (h) async {
            await h.pactRepo.savePact(_pact);
            await h.showupRepo.saveShowups([_showup]);
          },
        );

        // ── 1. Dashboard loaded — showup tile visible ────────────────────
        await waitFor(tester, find.text('Meditate'));

        // ── 2. Tap the showup tile → ShowupDetailScreen ──────────────────
        await h.dashboard.openShowup('Meditate');
        await h.showupDetail.waitForMarkDone();

        // Original habit name is shown in the showup detail header.
        expect(find.text('Meditate'), findsAtLeastNWidgets(1));
        expect(h.showupDetail.viewPactDetailsLink, findsOneWidget);

        // ── 3. Tap "View pact details" → PactDetailScreen ────────────────
        await h.showupDetail.viewPactDetails();
        await h.pactDetail.waitLoaded();
        await h.pactDetail.scrollToStopPact();
        expect(h.pactDetail.stopPactButton, findsOneWidget);

        // ── 4. Tap the edit button ───────────────────────────────────────
        await h.pactDetail.openEdit();

        // ── 5. Edit wizard loaded ────────────────────────────────────────
        await h.editWizard.waitForHabitNameField();

        // ── 6. Type the new habit name ───────────────────────────────────
        await h.editWizard.enterHabitName('Yoga');

        // Same check as flow 1: AppBar title reflects the new name.
        expect(find.text('Yoga'), findsWidgets, reason: 'enterText did not fire onChanged');

        // ── 7. Swipe to summary ──────────────────────────────────────────
        await h.editWizard.swipeForward(); // page 0 → 1 (reminder)
        await h.editWizard.swipeForward(); // page 1 → 2 (summary)

        // ── 8. Tap "Save Changes" — wizard pops back to pact detail ──────
        await tester.tap(find.byKey(const Key('pact-edit-save-button')));
        await tester.pump(); // start _onSubmit() async chain
        // Same as flow 1: poll until save button gone, then wait for content.
        while (find.byKey(const Key('pact-edit-save-button')).evaluate().isNotEmpty) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        // Same as flow 1: ListView preserved scroll position (scrolled to Stop
        // Pact from step 3). Scroll back up to reveal the updated habit name.
        await h.pactDetail.scrollUpTo('Yoga');
        expect(find.text('Yoga'), findsAtLeastNWidgets(1));

        // ── 9. Navigate back → ShowupDetailScreen ────────────────────────
        // On iOS, wait for CupertinoNavigationBarBackButton to stabilise after
        // the PactEditScreen pop animation, then use pageBack().
        // On Android, pumpAndSettle first so the Material route-pop animation
        // is done; then tap BackButton directly. tester.pageBack() uses
        // find.byTooltip('Back') which fails while the AppBar is still
        // transitioning from the pact-edit pop.
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          await waitFor(tester, find.byType(CupertinoNavigationBarBackButton));
          await tester.pageBack();
        } else {
          await tester.pumpAndSettle();
          await tester.tap(find.byType(BackButton));
        }
        await tester.pump(const Duration(milliseconds: 500));

        // ── 10. ShowupDetailScreen shows the updated name ─────────────────
        // Without the bug fix, this would still show 'Meditate' because
        // ShowupDetailViewModel.habitName was only set at initial load time
        // and was not refreshed after the pact was renamed.
        await waitFor(tester, find.text('Yoga'));
        expect(find.text('Yoga'), findsAtLeastNWidgets(1));
        expect(find.text('Meditate'), findsNothing);
      },
    );
  });
}
