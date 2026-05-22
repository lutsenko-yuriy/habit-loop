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
// Run on host:   flutter test integration_test/edit_pact_flow_test.dart
// Run on device: flutter test integration_test/edit_pact_flow_test.dart -d <device>
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/domain/showup/showup.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
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

final _pact = Pact(
  id: _pactId,
  habitName: 'Meditate',
  startDate: _testToday,
  endDate: DateTime(2099, 12, 31),
  showupDuration: const Duration(minutes: 10),
  schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
  status: PactStatus.active,
  createdAt: _testToday,
);

final _showup = Showup(
  id: _showupId,
  pactId: _pactId,
  scheduledAt: DateTime(2099, 6, 15, 8, 0),
  duration: const Duration(minutes: 10),
  status: ShowupStatus.pending,
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Swipes the edit-wizard [PageView] forward by one page.
///
/// Uses [find.byType(PageView)] so this works on both iOS and Android —
/// each platform uses a different key (`pact-edit-pageview-ios` /
/// `pact-edit-pageview-android`) but both contain exactly one [PageView].
///
/// Uses [WidgetTester.timedDrag] with a short duration for high effective
/// velocity (well above [kMinFlingVelocity] = 365 px/s) so the PageView
/// reliably snaps to the next page regardless of which page's content is
/// currently displayed (some pages use a [ListView] that can compete with the
/// [PageView]'s gesture recognizer under [flingFrom]).
Future<void> _swipeEditWizardForward(WidgetTester tester) async {
  final pageViewFinder = find.byType(PageView);
  // A 400 px drag in 50 ms → effective velocity ≈ 8000 px/s, well above
  // the PageView snap threshold. Starting at the center of the PageView
  // avoids any edge-widget hit-test ambiguity.
  await tester.timedDrag(pageViewFinder, const Offset(-400, 0), const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

/// Expands the pacts panel by tapping its collapsed header.
///
/// The panel header is the [GestureDetector] at the bottom of the dashboard
/// that shows the active/done/cancelled summary lines. A single tap triggers
/// `_expand()` which animates the panel to ~55% of screen height.
Future<void> _expandPactsPanel(WidgetTester tester, String habitName) async {
  // The summary text in the panel header is the most reliable finder because
  // it is visible at the collapsed height and does not conflict with other
  // widgets on the dashboard.
  final strings = l10n(tester);
  // The pacts panel header shows all three count lines joined with '\n' in a
  // single Text widget (see pacts_summary_bar.dart). find.text() requires an
  // exact full-string match, so use find.textContaining() to match the active
  // count substring instead.
  final summaryFinder = find.textContaining(strings.pactsActive(1));
  expect(summaryFinder, findsOneWidget);
  await tester.tap(summaryFinder);
  // Allow the DraggableScrollableSheet snap animation to complete.
  await tester.pump(const Duration(milliseconds: 400));
  // Wait for the pact tile to appear after the panel has expanded.
  await waitFor(tester, find.text(habitName));
}

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
      'renaming pact from pact detail updates the displayed habit name',
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

        final strings = l10n(tester);

        // ── 1. Dashboard loaded — showup tile visible ────────────────────
        await waitFor(tester, find.text('Meditate'));

        // ── 2. Expand the pacts panel and tap the pact tile ──────────────
        await _expandPactsPanel(tester, 'Meditate');

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
        await waitFor(tester, find.text(strings.stopPact));
        expect(find.text(strings.stopPact), findsOneWidget);

        // ── 4. Tap the edit button ───────────────────────────────────────
        // The edit button is in CupertinoNavigationBar.trailing, which in
        // the macOS integration test environment renders outside the 402px
        // viewport bounds (~x=512). tester.tap() misses it silently.
        // Directly invoke onPressed to bypass the hit-test limitation.
        tester.widget<CupertinoButton>(find.byKey(const Key('pact-detail-edit-button'))).onPressed?.call();
        // Do NOT pumpAndSettle here: PactEditScreen shows a spinner while
        // load() is in flight (CupertinoActivityIndicator on iOS never
        // settles). Pump once to let initState fire, then waitFor the field.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // ── 5. Edit wizard loaded — habit name text field visible ────────
        await waitFor(tester, find.byKey(const Key('pact-creation-habit-name-field')));

        // ── 6. Type the new habit name ───────────────────────────────────
        await tester.enterText(
          find.byKey(const Key('pact-creation-habit-name-field')),
          'Morning Run',
        );
        await tester.pump();

        // ── 7. Swipe to reminder page, then to summary page ──────────────
        await _swipeEditWizardForward(tester); // page 0 → 1 (reminder)
        await _swipeEditWizardForward(tester); // page 1 → 2 (summary)

        // ── 8. Tap "Save Changes" ────────────────────────────────────────
        await tester.tap(find.byKey(const Key('pact-edit-save-button')));
        // Do NOT pumpAndSettle: the save fires async ops and pops the route,
        // which can leave a loading indicator in the pact detail. Use waitFor.
        await waitFor(tester, find.text('Morning Run'));

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
      'renaming pact updates the habit name shown on ShowupDetailScreen',
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

        final strings = l10n(tester);

        // ── 1. Dashboard loaded — showup tile visible ────────────────────
        await waitFor(tester, find.text('Meditate'));

        // ── 2. Tap the showup tile → ShowupDetailScreen ──────────────────
        await tester.tap(find.text('Meditate'));
        await waitFor(tester, find.text(strings.markDone));

        // Original habit name is shown in the showup detail header.
        expect(find.text('Meditate'), findsAtLeastNWidgets(1));
        expect(find.text(strings.showupViewPactDetails), findsOneWidget);

        // ── 3. Tap "View pact details" → PactDetailScreen ────────────────
        await tester.tap(find.text(strings.showupViewPactDetails));
        await waitFor(tester, find.text(strings.stopPact));
        expect(find.text(strings.stopPact), findsOneWidget);

        // ── 4. Tap the edit button ───────────────────────────────────────
        // Direct onPressed invocation — same reason as flow 1: the button
        // renders outside the viewport in the macOS integration test runner.
        tester.widget<CupertinoButton>(find.byKey(const Key('pact-detail-edit-button'))).onPressed?.call();
        // Do NOT pumpAndSettle: spinner in PactEditScreen never settles.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // ── 5. Edit wizard loaded ────────────────────────────────────────
        await waitFor(tester, find.byKey(const Key('pact-creation-habit-name-field')));

        // ── 6. Type the new habit name ───────────────────────────────────
        await tester.enterText(
          find.byKey(const Key('pact-creation-habit-name-field')),
          'Yoga',
        );
        await tester.pump();

        // ── 7. Swipe to summary ──────────────────────────────────────────
        await _swipeEditWizardForward(tester); // page 0 → 1 (reminder)
        await _swipeEditWizardForward(tester); // page 1 → 2 (summary)

        // ── 8. Tap "Save Changes" — wizard pops back to pact detail ──────
        await tester.tap(find.byKey(const Key('pact-edit-save-button')));
        await waitFor(tester, find.text('Yoga'));
        expect(find.text('Yoga'), findsAtLeastNWidgets(1));

        // ── 9. Navigate back → ShowupDetailScreen ────────────────────────
        // Wait for the CupertinoNavigationBarBackButton to appear before
        // calling pageBack(). The PactEditScreen pop animation may still be
        // completing when 'Yoga' first becomes visible, leaving the nav bar
        // in a transitioning state where the back button is not yet a fully
        // independent widget.
        await waitFor(tester, find.byType(CupertinoNavigationBarBackButton));
        await tester.pageBack();
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
