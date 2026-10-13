import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart' as harness;
import 'base_robot.dart';

class PactDetailRobot extends BaseRobot {
  PactDetailRobot(super.tester);

  /// Pact detail's own list, keyed `pact-detail-scroll-view-<originalPactId ?? pactId>`.
  ///
  /// An unscoped ListView finder also matched the pacts panel's list still mounted underneath (GH-476).
  Finder get _scrollView => find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> && key.value.startsWith('pact-detail-scroll-view-');
      });

  /// Waits until the pact detail content has rendered (its stats section is near the top).
  Future<void> waitLoaded() => waitFor(find.text(harness.l10n(tester).sectionStats.toUpperCase()));

  /// Scrolls pact detail's "Take a break" button into view from an already-open pact detail screen.
  ///
  /// The button sits below the timeline button and several DateRowTiles in
  /// pact detail's sliver-backed ListView — on a short viewport (CI's Android
  /// emulator) it isn't realized yet, so waitFor alone can time out even
  /// though the widget legitimately exists once scrolled into range (HAB-199,
  /// same root cause as HAB-196 Fix 4).
  ///
  /// Anchors on the pact detail list rather than a nearby widget so the helper doesn't
  /// depend on `pact_timeline_enabled`, and not the broader `Scrollable` — a focused
  /// `TextField` has its own internal `Scrollable` too (HAB-211).
  Future<void> scrollToStartBreakButton() async {
    await tester.dragUntilVisible(
      find.byKey(const Key('pact-detail-start-break-button')),
      _scrollView,
      const Offset(0, -100),
    );
  }

  /// Opens the timeline screen from an already-open pact detail screen.
  ///
  /// Resets scroll position to the top first — a caller that scrolled down
  /// for an earlier interaction (e.g. editing the note field, which sits
  /// *below* the timeline button) would otherwise have this scroll the wrong
  /// direction: `dragUntilVisible`'s single fixed direction can't recover
  /// from starting already past the target (HAB-211, confirmed via CI
  /// diagnostics — the button was always present in the tree with
  /// pactTimelineEnabled=true, just never scrolled back into range).
  Future<void> openTimeline() async {
    final listViewFinder = _scrollView;
    for (var i = 0; i < 15; i++) {
      await tester.drag(listViewFinder, const Offset(0, 100));
      await tester.pump();
    }
    // dragUntilVisible (not waitFor + ensureVisible) — the button only appears
    // once the view model has resolved *and* it may sit below several
    // DateRowTiles on a short viewport (CI's Android emulator), where it isn't
    // realized yet; ensureVisible can't scroll a not-yet-built lazy-list child
    // into view (HAB-211, same root cause as HAB-196/HAB-199).
    await tester.dragUntilVisible(
      find.byKey(const Key('pact-detail-timeline-button')),
      listViewFinder,
      const Offset(0, -100),
    );
    // dragUntilVisible's found-check only confirms the element exists in the
    // tree — a lazy list's cache extent can pre-build an item before it's
    // actually painted at a stable on-screen position, so an immediate tap's
    // hit-test can still miss on a real device (HAB-211). Settle first.
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pact-detail-timeline-button')));
    await pushTransition();
  }
}
