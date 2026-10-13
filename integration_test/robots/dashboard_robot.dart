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

  Finder get _panelScrollable => find.byKey(const Key('pacts-panel-scrollable'));

  /// Drags the panel until [target] is built; the filter chips scroll out with the list, so [moveStep] may go up.
  Future<void> scrollPanelTo(Finder target, {Offset moveStep = const Offset(0, -100)}) =>
      tester.dragUntilVisible(target, _panelScrollable, moveStep);

  /// Toggles the "Break" filter chip.
  Future<void> toggleBreakFilter({Offset moveStep = const Offset(0, -100)}) =>
      _toggleChip(find.byKey(const Key('break-filter-chip')), moveStep);

  /// Toggles the "Active" filter chip.
  Future<void> toggleActiveFilter({Offset moveStep = const Offset(0, -100)}) =>
      _toggleChip(find.widgetWithText(FilterChip, p.l10n(tester).filterActive), moveStep);

  Future<void> _toggleChip(Finder chip, Offset moveStep) async {
    await scrollIntoView(chip, _panelScrollable, moveStep: moveStep);
    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// Opens the pact named [habitName] from the pacts panel, scrolling it into view first (HAB-211).
  Future<void> openPactDetail(String habitName) async {
    final scrollableFinder = _panelScrollable;
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

  static const _archivedRow = Key('show-archived-pacts-row');

  Future<void> waitForArchivedRow() => waitFor(find.byKey(_archivedRow));

  Future<void> scrollArchivedRowIntoView() => tester.ensureVisible(find.byKey(_archivedRow));

  /// Taps the "Archived pacts" row; default [settle] covers AnimatedSize (250 ms) + sheet _expandMax (300 ms).
  Future<void> tapArchivedRow({Duration settle = const Duration(milliseconds: 400)}) async {
    await tester.tap(find.byKey(_archivedRow));
    await tester.pump(settle);
  }

  /// Flings the drag handle up so the panel snaps to its max size.
  Future<void> flingPanelToMax() async {
    await tester.fling(find.byKey(const Key('pacts-panel-drag-handle')), const Offset(0, -300), 800);
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Taps [habitName]'s showup row; callers wait for the detail screen.
  Future<void> openShowup(String habitName) => tester.tap(find.text(habitName).first);
}
