// Integration tests for pact chaining (HAB-202): creating a new pact from a
// finished one via "Adjust and start again", with Previous/Next navigation
// links between predecessor and successor.
//
// Run on host:   flutter test integration_test/pact_chain_test.dart
// Run on device: flutter test integration_test/pact_chain_test.dart -d <device>
import 'package:flutter/material.dart' show Key;
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/domain/pact/showup_schedule.dart';
import 'package:habit_loop/slices/dashboard/ui/generic/dashboard_view_model.dart' show todayProvider;
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_screen.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_creation_view_model.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_screen.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_view_model.dart' show pactDetailNowProvider;
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

// pact_chaining_enabled now defaults to true (HAB-202 WU4 shipped), but an
// explicit override still keeps these scenarios independent of that default
// — see the flag-off scenario below, which needs the opposite override.
const _chainingEnabled = {'pact_chaining_enabled': true};

// Dated near 2099 (short spans, matching every other integration-test
// fixture in this suite) rather than the ticket's illustrative 2026 dates —
// buildPact's default endDate is 2099-12-31, so a near-term startDate here
// would produce a ~74-year pact span and force ShowupGenerator to compute
// tens of thousands of daily occurrences on every load (HAB-202 debugging
// note, 2026-07-30: this was the actual cause of an apparent test hang).
const _chainNavPredecessorId = 'chain-nav-predecessor';
const _chainNavSuccessorId = 'chain-nav-successor';

final _chainNavPredecessorPact = buildPact(
  id: _chainNavPredecessorId,
  habitName: 'Vibe coding',
  startDate: DateTime(2099, 1, 1),
  endDate: DateTime(2099, 6, 1),
  status: PactStatus.stopped,
  stoppedAt: DateTime(2099, 3, 1),
);

final _chainNavSuccessorPact = buildPact(
  id: _chainNavSuccessorId,
  habitName: 'Vibe coding (v2)',
  startDate: DateTime(2099, 3, 2),
  endDate: DateTime(2099, 9, 2),
  predecessorPactId: _chainNavPredecessorId,
);

/// Waits for `pact_created`; submit() completes asynchronously and pops the wizard.
Future<void> _waitForPactCreated(AppHarness h) => h.dashboard.waitUntil(
      () => h.analytics.loggedEvents.any((e) => e.name == 'pact_created'),
      description: 'pact_created event fired',
    );

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
          pactDetailNowProvider.overrideWithValue(adjustTestNow),
          pactCreationTodayProvider.overrideWithValue(adjustTestNow),
          pactCreationSubmitNowProvider.overrideWithValue(() => adjustTestNow),
          todayProvider.overrideWithValue(adjustTestNow),
        ],
        remoteConfigOverrides: {
          'pact_chaining_enabled': true,
          // 'button' variant — single "I Accept" button, simplest to automate.
          'exp_003_commitment_confirmation': 'button',
        },
        beforePump: (h) async {
          await h.pactRepo.savePact(predecessor);
        },
      );
      final strings = l10n(tester);

      // ── 1-2. Predecessor detail shows "Adjust and start again" ───────────
      await openPactsPanel(tester);
      await openPactDetail(tester, 'Vibe coding');
      await h.pactDetail.scrollToKey(const Key('pact-detail-adjust-and-start-again-button'), pactId: predecessor.id);
      expect(find.byKey(const Key('pact-detail-adjust-and-start-again-button')), findsOneWidget);

      // ── 3. Tap it — wizard opens ───────────────────────────────────────
      await tester.tap(find.byKey(const Key('pact-detail-adjust-and-start-again-button')));
      await waitFor(tester, find.byType(PactCreationScreen));
      // Settle the push transition — see the cancelled-wizard test's comment
      // on this same pattern for why this matters once a keyed finder (not
      // just `.last`-tolerant reads) is involved.
      await tester.pumpAndSettle();

      // ── 4. Habit name is pre-filled with "Vibe coding (v2)" ──────────────
      expect(h.wizard.habitNameText, 'Vibe coding (v2)');

      // ── 5. Swipe to summary and confirm (all fields already valid from
      //        the prefill — no field interaction needed) ──────────────────
      await h.wizard.swipeToSummary();
      await tester.tap(find.text(strings.createPactConfirm));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.commitmentAccept));

      // ── 6. Wait for pact_created, then verify persisted fields ──────────
      await _waitForPactCreated(h);

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
      await h.pactDetail.tapNextPactLink(predecessor.id);

      // ── 9. Successor detail shows the predecessor's name in the chevron stripe ──
      await waitFor(tester, find.byKey(const Key('pact-detail-previous-pact-link')));
      expect(
        find.descendant(
          of: find.byKey(const Key('pact-detail-previous-pact-link')),
          matching: find.textContaining('Vibe coding'),
        ),
        findsOneWidget,
      );

      // ── 10. Tap "Previous Pact" — navigates back to the predecessor's
      //         detail screen (pops to the originating page instance) ─────
      await h.pactDetail.tapPreviousPactLink();
      await h.pactDetail.scrollToKey(const Key('pact-detail-next-pact-link'), pactId: predecessor.id);
      expect(find.byKey(const Key('pact-detail-next-pact-link')), findsOneWidget);
    });
  });

  group('Pact chain — navigation stack', () {
    late AppHarness h;
    tearDown(() => h.dispose());

    // Scenarios below use P_p (predecessor / "parent") and P_c (successor /
    // "child"): P_c.predecessorPactId == P_p.id. They verify that tapping
    // "Previous Pact"/"Next Pact" swaps data in place on a single mounted
    // PactDetailScreen route (no push/pop) — see HAB-206's "Update — animated
    // transitions" for the full spec (WU1 covers the in-place swap only; the
    // transition/carousel animation itself lands in WU3/WU4).

    testWidgets('chain_navigation_previous_then_next_returns_to_same_page_instance', (tester) async {
      // ── 1. Seed P_p ("Vibe coding") and linked P_c ("Vibe coding (v2)") ──
      h = await AppHarness.create(
        tester,
        remoteConfigOverrides: _chainingEnabled,
        beforePump: (h) async {
          await h.pactRepo.savePact(_chainNavPredecessorPact);
          await h.pactRepo.savePact(_chainNavSuccessorPact);
        },
      );

      // ── 2. Open the successor's detail screen ────────────────────────────
      await openPactsPanel(tester);
      await openPactDetail(tester, 'Vibe coding (v2)');

      // ── 3. Exactly one PactDetailScreen, showing the successor ───────────
      expect(find.byType(PactDetailScreen), findsOneWidget);
      expect(h.pactDetail.currentPactId, _chainNavSuccessorId);

      // ── 4. Tap "Previous Pact" — swaps in place, no push ─────────────────
      await h.pactDetail.tapPreviousPactLink();
      expect(find.byType(PactDetailScreen), findsOneWidget);
      expect(h.pactDetail.currentPactId, _chainNavPredecessorId);

      // ── 5. Tap "Next Pact" — swaps back to the successor ─────────────────
      // originalPactId is the successor — this screen was opened on it (step
      // 2), and the ListView's key stays pinned to that regardless of the
      // predecessor currently being shown (HAB-206 WU3).
      await h.pactDetail.tapNextPactLink(_chainNavSuccessorId);
      expect(find.byType(PactDetailScreen), findsOneWidget);
      expect(h.pactDetail.currentPactId, _chainNavSuccessorId);

      // ── 6. System back exits directly to the Pacts List in a single pop ──
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pacts-panel-drag-handle')), findsOneWidget);
      expect(find.byType(PactDetailScreen), findsNothing);
    });

    testWidgets('chain_navigation_next_then_previous_returns_to_same_page_instance', (tester) async {
      // ── 1. Seed P_p and P_c ───────────────────────────────────────────────
      h = await AppHarness.create(
        tester,
        remoteConfigOverrides: _chainingEnabled,
        beforePump: (h) async {
          await h.pactRepo.savePact(_chainNavPredecessorPact);
          await h.pactRepo.savePact(_chainNavSuccessorPact);
        },
      );

      // ── 2. Open the predecessor's detail screen ──────────────────────────
      await openPactsPanel(tester);
      await openPactDetail(tester, 'Vibe coding');

      // ── 3. Exactly one PactDetailScreen, showing the predecessor ─────────
      expect(find.byType(PactDetailScreen), findsOneWidget);
      expect(h.pactDetail.currentPactId, _chainNavPredecessorId);

      // ── 4. Tap "Next Pact" — swaps in place, no push ─────────────────────
      await h.pactDetail.tapNextPactLink(_chainNavPredecessorId);
      expect(find.byType(PactDetailScreen), findsOneWidget);
      expect(h.pactDetail.currentPactId, _chainNavSuccessorId);

      // ── 5. Tap "Previous Pact" — swaps back to the predecessor ───────────
      await h.pactDetail.tapPreviousPactLink();
      expect(find.byType(PactDetailScreen), findsOneWidget);
      expect(h.pactDetail.currentPactId, _chainNavPredecessorId);

      // ── 6. System back exits directly to the Pacts List in a single pop ──
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pacts-panel-drag-handle')), findsOneWidget);
      expect(find.byType(PactDetailScreen), findsNothing);
    });

    testWidgets('chain_navigation_back_exits_directly_after_a_single_hop', (tester) async {
      // ── 1. Seed P_p and P_c ───────────────────────────────────────────────
      h = await AppHarness.create(
        tester,
        remoteConfigOverrides: _chainingEnabled,
        beforePump: (h) async {
          await h.pactRepo.savePact(_chainNavPredecessorPact);
          await h.pactRepo.savePact(_chainNavSuccessorPact);
        },
      );

      // ── 2. Open the predecessor's detail screen ──────────────────────────
      await openPactsPanel(tester);
      await openPactDetail(tester, 'Vibe coding');

      // ── 3. Tap "Next Pact" — a single hop, not returned to the start ─────
      await h.pactDetail.tapNextPactLink(_chainNavPredecessorId);
      expect(h.pactDetail.currentPactId, _chainNavSuccessorId);

      // ── 4. System back exits directly to the Pacts List in a single pop ──
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
          pactDetailNowProvider.overrideWithValue(defaultNamingTestNow),
          pactCreationTodayProvider.overrideWithValue(defaultNamingTestNow),
          pactCreationSubmitNowProvider.overrideWithValue(() => defaultNamingTestNow),
          todayProvider.overrideWithValue(defaultNamingTestNow),
        ],
        remoteConfigOverrides: {
          'pact_chaining_enabled': true,
          'exp_003_commitment_confirmation': 'button',
        },
        beforePump: (h) async {
          await h.pactRepo.savePact(rootPact);
          await h.pactRepo.savePact(midPact);
        },
      );
      final strings = l10n(tester);

      // ── 1-2. Open pact detail for "Focus Sessions" ────────────────────────
      await openPactsPanel(tester);
      await openPactDetail(tester, 'Focus Sessions');
      await h.pactDetail.scrollToKey(const Key('pact-detail-adjust-and-start-again-button'), pactId: midPact.id);

      // ── 3. Tap "Adjust and start again" ───────────────────────────────────
      await tester.tap(find.byKey(const Key('pact-detail-adjust-and-start-again-button')));
      await waitFor(tester, find.byType(PactCreationScreen));
      // Settle the push transition — see the cancelled-wizard test's comment
      // on this same pattern for why this matters once a keyed finder (not
      // just `.last`-tolerant reads) is involved.
      await tester.pumpAndSettle();

      // ── 4. Pre-filled with the root's name, not the immediate predecessor's ──
      expect(h.wizard.habitNameText, 'Vibe coding (v3)');

      // ── 5. Swipe to summary and confirm ───────────────────────────────────
      await h.wizard.swipeToSummary();
      await tester.tap(find.text(strings.createPactConfirm));
      await tester.pumpAndSettle();
      await tester.tap(find.text(strings.commitmentAccept));

      // ── 6. Verify persisted fields ─────────────────────────────────────────
      await _waitForPactCreated(h);

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
        remoteConfigOverrides: _chainingEnabled,
        beforePump: (h) async {
          await h.pactRepo.savePact(completedPact);
        },
      );

      // ── 1-2. Open pact detail; scroll to the bottom action area ─────────
      await openPactsPanel(tester);
      await openPactDetail(tester, 'Morning Run');
      await h.pactDetail.scrollToKey(const Key('pact-detail-adjust-and-start-again-button'), pactId: completedPact.id);

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
        remoteConfigOverrides: const {'pact_chaining_enabled': false},
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
        remoteConfigOverrides: _chainingEnabled,
        beforePump: (h) async {
          await h.pactRepo.savePact(cancelledPact);
        },
      );

      // ── 1-2. Open detail; tap "Adjust and start again" — wizard opens ────
      await openPactsPanel(tester);
      await openPactDetail(tester, 'Evening Walk');
      await h.pactDetail.scrollToKey(const Key('pact-detail-adjust-and-start-again-button'), pactId: cancelledPact.id);
      await tester.tap(find.byKey(const Key('pact-detail-adjust-and-start-again-button')));
      await waitFor(tester, find.byType(PactCreationScreen));
      // Settle the push transition — otherwise the outgoing and incoming
      // Cupertino nav bars are both transiently present (the transition
      // overlays them during the animation), so a keyed finder on the close
      // button ambiguously matches both mid-flight.
      await tester.pumpAndSettle();
      expect(h.wizard.habitNameText, 'Evening Walk (v2)');

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
      expect(h.pactDetail.currentPactId, cancelledPact.id);

      // ── 5. Repository still contains only the original pact ─────────────
      final allPacts = await h.pactRepo.getAllPacts();
      expect(allPacts, hasLength(1));
      expect(allPacts.single.id, cancelledPact.id);
      expect(allPacts.single.predecessorPactId, isNull);

      // ── 6. "Adjust and start again" is still visible ────────────────────
      await h.pactDetail.scrollToKey(const Key('pact-detail-adjust-and-start-again-button'), pactId: cancelledPact.id);
      expect(find.byKey(const Key('pact-detail-adjust-and-start-again-button')), findsOneWidget);
    });
  });
}
