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
  // 300 px in 50 ms → velocity ≈ 6000 px/s (above the snap threshold).
  // 300 px keeps the drag within one page width on any ≥300 dp device:
  // (300/320)+0.5=1.44 → rounds to 1, so one page advance per swipe.
  // A 400 px drag overshoots to page 2 on ≤400 dp screens (CI AVD is 320 dp):
  // (400/320)+0.5=1.75 → rounds to 2, skipping the reminder step entirely.
  await tester.timedDrag(pageViewFinder, const Offset(-300, 0), const Duration(milliseconds: 50));
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
        // sectionStats is near the top of _PactDetailContent and only rendered
        // after the VM finishes loading — reliable on any screen size.
        await waitFor(tester, find.text(strings.sectionStats.toUpperCase()));
        // Stop Pact lives at the bottom of the ListView; scroll to build + reveal it.
        await tester.scrollUntilVisible(
          find.text(strings.stopPact),
          200.0,
          scrollable: find.ancestor(
            of: find.text(strings.sectionStats.toUpperCase()),
            matching: find.byType(Scrollable),
          ),
        );
        expect(find.text(strings.stopPact), findsOneWidget);

        // ── 4. Tap the edit button ───────────────────────────────────────
        // Call onPressed directly on both platforms: the AppBar action may
        // render partially off-screen on narrow test devices (centre x > screen
        // width), causing tester.tap() to miss. iOS CupertinoNavigationBar has
        // the same issue on macOS test environments.
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          tester.widget<CupertinoButton>(find.byKey(const Key('pact-detail-edit-button'))).onPressed?.call();
        } else {
          tester.widget<IconButton>(find.byKey(const Key('pact-detail-edit-button'))).onPressed?.call();
        }
        // Do NOT pumpAndSettle here: PactEditScreen shows a spinner while
        // load() is in flight (CupertinoActivityIndicator on iOS never
        // settles). Pump once to let initState fire, then waitFor the field.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // ── 5. Edit wizard loaded — habit name text field visible ────────
        await waitFor(tester, find.byKey(const Key('pact-creation-habit-name-field')));
        // Let the route slide-in animation finish before enterText. The
        // field enters the widget tree partway through the animation; if
        // we attempt to focus it while it is still off-screen, showKeyboard
        // taps the wrong position and onChanged never fires.
        await tester.pumpAndSettle();

        // ── 6. Type the new habit name ───────────────────────────────────
        // Pre-tap focuses the field and establishes the platform TextInput
        // connection. pumpAndSettle() is intentionally NOT used after this tap
        // — it drove the keyboard-open animation long enough to reset the
        // connection on cold-JIT Android CI before enterText could fire
        // onChanged. A minimal pump is enough for focus to settle.
        await tester.tap(find.byKey(const Key('pact-creation-habit-name-field')));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.enterText(
          find.byKey(const Key('pact-creation-habit-name-field')),
          'Morning Run',
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // The AppBar title mirrors state.habitName live — visible now confirms
        // enterText fired onChanged before we swipe away from the name page.
        expect(find.text('Morning Run'), findsWidgets, reason: 'enterText did not fire onChanged');

        // ── 7. Swipe to reminder page, then to summary page ──────────────
        await _swipeEditWizardForward(tester); // page 0 → 1 (reminder)
        await _swipeEditWizardForward(tester); // page 1 → 2 (summary)

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
        await tester.scrollUntilVisible(
          find.text('Morning Run'),
          -200.0,
          scrollable: find.ancestor(
            of: find.text(strings.stopPact),
            matching: find.byType(Scrollable),
          ),
        );

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
        // sectionStats is near the top of _PactDetailContent and only rendered
        // after the VM finishes loading — reliable on any screen size.
        await waitFor(tester, find.text(strings.sectionStats.toUpperCase()));
        // Stop Pact lives at the bottom of the ListView; scroll to build + reveal it.
        await tester.scrollUntilVisible(
          find.text(strings.stopPact),
          200.0,
          scrollable: find.ancestor(
            of: find.text(strings.sectionStats.toUpperCase()),
            matching: find.byType(Scrollable),
          ),
        );
        expect(find.text(strings.stopPact), findsOneWidget);

        // ── 4. Tap the edit button ───────────────────────────────────────
        // Call onPressed directly on both platforms: same pattern as flow 1.
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          tester.widget<CupertinoButton>(find.byKey(const Key('pact-detail-edit-button'))).onPressed?.call();
        } else {
          tester.widget<IconButton>(find.byKey(const Key('pact-detail-edit-button'))).onPressed?.call();
        }
        // Do NOT pumpAndSettle: spinner in PactEditScreen never settles.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // ── 5. Edit wizard loaded ────────────────────────────────────────
        await waitFor(tester, find.byKey(const Key('pact-creation-habit-name-field')));
        // Same as flow 1: settle the route animation before focusing the field.
        await tester.pumpAndSettle();

        // ── 6. Type the new habit name ───────────────────────────────────
        // No pre-tap here: the field is fresh after pumpAndSettle and enterText
        // focuses it internally. Flow 1 pre-taps to work around a cold-JIT
        // keyboard timing issue that does not appear on this navigation path.
        await tester.enterText(
          find.byKey(const Key('pact-creation-habit-name-field')),
          'Yoga',
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Same check as flow 1: AppBar title reflects the new name.
        expect(find.text('Yoga'), findsWidgets, reason: 'enterText did not fire onChanged');

        // ── 7. Swipe to summary ──────────────────────────────────────────
        await _swipeEditWizardForward(tester); // page 0 → 1 (reminder)
        await _swipeEditWizardForward(tester); // page 1 → 2 (summary)

        // ── 8. Tap "Save Changes" — wizard pops back to pact detail ──────
        await tester.tap(find.byKey(const Key('pact-edit-save-button')));
        await tester.pump(); // start _onSubmit() async chain
        // Same as flow 1: poll until save button gone, then wait for content.
        while (find.byKey(const Key('pact-edit-save-button')).evaluate().isNotEmpty) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        // Same as flow 1: ListView preserved scroll position (scrolled to Stop
        // Pact from step 3). Scroll back up to reveal the updated habit name.
        await tester.scrollUntilVisible(
          find.text('Yoga'),
          -200.0,
          scrollable: find.ancestor(
            of: find.text(strings.stopPact),
            matching: find.byType(Scrollable),
          ),
        );
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
