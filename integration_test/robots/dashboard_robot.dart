import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../primitives.dart' as p;
import 'base_robot.dart';

class DashboardRobot extends BaseRobot {
  DashboardRobot(super.tester);

  static const _changeNameField = Key('change-name-text-field');

  /// Opens the collapsible pacts panel from the dashboard.
  Future<void> openPactsPanel() async {
    await tester.tap(find.byKey(const Key('pacts-panel-drag-handle')));
    // Flush the tap before the 400 ms expand animation starts.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Expands the pacts panel by tapping its "[activeCount] active" summary, then waits for [habitName] to appear.
  Future<void> expandPactsPanelViaSummary(String habitName, {int activeCount = 1}) async {
    // The summary is one multi-line Text, so match by substring.
    final summaryFinder = find.textContaining(p.l10n(tester).pactsActive(activeCount));
    expect(summaryFinder, findsOneWidget);
    await tester.tap(summaryFinder);
    await tester.pump(const Duration(milliseconds: 400));
    await waitFor(find.text(habitName));
  }

  /// Opens the pact named [habitName] from the pacts panel, scrolling it into view first (HAB-211).
  Future<void> openPactDetail(String habitName) async {
    final scrollableFinder = find.byKey(const Key('pacts-panel-scrollable'));
    // Scoped to the panel: the name can also appear in today's list (HAB-211).
    final panelEntryFinder = find.descendant(of: scrollableFinder, matching: find.text(habitName));
    await scrollIntoView(panelEntryFinder, scrollableFinder);
    await tester.tap(panelEntryFinder.last);
    await pushTransition();
  }

  /// Opens the ⋯ kebab menu and taps "Change name" (HAB-232 WU5).
  Future<void> openChangeNameDialog() async {
    await tester.tap(find.byKey(const Key('kebab-menu-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('change-name-button')));
    await tester.pumpAndSettle();
  }

  /// Saves [name] in the "Change name" dialog (HAB-232 WU5).
  Future<void> saveChangeName(String name) async {
    await enterText(find.byKey(_changeNameField), name);
    await tester.pump(); // rebuild so a (now non-empty) field re-enables Save
    await tester.tap(find.byKey(const Key('change-name-save-button')));
    await tester.pump();
    await waitForGone(find.byKey(_changeNameField));
  }

  String get changeNameText => fieldText(find.byKey(_changeNameField));
}
