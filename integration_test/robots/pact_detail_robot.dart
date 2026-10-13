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

  /// The [Scrollable] inside [_scrollView], as `scrollUntilVisible` requires.
  Finder get _scrollable => find.descendant(of: _scrollView, matching: find.byType(Scrollable)).first;

  /// Scrolls "Stop Pact" at the bottom of the list into view.
  Future<void> scrollToStopPact() async {
    await tester.scrollUntilVisible(find.text(p.l10n(tester).stopPact), 200.0, scrollable: _scrollable);
  }

  /// Scrolls back up to [text]; the list keeps its position after the edit wizard pops.
  Future<void> scrollUpTo(String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      -200.0,
      scrollable: _scrollable,
    );
  }

  /// Invokes the edit button's `onPressed` directly; its hit target can sit off-screen on narrow devices.
  Future<void> openEdit() async {
    invokeOnPressed(find.byKey(const Key('pact-detail-edit-button')));
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

  /// Taps "Stop Pact" at the bottom of the list, leaving the confirm dialog open.
  Future<void> stopPact() async {
    await scrollToStopPact();
    // scrollUntilVisible can stop just past the viewport edge on taller layouts.
    await tester.ensureVisible(find.text(p.l10n(tester).stopPact));
    await tester.pumpAndSettle();
    await tapAndSettle(find.text(p.l10n(tester).stopPact));
  }

  /// Confirms the stop-pact dialog.
  Future<void> confirmStopPact() => tapAndSettle(find.text(p.l10n(tester).stopPactConfirm));

  Finder get _noteField => find.byKey(const Key('pact-note-field'));
  Finder get _saveNoteButton => find.byKey(const Key('pact-note-save-button'));

  /// Scrolls the note field into view; it isn't built yet in the lazy list.
  Future<void> scrollToNoteField() async {
    await tester.scrollUntilVisible(_noteField, 200.0, scrollable: _scrollable);
    // Settle: mid-scroll the hit-test can miss the field (HAB-258).
    await tester.pumpAndSettle();
  }

  /// Types [text] and waits for Save to enable; the rebuild can take seconds on CI (HAB-211).
  Future<void> enterNote(String text) async {
    await enterText(_noteField, text);
    await waitUntil(
      () => isSaveNoteEnabled,
      timeout: const Duration(seconds: 45),
      description: 'save note button enabled for "$text"',
    );
  }

  /// Taps Save, then returns without settling; callers wait on the repo write.
  Future<void> tapSaveNote() async {
    await tester.ensureVisible(_saveNoteButton);
    // Settle: the scroll may still animate and an early tap would miss (HAB-258).
    await tester.pumpAndSettle();
    await tester.tap(_saveNoteButton);
    await tester.pump();
  }

  String get noteText => fieldText(_noteField);

  bool get isSaveNoteEnabled => isEnabled(_saveNoteButton);
}
