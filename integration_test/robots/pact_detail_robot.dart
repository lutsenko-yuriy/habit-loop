import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart' as harness;
import 'base_robot.dart';

class PactDetailRobot extends BaseRobot {
  PactDetailRobot(super.tester);

  /// Pact detail's own list; a bare ListView finder also hits the pacts panel underneath.
  Finder get _scrollView => find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> && key.value.startsWith('pact-detail-scroll-view-');
      });

  /// Waits until the pact detail content has rendered (its stats section is near the top).
  Future<void> waitLoaded() => waitFor(find.text(harness.l10n(tester).sectionStats.toUpperCase()));

  /// Scrolls the "Take a break" button into view; it isn't built yet on short viewports (HAB-199).
  Future<void> scrollToStartBreakButton() async {
    await tester.dragUntilVisible(
      find.byKey(const Key('pact-detail-start-break-button')),
      _scrollView,
      const Offset(0, -100),
    );
  }

  /// Opens the timeline, scrolling back to the top first since dragUntilVisible scrolls one way only (HAB-211).
  Future<void> openTimeline() async {
    final listViewFinder = _scrollView;
    for (var i = 0; i < 15; i++) {
      await tester.drag(listViewFinder, const Offset(0, 100));
      await tester.pump();
    }
    // dragUntilVisible, not ensureVisible: the button may not be built yet (HAB-211).
    await tester.dragUntilVisible(
      find.byKey(const Key('pact-detail-timeline-button')),
      listViewFinder,
      const Offset(0, -100),
    );
    // Settle first: a pre-built lazy-list item may not be painted in place yet (HAB-211).
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pact-detail-timeline-button')));
    await pushTransition();
  }
}
