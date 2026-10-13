import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../primitives.dart' as p;
import 'base_robot.dart';

class ShowupDetailRobot extends BaseRobot {
  ShowupDetailRobot(super.tester);

  static const _redeemButton = Key('showup-redeem-button');
  static const _runChecklistButton = Key('showup-run-checklist-button');
  static const _noteField = Key('showup-note-field');
  static const _saveNoteButton = Key('showup-note-save-button');

  /// Waits until the showup detail title is shown.
  Future<void> waitLoaded() => waitFor(find.text(p.l10n(tester).showupDetailTitle));

  /// Taps "Mark as done" and settles.
  Future<void> markDone() async {
    await waitFor(markDoneButton);
    await tapAndSettle(markDoneButton);
  }

  Finder get markDoneButton => find.text(p.l10n(tester).markDone);

  Future<void> waitForMarkDone() => waitFor(markDoneButton);

  Finder get doneStatus => find.text(p.l10n(tester).showupDone);
  Finder get failedStatus => find.text(p.l10n(tester).showupFailed);
  Finder get viewPactDetailsLink => find.text(p.l10n(tester).showupViewPactDetails);

  /// Taps "View pact details"; callers wait for the pact detail to load.
  Future<void> viewPactDetails() => tester.tap(viewPactDetailsLink);

  Finder get markFailedButton => find.text(p.l10n(tester).markFailed);

  /// Waits for "Mark as failed", taps it and settles.
  Future<void> markFailed() async {
    await waitForMarkFailed();
    await tapAndSettle(markFailedButton);
  }

  /// Waits for "Mark as failed", which renders once the pending showup has loaded.
  Future<void> waitForMarkFailed() => waitFor(markFailedButton);

  Finder get runChecklistButton => find.byKey(_runChecklistButton);

  Future<void> waitForRunChecklist() => waitFor(runChecklistButton);

  /// Taps "Run checklist" and settles.
  Future<void> tapRunChecklist() => tapAndSettle(runChecklistButton);

  Future<void> waitForRedeemButton() => waitFor(find.byKey(_redeemButton));

  Finder get redeemButton => find.byKey(_redeemButton);

  bool get isRedeemEnabled => isEnabled(find.byKey(_redeemButton));

  /// Taps the redeem button, then pumps past the status update.
  Future<void> redeem() async {
    await tester.tap(find.byKey(_redeemButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> enterNote(String text) async {
    await enterText(find.byKey(_noteField), text);
    await tester.pump();
  }

  /// Scrolls Save into view (it can sit below the fold on short viewports), taps it and pumps past the write.
  Future<void> saveNote() async {
    final scrollable = find.ancestor(of: find.byKey(_noteField), matching: find.byType(Scrollable));
    await tester.dragUntilVisible(find.byKey(_saveNoteButton), scrollable, const Offset(0, -100));
    await tester.pump();
    await tester.tap(find.byKey(_saveNoteButton));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }
}
