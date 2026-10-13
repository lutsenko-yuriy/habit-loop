import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../primitives.dart' as p;
import 'base_robot.dart';

/// The Checklist section of pact detail.
class ChecklistRobot extends BaseRobot {
  ChecklistRobot(super.tester);

  Finder get selectButton => find.byKey(const Key('pact-checklist-select-button'));
  Finder get changeButton => find.byKey(const Key('pact-checklist-change-button'));
  Finder get removeButton => find.byKey(const Key('pact-checklist-remove-button'));

  Finder get sectionTitle => find.text(p.l10n(tester).pactChecklistSectionTitle.toUpperCase());

  Finder get noChecklistsError => find.text(p.l10n(tester).pactChecklistNoChecklistsError);

  /// The linked checklist's name in the section.
  Finder linkedName(String name) => find.text(name);

  Future<void> waitForLinkedName(String name) => waitFor(linkedName(name));

  Future<void> waitForNoChecklistsError() => waitFor(noChecklistsError);

  /// Scrolls [finder] into view in the list of [pactId]; the section sits below the fold on short viewports.
  Future<void> _bringIntoView(Finder finder, String pactId) async {
    final scrollView = find.byKey(Key('pact-detail-scroll-view-$pactId'));
    await waitFor(scrollView);
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.descendant(of: scrollView, matching: find.byType(Scrollable)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollToSelect(String pactId) => _bringIntoView(selectButton, pactId);

  Future<void> scrollToChange(String pactId) => _bringIntoView(changeButton, pactId);

  Future<void> tapSelect() => tapAndSettle(selectButton);

  Future<void> tapChange() => tapAndSettle(changeButton);

  Future<void> tapRemove() => tapAndSettle(removeButton);
}
