// Integration tests for pact chaining (HAB-202): creating a new pact from a
// finished one via "Adjust and start again", with Previous/Next navigation
// links between predecessor and successor.
//
// Run on host:   flutter test integration_test/pact_chain_test.dart
// Run on device: flutter test integration_test/pact_chain_test.dart -d <device>
import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/material.dart' show Key, Offset, Scrollable, TextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart' show todayProvider;
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_screen.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_screen.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_view_model.dart' show pactDetailNowProvider;
import 'package:integration_test/integration_test.dart';

import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import 'harness.dart';

// pact_chaining_enabled now defaults to true (HAB-202 WU4 shipped), but an
// explicit override still keeps these scenarios independent of that default
// — see the flag-off scenario below, which needs the opposite override.
final _chainingEnabled = remoteConfigServiceProvider.overrideWithValue(
  FakeRemoteConfigService(overrides: {'pact_chaining_enabled': true}),
);

// ── LEGACY push/pop nav-stack fixtures/helpers (HAB-206) ──────────────────
//
// HAB-206 WU0 (PR #346) replaced the two scenarios below with stubs for the
// not-yet-implemented in-place-swap behavior, deleting real coverage for the
// push/pop model that is still what actually ships until WU1 lands — a real
// hotfix window would go out with chain navigation unguarded. Restored here
// as an explicitly-labeled legacy group so `main` keeps coverage of the
// *actually-shipping* behavior in the meantime. Delete this entire section
// (fixtures, helpers, and the "LEGACY" group below) in the same commit that
// makes the new in-place-swap stub scenarios green — see
// docs/knowledge/notes/HAB-206.md.

const _legacyPredecessorId = 'chain-nav-predecessor';
const _legacySuccessorId = 'chain-nav-successor';

// Dated near 2099 (short spans, matching every other integration-test
// fixture in this suite) rather than the ticket's illustrative 2026 dates —
// buildPact's default endDate is 2099-12-31, so a near-term startDate here
// would produce a ~74-year pact span and force ShowupGenerator to compute
// tens of thousands of daily occurrences on every load (HAB-202 debugging
// note, 2026-07-30: this was the actual cause of an apparent test hang).
final _legacyPredecessorPact = buildPact(
  id: _legacyPredecessorId,
  habitName: 'Vibe coding',
  startDate: DateTime(2099, 1, 1),
  endDate: DateTime(2099, 6, 1),
  status: PactStatus.stopped,
  stoppedAt: DateTime(2099, 3, 1),
);

final _legacySuccessorPact = buildPact(
  id: _legacySuccessorId,
  habitName: 'Vibe coding (v2)',
  startDate: DateTime(2099, 3, 2),
  endDate: DateTime(2099, 9, 2),
  predecessorPactId: _legacyPredecessorId,
);

Future<void> _legacyTapPreviousPactLink(WidgetTester tester) async {
  await waitFor(tester, find.byKey(const Key('pact-detail-previous-pact-link')));
  await tester.tap(find.byKey(const Key('pact-detail-previous-pact-link')));
  // pumpAndSettle (not fixed-duration pumps) — a pop needs the exit
  // transition to fully finish before the popped screen's PactDetailScreen
  // is actually removed from the tree, otherwise _currentDetailPactId's
  // find.byType(PactDetailScreen).last can still match the mid-transition
  // outgoing screen (HAB-202 debugging note, 2026-07-30).
  await tester.pumpAndSettle();
}

/// Taps "Next Pact" on the currently-visible screen for [currentPactId].
///
/// Scoped to that screen's own `pact-detail-scroll-view-<id>` Scrollable
/// (HAB-202) rather than `find.byType(Scrollable).first` — an earlier
/// PactDetailScreen stays mounted underneath a pushed one, so an
/// unscoped Scrollable finder can match the wrong (offstage) screen's list
/// and never actually bring the visible screen's link into view.
Future<void> _legacyTapNextPactLink(WidgetTester tester, {required String currentPactId}) async {
  await tester.dragUntilVisible(
    find.byKey(const Key('pact-detail-next-pact-link')),
    find
        .descendant(
          of: find.byKey(Key('pact-detail-scroll-view-$currentPactId')),
          matching: find.byType(Scrollable),
        )
        .first,
    const Offset(0, -100),
  );
  await tester.tap(find.byKey(const Key('pact-detail-next-pact-link')));
  // pumpAndSettle — see _legacyTapPreviousPactLink's comment; this link can
  // trigger either a push or a pop depending on cameFromPactId, and both
  // need their transition to fully finish before asserting.
  await tester.pumpAndSettle();
}

/// The pactId of the topmost mounted [PactDetailScreen] — i.e. the one
/// currently visible. Earlier routes stay mounted underneath a pushed one
/// (Navigator's default `maintainState: true`), so `find.text(habitName)`
/// matches both the visible screen's title and the pacts-panel row still
/// mounted behind it; this reads the unambiguous `pactId` field instead.
String _currentDetailPactId(WidgetTester tester) =>
    tester.widgetList<PactDetailScreen>(find.byType(PactDetailScreen)).last.pactId;

/// Scrolls [key] into view within the pact detail screen for [pactId].
///
/// Scoped to that screen's own `pact-detail-scroll-view-<id>` Scrollable
/// (HAB-202) — see `_tapNextPactLink`'s comment above for why an unscoped
/// `Scrollable` finder can target the wrong (offstage) screen when multiple
/// `PactDetailScreen`s are mounted at once.
///
/// [moveStep] defaults to scrolling *down* (revealing content below the
/// fold, e.g. "Adjust and start again" near the bottom). Pass a positive Y
/// offset to scroll *up* instead — needed for "Previous"/"Next Pact" (near
/// the top) when the list is already scrolled down from an earlier call on
/// the same still-mounted screen instance (its scroll position persists
/// across a push/pop round trip, so scrolling toward the bottom for one
/// widget can leave a top-of-list widget outside the lazy ListView's built
/// range entirely, not just offstage — HAB-202 WU4).
Future<void> _scrollToDetailKey(
  WidgetTester tester,
  Key key, {
  required String pactId,
  Offset moveStep = const Offset(0, -100),
}) async {
  await tester.dragUntilVisible(
    find.byKey(key),
    find
        .descendant(
          of: find.byKey(Key('pact-detail-scroll-view-$pactId')),
          matching: find.byType(Scrollable),
        )
        .first,
    moveStep,
  );
  // dragUntilVisible's own trailing Scrollable.ensureVisible() call can leave
  // its scroll-into-view animation still settling by the time control
  // returns — observed as a tap landing a few px past the viewport's bottom
  // edge (HAB-202 WU4). Drain it before the caller taps.
  await tester.pumpAndSettle();
}

/// Swipes the pact-creation [PageView] to the next page.
///
/// Copied from `create_pact_flow_test.dart` — see that file's doc comment for
/// why 300px/50ms drags from the top-right corner are used instead of a fling
/// from the center (avoids intercepting the showup-duration Slider, and stays
/// on-screen / doesn't overshoot on any viewport width).
Future<void> _swipeWizardForward(WidgetTester tester) async {
  const iosKey = Key('pact-creation-pageview-ios');
  const androidKey = Key('pact-creation-pageview-android');
  final key = find.byKey(iosKey).evaluate().isNotEmpty ? iosKey : androidKey;
  final rect = tester.getRect(find.byKey(key));
  await tester.timedDragFrom(
    Offset(rect.right - 10, rect.top + 40),
    const Offset(-300, 0),
    const Duration(milliseconds: 50),
  );
  await tester.pumpAndSettle();
}

/// Swipes from the habit-name page all the way to the summary page.
///
/// 8 swipes, not 5 (the number of page transitions needed) — a forward drag
/// occasionally doesn't cross the PageView's snap threshold on the last hop
/// into the reminder/summary pages, observed empirically on iOS; the extra
/// margin is harmless since swiping past the last page is a no-op.
Future<void> _swipeWizardToSummary(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await _swipeWizardForward(tester);
  }
}

/// Current text of the habit-name field on the (already open) creation
/// wizard. Reads the controller directly rather than `find.text` — the
/// wizard's AppBar/nav-bar title *also* shows the habit name once it's
/// non-empty (see `pact_creation_page_android.dart`'s title logic), so a
/// pre-filled flow has two matching `Text`/`EditableText` widgets and
/// `find.text` can't disambiguate which one is the field itself.
///
/// `.last` — the predecessor's own detail screen (with its note-section
/// `TextField`/`CupertinoTextField`) stays mounted underneath the pushed
/// creation wizard (Navigator's default `maintainState: true`), so an
/// unscoped predicate can match it too; the topmost (most-recently-built)
/// match is always the wizard's own field (same precedent as
/// `_currentDetailPactId` above).
String _habitNameFieldText(WidgetTester tester) {
  final field = tester.widget(find.byWidgetPredicate((w) => w is TextField || w is CupertinoTextField).last);
  return field is TextField ? field.controller!.text : (field as CupertinoTextField).controller!.text;
}

/// Waits for `pact_created` to fire (submit() completes asynchronously and
/// pops the wizard) — see `create_pact_flow_test.dart` for why this is safer
/// than asserting immediately after the confirm tap.
Future<void> _waitForPactCreated(WidgetTester tester, AppHarness h) async {
  final deadline = tester.binding.clock.now().add(const Duration(seconds: 30));
  while (!h.analytics.loggedEvents.any((e) => e.name == 'pact_created')) {
    if (tester.binding.clock.now().isAfter(deadline)) {
      throw TestFailure('pact_created event was not fired within the timeout');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Pact chain — adjust and start again', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    // 5 min before the predecessor's own DailySchedule slot, so the flow's
    // "today" sits just after the predecessor stopped — near 2099 to keep
    // every fixture's span short (see buildPact's endDate doc comment).
    final adjustTestNow = DateTime(2099, 3, 2, 7, 55);

    final predecessor = buildPact(
      id: 'adjust-predecessor',
      habitName: 'Vibe coding',
      startDate: DateTime(2099, 1, 1),
      endDate: DateTime(2099, 3, 1),
      showupDuration: const Duration(minutes: 15),
      schedule: const DailySchedule(timeOfDay: Duration(hours: 8)),
      status: PactStatus.stopped,
      stoppedAt: DateTime(2099, 2, 1),
      reminderOffset: const Duration(minutes: 10),
    );

    testWidgets('adjust_and_start_again_creates_chained_pact_with_prefill_and_backlink', (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [
          remoteConfigServiceProvider.overrideWithValue(
            FakeRemoteConfigService(overrides: {
              'pact_chaining_enabled': true,
              // 'button' variant — single "I Accept" button, simplest to automate.
              'exp_003_commitment_confirmation': 'button',
            }),
          ),
          pactDetailNowProvider.overrideWithValue(adjustTestNow),
          pactCreationTodayProvider.overrideWithValue(adjustTestNow),
          pactCreationSubmitNowProvider.overrideWithValue(() => adjustTestNow),
          todayProvider.overrideWithValue(adjustTestNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(predecessor);
        },
      );
      final strings = l10n(tester);

      // ── 1-2. Predecessor detail shows "Adjust and start again" ───────────
      await openPactsPanel(tester);
      await openPactDetail(tester, 'Vibe coding');
      await _scrollToDetailKey(
        tester,
        const Key('pact-detail-adjust-and-start-again-button'),
        pactId: predecessor.id,
      );
      expect(find.byKey(const Key('pact-detail-adjust-and-start-again-button')), findsOneWidget);

      // ── 3. Tap it — wizard opens ───────────────────────────────────────
      await tester.tap(find.byKey(const Key('pact-detail-adjust-and-start-again-button')));
      await waitFor(tester, find.byType(PactCreationScreen));
      // Settle the push transition — see the cancelled-wizard test's comment
      // on this same pattern for why this matters once a keyed finder (not
      // just `.last`-tolerant reads) is involved.
      await tester.pumpAndSettle();

      // ── 4. Habit name is pre-filled with "Vibe coding (v2)" ──────────────
      expect(_habitNameFieldText(tester), 'Vibe coding (v2)');

      // ── 5. Swipe to summary and confirm (all fields already valid from
      //        the prefill — no field interaction needed) ──────────────────
      await _swipeWizardToSummary(tester);
      await tester.tap(find.text(strings.createPactConfirm));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.commitmentAccept));

      // ── 6. Wait for pact_created, then verify persisted fields ──────────
      await _waitForPactCreated(tester, h);

      final allPacts = await h.pactRepo.getAllPacts();
      final successor = allPacts.firstWhere((p) => p.habitName == 'Vibe coding (v2)');
      expect(successor.predecessorPactId, predecessor.id);
      // The prefill migrates a legacy DailySchedule to the card-based
      // SlotSchedule (PactChainService reuses PactBuilder.fromPact's
      // migration) — same daily 8am cadence, different schedule shape.
      expect(
        successor.schedule,
        SlotSchedule(slots: [
          WeeklySlot(weekdays: const {1, 2, 3, 4, 5, 6, 7}, timeOfDay: const Duration(hours: 8))
        ]),
      );
      expect(successor.showupDuration, predecessor.showupDuration);
      expect(successor.reminderOffset, predecessor.reminderOffset);
      expect(
        successor.startDate,
        DateTime(adjustTestNow.year, adjustTestNow.month, adjustTestNow.day),
      );

      // ── 7. Back on the (reloaded) predecessor: "Adjust and start again" is
      //        gone; "Next Pact: 'Vibe coding (v2)'" now shows under the
      //        title instead. No manual scroll needed — PactDetailScreen
      //        resets scroll position to the top after this round trip, so
      //        the newly-relevant top-of-list content is already visible.
      await waitFor(tester, find.byKey(const Key('pact-detail-next-pact-link')));
      // The scroll-to-top jump is synchronous, but the resulting relayout
      // needs a settled frame before a tap's hit-test coordinates are
      // reliable — same class of race as the push-transition settle above.
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pact-detail-adjust-and-start-again-button')), findsNothing);

      // ── 8. Tap "Next Pact" — navigates to the new pact's detail screen ──
      await tester.tap(find.byKey(const Key('pact-detail-next-pact-link')));
      await tester.pumpAndSettle();

      // ── 9. Successor detail shows "Previous Pact: 'Vibe coding'" ─────────
      await waitFor(tester, find.byKey(const Key('pact-detail-previous-pact-link')));
      expect(find.text(strings.pactDetailPreviousPact('Vibe coding')), findsOneWidget);

      // ── 10. Tap "Previous Pact" — navigates back to the predecessor's
      //         detail screen (pops to the originating page instance) ─────
      await tester.tap(find.byKey(const Key('pact-detail-previous-pact-link')));
      await tester.pumpAndSettle();
      await _scrollToDetailKey(tester, const Key('pact-detail-next-pact-link'), pactId: predecessor.id);
      expect(find.byKey(const Key('pact-detail-next-pact-link')), findsOneWidget);
    });
  });

  group('Pact chain — navigation stack', () {
    // Scenarios below use P_p (predecessor / "parent") and P_c (successor /
    // "child"): P_c.predecessorPactId == P_p.id. They verify that tapping
    // "Previous Pact"/"Next Pact" swaps data in place on a single mounted
    // PactDetailScreen route (no push/pop) — see HAB-206's "Update — animated
    // transitions" for the full spec this stubs against.
    //
    // TODO(implement, WU1): declare `late AppHarness h;` and
    // `tearDown(() => h.dispose());` here when filling in the driver code.

    testWidgets('chain_navigation_previous_then_next_returns_to_same_page_instance', (tester) async {
      // TODO: 1. Seed predecessor pact ("Vibe coding") and linked successor
      //          pact ("Vibe coding (v2)").
      // TODO: 2. Open pacts panel, open the successor's detail screen.
      // TODO: 3. Verify exactly one PactDetailScreen is mounted, showing the
      //          successor's pactId.
      // TODO: 4. Tap "Previous Pact" — verify still exactly one
      //          PactDetailScreen mounted (no push occurred), now showing the
      //          predecessor's pactId.
      // TODO: 5. Tap "Next Pact" — verify still exactly one PactDetailScreen
      //          mounted, now showing the successor's pactId again.
      // TODO: 6. Press system back — verify it exits directly to the Pacts
      //          List in a single pop (no PactDetailScreen remains mounted).
    });

    testWidgets('chain_navigation_next_then_previous_returns_to_same_page_instance', (tester) async {
      // TODO: 1. Seed predecessor and successor pacts.
      // TODO: 2. Open pacts panel, open the predecessor's detail screen.
      // TODO: 3. Verify exactly one PactDetailScreen mounted, showing the
      //          predecessor's pactId.
      // TODO: 4. Tap "Next Pact" — verify still exactly one PactDetailScreen
      //          mounted, now showing the successor's pactId.
      // TODO: 5. Tap "Previous Pact" — verify still exactly one
      //          PactDetailScreen mounted, now showing the predecessor's
      //          pactId again.
      // TODO: 6. Press system back — verify direct exit to the Pacts List in
      //          a single pop.
    });

    testWidgets('chain_navigation_back_exits_directly_after_a_single_hop', (tester) async {
      // TODO: 1. Seed predecessor and successor pacts.
      // TODO: 2. Open pacts panel, open the predecessor's detail screen.
      // TODO: 3. Tap "Next Pact" — now viewing the successor (a single hop,
      //          not returned to the start).
      // TODO: 4. Press system back — verify it exits directly to the Pacts
      //          List in a single pop, with no PactDetailScreen remaining
      //          mounted.
    });
  });

  // See the "LEGACY push/pop nav-stack fixtures/helpers" comment near the top
  // of this file for why this group exists alongside the stubs above and
  // when to delete it (HAB-206).
  group('Pact chain — navigation stack (LEGACY push/pop model, HAB-206)', () {
    late AppHarness h;
    tearDown(() => h.dispose());
    // Both scenarios below use P_p (predecessor / "parent") and P_c (successor
    // / "child"): P_c.predecessorPactId == P_p.id. They verify that bouncing
    // between "Previous Pact"/"Next Pact" links pops back to the existing page
    // instance instead of pushing a duplicate — so the back stack never grows
    // past however deep the user has actually gone in one direction.

    testWidgets('LEGACY chain_navigation_previous_then_next_returns_to_same_page_instance', (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [_chainingEnabled],
        beforePump: (h) async {
          await h.pactRepo.savePact(_legacyPredecessorPact);
          await h.pactRepo.savePact(_legacySuccessorPact);
        },
      );

      await openPactsPanel(tester);
      await openPactDetail(tester, 'Vibe coding (v2)');

      // ── 3. P_c's detail screen is shown ───────────────────────────────────
      expect(_currentDetailPactId(tester), _legacySuccessorId);

      // ── 4. Tap "Previous Pact" — P_p's detail screen pushed on top ────────
      await _legacyTapPreviousPactLink(tester);
      expect(_currentDetailPactId(tester), _legacyPredecessorId);

      // ── 5. Tap "Next Pact" — back to P_c ──────────────────────────────────
      await _legacyTapNextPactLink(tester, currentPactId: _legacyPredecessorId);
      expect(_currentDetailPactId(tester), _legacySuccessorId);

      // ── 6. A single pop lands directly on the Pacts List, proving step 5
      //        popped back to the original P_c page instance rather than
      //        pushing a second copy of it. ─────────────────────────────────
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pacts-panel-drag-handle')), findsOneWidget);
      expect(find.byType(PactDetailScreen), findsNothing);
    });

    testWidgets('LEGACY chain_navigation_next_then_previous_returns_to_same_page_instance', (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [_chainingEnabled],
        beforePump: (h) async {
          await h.pactRepo.savePact(_legacyPredecessorPact);
          await h.pactRepo.savePact(_legacySuccessorPact);
        },
      );

      await openPactsPanel(tester);
      await openPactDetail(tester, 'Vibe coding');

      // ── 3. P_p's detail screen is shown ───────────────────────────────────
      expect(_currentDetailPactId(tester), _legacyPredecessorId);

      // ── 4. Tap "Next Pact" — P_c's detail screen pushed on top ────────────
      await _legacyTapNextPactLink(tester, currentPactId: _legacyPredecessorId);
      expect(_currentDetailPactId(tester), _legacySuccessorId);

      // ── 5. Tap "Previous Pact" — back to P_p ──────────────────────────────
      await _legacyTapPreviousPactLink(tester);
      expect(_currentDetailPactId(tester), _legacyPredecessorId);

      // ── 6. A single pop lands directly on the Pacts List, proving step 5
      //        popped back to the original P_p page instance rather than
      //        pushing a second copy of it. ─────────────────────────────────
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pacts-panel-drag-handle')), findsOneWidget);
      expect(find.byType(PactDetailScreen), findsNothing);
    });
  });

  group('Pact chain — default naming', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    final defaultNamingTestNow = DateTime(2099, 3, 3, 7, 55);

    final rootPact = buildPact(
      id: 'naming-root',
      habitName: 'Vibe coding',
      startDate: DateTime(2099, 1, 1),
      endDate: DateTime(2099, 2, 1),
      status: PactStatus.stopped,
      stoppedAt: DateTime(2099, 1, 20),
    );

    final midPact = buildPact(
      id: 'naming-mid',
      habitName: 'Focus Sessions',
      startDate: DateTime(2099, 2, 2),
      endDate: DateTime(2099, 3, 2),
      status: PactStatus.stopped,
      stoppedAt: DateTime(2099, 2, 20),
      predecessorPactId: 'naming-root',
    );

    testWidgets('chained_default_name_uses_root_habit_name_not_immediate_predecessor', (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [
          remoteConfigServiceProvider.overrideWithValue(
            FakeRemoteConfigService(overrides: {
              'pact_chaining_enabled': true,
              'exp_003_commitment_confirmation': 'button',
            }),
          ),
          pactDetailNowProvider.overrideWithValue(defaultNamingTestNow),
          pactCreationTodayProvider.overrideWithValue(defaultNamingTestNow),
          pactCreationSubmitNowProvider.overrideWithValue(() => defaultNamingTestNow),
          todayProvider.overrideWithValue(defaultNamingTestNow),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(rootPact);
          await h.pactRepo.savePact(midPact);
        },
      );
      final strings = l10n(tester);

      // ── 1-2. Open pact detail for "Focus Sessions" ────────────────────────
      await openPactsPanel(tester);
      await openPactDetail(tester, 'Focus Sessions');
      await _scrollToDetailKey(
        tester,
        const Key('pact-detail-adjust-and-start-again-button'),
        pactId: midPact.id,
      );

      // ── 3. Tap "Adjust and start again" ───────────────────────────────────
      await tester.tap(find.byKey(const Key('pact-detail-adjust-and-start-again-button')));
      await waitFor(tester, find.byType(PactCreationScreen));
      // Settle the push transition — see the cancelled-wizard test's comment
      // on this same pattern for why this matters once a keyed finder (not
      // just `.last`-tolerant reads) is involved.
      await tester.pumpAndSettle();

      // ── 4. Pre-filled with the root's name, not the immediate predecessor's ──
      expect(_habitNameFieldText(tester), 'Vibe coding (v3)');

      // ── 5. Swipe to summary and confirm ───────────────────────────────────
      await _swipeWizardToSummary(tester);
      await tester.tap(find.text(strings.createPactConfirm));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.commitmentAccept));

      // ── 6. Verify persisted fields ─────────────────────────────────────────
      await _waitForPactCreated(tester, h);

      final allPacts = await h.pactRepo.getAllPacts();
      final successor = allPacts.firstWhere((p) => p.habitName == 'Vibe coding (v3)');
      expect(successor.predecessorPactId, midPact.id);
    });
  });

  group('Pact chain — completed pact eligibility', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    final completedPact = buildPact(
      id: 'completed-morning-run',
      habitName: 'Morning Run',
      startDate: DateTime(2099, 1, 1),
      endDate: DateTime(2099, 2, 1),
      status: PactStatus.completed,
    );

    testWidgets('adjust_and_start_again_available_from_completed_pact', (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [_chainingEnabled],
        beforePump: (h) async {
          await h.pactRepo.savePact(completedPact);
        },
      );

      // ── 1-2. Open pact detail; scroll to the bottom action area ─────────
      await openPactsPanel(tester);
      await openPactDetail(tester, 'Morning Run');
      await _scrollToDetailKey(
        tester,
        const Key('pact-detail-adjust-and-start-again-button'),
        pactId: completedPact.id,
      );

      // ── 3. "Adjust and start again" is visible ──────────────────────────
      expect(find.byKey(const Key('pact-detail-adjust-and-start-again-button')), findsOneWidget);
    });
  });

  group('Pact chain — feature flag', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    final flagOffPredecessor = buildPact(
      id: 'flag-off-predecessor',
      habitName: 'Old Habit',
      startDate: DateTime(2099, 1, 1),
      endDate: DateTime(2099, 2, 1),
      status: PactStatus.stopped,
      stoppedAt: DateTime(2099, 1, 20),
    );

    final flagOffSuccessor = buildPact(
      id: 'flag-off-successor',
      habitName: 'New Habit',
      startDate: DateTime(2099, 2, 2),
      endDate: DateTime(2099, 3, 2),
      predecessorPactId: 'flag-off-predecessor',
    );

    testWidgets('flag_off_hides_adjust_button_and_chain_links', (tester) async {
      h = await AppHarness.create(
        tester,
        // 2. Explicit override — pact_chaining_enabled now defaults to
        // `true` (HAB-202 WU4 shipped), so this scenario's premise (the
        // flag being off) must be forced rather than relying on the default.
        extraOverrides: [
          remoteConfigServiceProvider.overrideWithValue(
            FakeRemoteConfigService(overrides: {'pact_chaining_enabled': false}),
          ),
        ],
        beforePump: (h) async {
          await h.pactRepo.savePact(flagOffPredecessor);
          await h.pactRepo.savePact(flagOffSuccessor);
        },
      );

      // ── 3. Predecessor: no "Adjust and start again", no "Next Pact" ─────
      await openPactsPanel(tester);
      await openPactDetail(tester, 'Old Habit');
      await waitFor(tester, find.byType(PactDetailScreen));
      expect(find.byKey(const Key('pact-detail-adjust-and-start-again-button')), findsNothing);
      expect(find.byKey(const Key('pact-detail-next-pact-link')), findsNothing);

      // ── 4. Back to the list; successor has no "Previous Pact" link ──────
      // pumpAndSettle drains the push transition first — otherwise pageBack()
      // (which taps the back button by tooltip/type) can fail to hit-test it
      // mid-animation (see archive_pact_flow_test.dart's own precedent).
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await openPactDetail(tester, 'New Habit');
      await waitFor(tester, find.byType(PactDetailScreen));
      expect(find.byKey(const Key('pact-detail-previous-pact-link')), findsNothing);
    });
  });

  group('Pact chain — cancelled wizard', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    final cancelledPact = buildPact(
      id: 'cancelled-evening-walk',
      habitName: 'Evening Walk',
      startDate: DateTime(2099, 1, 1),
      endDate: DateTime(2099, 2, 1),
      status: PactStatus.stopped,
      stoppedAt: DateTime(2099, 1, 20),
    );

    testWidgets('abandoning_adjust_wizard_leaves_predecessor_unchanged', (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [_chainingEnabled],
        beforePump: (h) async {
          await h.pactRepo.savePact(cancelledPact);
        },
      );

      // ── 1-2. Open detail; tap "Adjust and start again" — wizard opens ────
      await openPactsPanel(tester);
      await openPactDetail(tester, 'Evening Walk');
      await _scrollToDetailKey(
        tester,
        const Key('pact-detail-adjust-and-start-again-button'),
        pactId: cancelledPact.id,
      );
      await tester.tap(find.byKey(const Key('pact-detail-adjust-and-start-again-button')));
      await waitFor(tester, find.byType(PactCreationScreen));
      // Settle the push transition — otherwise the outgoing and incoming
      // Cupertino nav bars are both transiently present (the transition
      // overlays them during the animation), so a keyed finder on the close
      // button ambiguously matches both mid-flight.
      await tester.pumpAndSettle();
      expect(_habitNameFieldText(tester), 'Evening Walk (v2)');

      // ── 3. Back out without confirming, via the wizard's close button ────
      await tester.tap(find.byKey(const Key('pact-creation-close-button')));
      await tester.pumpAndSettle();

      // ── 4. Back on the predecessor's detail screen ────────────────────────
      // Read the pactId directly rather than scrolling to find the habit-name
      // text — the list is still scrolled to where "Adjust and start again"
      // was tapped from (same screen instance, never disposed), so the
      // top-of-list habit-name row isn't built yet (lazy ListView, not
      // merely offstage).
      await waitFor(tester, find.byType(PactDetailScreen));
      expect(_currentDetailPactId(tester), cancelledPact.id);

      // ── 5. Repository still contains only the original pact ─────────────
      final allPacts = await h.pactRepo.getAllPacts();
      expect(allPacts, hasLength(1));
      expect(allPacts.single.id, cancelledPact.id);
      expect(allPacts.single.predecessorPactId, isNull);

      // ── 6. "Adjust and start again" is still visible ────────────────────
      await _scrollToDetailKey(
        tester,
        const Key('pact-detail-adjust-and-start-again-button'),
        pactId: cancelledPact.id,
      );
      expect(find.byKey(const Key('pact-detail-adjust-and-start-again-button')), findsOneWidget);
    });
  });
}
