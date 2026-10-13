import 'package:flutter/cupertino.dart' show CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'base_robot.dart';

/// Create or edit pact wizard, told apart by its PageView key prefix.
class PactWizardRobot extends BaseRobot {
  PactWizardRobot._(super.tester, {required String pageViewKeyPrefix})
      : _iosPageView = Key('$pageViewKeyPrefix-ios'),
        _androidPageView = Key('$pageViewKeyPrefix-android');

  /// Create wizard.
  PactWizardRobot.create(WidgetTester tester) : this._(tester, pageViewKeyPrefix: 'pact-creation-pageview');

  /// Edit wizard.
  PactWizardRobot.edit(WidgetTester tester) : this._(tester, pageViewKeyPrefix: 'pact-edit-pageview');

  final Key _iosPageView;
  final Key _androidPageView;

  static const _habitNameField = Key('pact-creation-habit-name-field');

  /// Swipes one page forward from the top-right title area, clear of the slider and the focused name field.
  Future<void> swipeForward() async {
    final key = find.byKey(_iosPageView).evaluate().isNotEmpty ? _iosPageView : _androidPageView;
    final rect = tester.getRect(find.byKey(key));
    await tester.timedDragFrom(
      Offset(rect.right - 10, rect.top + 40),
      const Offset(-300, 0),
      const Duration(milliseconds: 50),
    );
    await tester.pumpAndSettle();
  }

  /// Types [text] into the habit-name field, then pumps so `onChanged` lands.
  Future<void> enterHabitName(String text) async {
    await enterText(find.byKey(_habitNameField), text);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  /// Waits for the habit-name field, then settles the route slide-in before it is focused.
  Future<void> waitForHabitNameField() async {
    await waitFor(find.byKey(_habitNameField));
    await tester.pumpAndSettle();
  }

  /// Swipes to the summary page; 8 swipes since the last hops occasionally miss the snap threshold on iOS.
  Future<void> swipeToSummary() async {
    for (var i = 0; i < 8; i++) {
      await swipeForward();
    }
  }

  /// Habit-name text via the controller (the title repeats it); `.last` skips the detail screen's field underneath.
  String get habitNameText => fieldText(find.byWidgetPredicate((w) => w is TextField || w is CupertinoTextField).last);
}
