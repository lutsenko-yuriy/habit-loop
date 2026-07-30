// Integration tests for pact chaining (HAB-202): creating a new pact from a
// finished one via "Adjust and start again", with Previous/Next navigation
// links between predecessor and successor.
//
// Run on host:   flutter test integration_test/pact_chain_test.dart
// Run on device: flutter test integration_test/pact_chain_test.dart -d <device>
import 'package:flutter/material.dart' show Key, Offset, Scrollable;
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/pact/pact_status.dart';
import 'package:habit_loop/infrastructure/injections/app_providers.dart';
import 'package:habit_loop/slices/pact/ui/generic/pact_detail_screen.dart';
import 'package:integration_test/integration_test.dart';

import '../test/infrastructure/remote_config/fake_remote_config_service.dart';
import 'harness.dart';

// pact_chaining_enabled defaults to false while the feature is mid-rollout
// (see docs/FEATURE_TOGGLES.md) — scenarios that exercise the links need it on.
final _chainingEnabled = remoteConfigServiceProvider.overrideWithValue(
  FakeRemoteConfigService(overrides: {'pact_chaining_enabled': true}),
);

const _predecessorId = 'chain-nav-predecessor';
const _successorId = 'chain-nav-successor';

// Dated near 2099 (short spans, matching every other integration-test
// fixture in this suite) rather than the ticket's illustrative 2026 dates —
// buildPact's default endDate is 2099-12-31, so a near-term startDate here
// would produce a ~74-year pact span and force ShowupGenerator to compute
// tens of thousands of daily occurrences on every load (HAB-202 debugging
// note, 2026-07-30: this was the actual cause of an apparent test hang).
final _predecessorPact = buildPact(
  id: _predecessorId,
  habitName: 'Vibe coding',
  startDate: DateTime(2099, 1, 1),
  endDate: DateTime(2099, 6, 1),
  status: PactStatus.stopped,
  stoppedAt: DateTime(2099, 3, 1),
);

final _successorPact = buildPact(
  id: _successorId,
  habitName: 'Vibe coding (v2)',
  startDate: DateTime(2099, 3, 2),
  endDate: DateTime(2099, 9, 2),
  predecessorPactId: _predecessorId,
);

/// The pactId of the topmost mounted [PactDetailScreen] — i.e. the one
/// currently visible. Earlier routes stay mounted underneath a pushed one
/// (Navigator's default `maintainState: true`), so `find.text(habitName)`
/// matches both the visible screen's title and the pacts-panel row still
/// mounted behind it; this reads the unambiguous `pactId` field instead.
String _currentDetailPactId(WidgetTester tester) =>
    tester.widgetList<PactDetailScreen>(find.byType(PactDetailScreen)).last.pactId;

Future<void> _tapPreviousPactLink(WidgetTester tester) async {
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
Future<void> _tapNextPactLink(WidgetTester tester, {required String currentPactId}) async {
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
  // pumpAndSettle — see _tapPreviousPactLink's comment; this link can
  // trigger either a push or a pop depending on cameFromPactId, and both
  // need their transition to fully finish before asserting.
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppHarness.initForHost);

  group('Pact chain — adjust and start again', () {
    // TODO: declare `late AppHarness h;` and `tearDown(() => h.dispose());` when filling in stubs.

    testWidgets('adjust_and_start_again_creates_chained_pact_with_prefill_and_backlink', (tester) async {
      // TODO: 1. Seed a stopped pact "Vibe coding" with a known schedule, showup
      //          duration, and reminder offset.
      // TODO: 2. Open its pact detail screen; scroll to the bottom action area;
      //          verify "Adjust and start again" is visible.
      // TODO: 3. Tap it — wizard opens.
      // TODO: 4. Verify the habit-name field is pre-filled with "Vibe coding (v2)".
      // TODO: 5. Swipe through the wizard to the summary step and confirm creation
      //          (handle the commitment dialog if shown).
      // TODO: 6. Wait for the pact-created signal, then verify in the repository:
      //          new pact's habitName is "Vibe coding (v2)", predecessorPactId
      //          equals the original pact's id, schedule/showupDuration/
      //          reminderOffset match the predecessor, and startDate is today
      //          (not carried over from the predecessor).
      // TODO: 7. Navigate to the new pact's detail screen; verify
      //          "Previous Pact: 'Vibe coding'" link appears under the habit
      //          name/status badge.
      // TODO: 8. Tap the link — navigates to the predecessor's detail screen.
      // TODO: 9. On the predecessor's detail screen, verify "Adjust and start
      //          again" is gone, replaced by "Next Pact: 'Vibe coding (v2)'" in
      //          the bottom action area.
      // TODO: 10. Tap that link — navigates back to the successor's detail screen.
    });
  });

  group('Pact chain — navigation stack', () {
    late AppHarness h;
    tearDown(() => h.dispose());
    // Both scenarios below use P_p (predecessor / "parent") and P_c (successor
    // / "child"): P_c.predecessorPactId == P_p.id. They verify that bouncing
    // between "Previous Pact"/"Next Pact" links pops back to the existing page
    // instance instead of pushing a duplicate — so the back stack never grows
    // past however deep the user has actually gone in one direction.

    testWidgets('chain_navigation_previous_then_next_returns_to_same_page_instance', (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [_chainingEnabled],
        beforePump: (h) async {
          await h.pactRepo.savePact(_predecessorPact);
          await h.pactRepo.savePact(_successorPact);
        },
      );

      await openPactsPanel(tester);
      await openPactDetail(tester, 'Vibe coding (v2)');

      // ── 3. P_c's detail screen is shown ───────────────────────────────────
      expect(_currentDetailPactId(tester), _successorId);

      // ── 4. Tap "Previous Pact" — P_p's detail screen pushed on top ────────
      await _tapPreviousPactLink(tester);
      expect(_currentDetailPactId(tester), _predecessorId);

      // ── 5. Tap "Next Pact" — back to P_c ──────────────────────────────────
      await _tapNextPactLink(tester, currentPactId: _predecessorId);
      expect(_currentDetailPactId(tester), _successorId);

      // ── 6. A single pop lands directly on the Pacts List, proving step 5
      //        popped back to the original P_c page instance rather than
      //        pushing a second copy of it. ─────────────────────────────────
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pacts-panel-drag-handle')), findsOneWidget);
      expect(find.byType(PactDetailScreen), findsNothing);
    });

    testWidgets('chain_navigation_next_then_previous_returns_to_same_page_instance', (tester) async {
      h = await AppHarness.create(
        tester,
        extraOverrides: [_chainingEnabled],
        beforePump: (h) async {
          await h.pactRepo.savePact(_predecessorPact);
          await h.pactRepo.savePact(_successorPact);
        },
      );

      await openPactsPanel(tester);
      await openPactDetail(tester, 'Vibe coding');

      // ── 3. P_p's detail screen is shown ───────────────────────────────────
      expect(_currentDetailPactId(tester), _predecessorId);

      // ── 4. Tap "Next Pact" — P_c's detail screen pushed on top ────────────
      await _tapNextPactLink(tester, currentPactId: _predecessorId);
      expect(_currentDetailPactId(tester), _successorId);

      // ── 5. Tap "Previous Pact" — back to P_p ──────────────────────────────
      await _tapPreviousPactLink(tester);
      expect(_currentDetailPactId(tester), _predecessorId);

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
    // TODO: declare `late AppHarness h;` and `tearDown(() => h.dispose());` when filling in stubs.

    testWidgets('chained_default_name_uses_root_habit_name_not_immediate_predecessor', (tester) async {
      // TODO: 1. Seed a chain: root pact "Vibe coding" (id A, stopped), successor
      //          pact renamed to "Focus Sessions" (id B, stopped,
      //          predecessorPactId=A).
      // TODO: 2. Open pact detail for "Focus Sessions".
      // TODO: 3. Tap "Adjust and start again".
      // TODO: 4. Verify the habit-name field is pre-filled with "Vibe coding (v3)"
      //          (derived from the root's name, not "Focus Sessions").
      // TODO: 5. Swipe to summary and confirm creation.
      // TODO: 6. Verify in the repository: new pact's habitName is
      //          "Vibe coding (v3)", predecessorPactId equals B's id.
    });
  });

  group('Pact chain — completed pact eligibility', () {
    // TODO: declare `late AppHarness h;` and `tearDown(() => h.dispose());` when filling in stubs.

    testWidgets('adjust_and_start_again_available_from_completed_pact', (tester) async {
      // TODO: 1. Seed a completed pact "Morning Run".
      // TODO: 2. Open its pact detail screen; scroll to the bottom action area.
      // TODO: 3. Verify "Adjust and start again" is visible.
    });
  });

  group('Pact chain — feature flag', () {
    // TODO: declare `late AppHarness h;` and `tearDown(() => h.dispose());` when filling in stubs.

    testWidgets('flag_off_hides_adjust_button_and_chain_links', (tester) async {
      // TODO: 1. Seed a chain: predecessor "Old Habit" (stopped, id A) and
      //          successor "New Habit" (predecessorPactId=A) saved directly via
      //          the repo.
      // TODO: 2. Override remote config with pact_chaining_enabled: false.
      // TODO: 3. Open predecessor's detail screen — verify "Adjust and start
      //          again" is absent and "Next Pact" link is absent.
      // TODO: 4. Navigate back; open successor's detail screen — verify
      //          "Previous Pact" link is absent.
    });
  });

  group('Pact chain — cancelled wizard', () {
    // TODO: declare `late AppHarness h;` and `tearDown(() => h.dispose());` when filling in stubs.

    testWidgets('abandoning_adjust_wizard_leaves_predecessor_unchanged', (tester) async {
      // TODO: 1. Seed a stopped pact "Evening Walk".
      // TODO: 2. Open its pact detail screen; tap "Adjust and start again" —
      //          wizard opens pre-filled.
      // TODO: 3. Back out of the wizard without confirming (system/back-button
      //          pop).
      // TODO: 4. Verify navigation returns to the predecessor's pact detail
      //          screen.
      // TODO: 5. Verify the repository still contains only the original pact (no
      //          new pact, no predecessorPactId link created).
      // TODO: 6. Verify "Adjust and start again" is still visible on the
      //          predecessor's detail screen.
    });
  });
}
