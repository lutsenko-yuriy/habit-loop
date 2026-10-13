import 'package:flutter/cupertino.dart' show CupertinoButton;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../primitives.dart' as p;
import 'base_robot.dart';

class PactDetailRobot extends BaseRobot {
  PactDetailRobot(super.tester);

  /// Pact detail's own list; a bare ListView finder also hits the pacts panel underneath.
  Finder get _scrollView => find.byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> && key.value.startsWith('pact-detail-scroll-view-');
      });

  /// Waits until the pact detail content has rendered (its stats section is near the top).
  Future<void> waitLoaded() => waitFor(find.text(p.l10n(tester).sectionStats.toUpperCase()));

  Finder get _statsScrollable => find.ancestor(
        of: find.text(p.l10n(tester).sectionStats.toUpperCase()),
        matching: find.byType(Scrollable),
      );

  /// Scrolls "Stop Pact" at the bottom of the list into view.
  Future<void> scrollToStopPact() async {
    await tester.scrollUntilVisible(find.text(p.l10n(tester).stopPact), 200.0, scrollable: _statsScrollable);
  }

  /// Scrolls back up to [text]; the list keeps its position after the edit wizard pops.
  Future<void> scrollUpTo(String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      -200.0,
      scrollable: find.ancestor(of: find.text(p.l10n(tester).stopPact), matching: find.byType(Scrollable)),
    );
  }

  /// Invokes the edit button's `onPressed` directly; its hit target can sit off-screen on narrow devices.
  Future<void> openEdit() async {
    const key = Key('pact-detail-edit-button');
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      tester.widget<CupertinoButton>(find.byKey(key)).onPressed?.call();
    } else {
      tester.widget<IconButton>(find.byKey(key)).onPressed?.call();
    }
    // No pumpAndSettle: the edit screen's spinner never settles while loading.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

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
    await scrollIntoViewAndTap(find.byKey(const Key('pact-detail-timeline-button')), listViewFinder);
    await pushTransition();
  }
}
