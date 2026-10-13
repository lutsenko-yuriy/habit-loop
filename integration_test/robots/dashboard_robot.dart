import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'base_robot.dart';

class DashboardRobot extends BaseRobot {
  DashboardRobot(super.tester);

  static const _changeNameField = Key('change-name-text-field');

  /// Opens the collapsible pacts panel from the dashboard.
  Future<void> openPactsPanel() async {
    await tester.tap(find.byKey(const Key('pacts-panel-drag-handle')));
    // Bare pump flushes the tap handler synchronously before the 400 ms animation
    // clock starts — without this the panel may still be collapsed on entry.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Opens the detail screen for the pact named [habitName] from the pacts panel.
  ///
  /// Scrolls the panel's list into view first — on a short viewport (CI's
  /// Android emulator) a pact further down the list isn't realized yet, so a
  /// bare waitFor can time out even though it legitimately exists once
  /// scrolled into range (HAB-211, same root cause as HAB-196/HAB-199).
  Future<void> openPactDetail(String habitName) async {
    final scrollableFinder = find.byKey(const Key('pacts-panel-scrollable'));
    // Scoped to the panel, not a bare find.text(habitName) — the same habit
    // name can also appear in the dashboard's "today" todo list, and
    // dragUntilVisible's internal Scrollable.ensureVisible(element(finder))
    // calls finder.evaluate().single, which throws on that ambiguity even
    // though the tap below already disambiguates via .last (HAB-211).
    final panelEntryFinder = find.descendant(of: scrollableFinder, matching: find.text(habitName));
    await tester.dragUntilVisible(panelEntryFinder, scrollableFinder, const Offset(0, -100));
    // dragUntilVisible's found-check only confirms the element exists in the
    // tree — a lazy list's cache extent can pre-build an item before it's
    // actually painted at a stable on-screen position, so an immediate tap's
    // hit-test can still miss on a real device (HAB-211). Settle first.
    await tester.pumpAndSettle();
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

  /// Enters [name] into the "Change name" dialog, taps Save, and waits for the dialog to disappear (HAB-232 WU5).
  Future<void> saveChangeName(String name) async {
    await tester.enterText(find.byKey(_changeNameField), name);
    await tester.pump(); // rebuild so a (now non-empty) field re-enables Save
    await tester.tap(find.byKey(const Key('change-name-save-button')));
    await tester.pump();
    await waitForGone(find.byKey(_changeNameField));
  }

  String get changeNameText => fieldText(find.byKey(_changeNameField));
}
