import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'base_robot.dart';

class OnboardingRobot extends BaseRobot {
  OnboardingRobot(super.tester);

  static const _nameField = Key('enter-name-text-field');

  /// Enters [name] into EnterNameScreen's field, taps save, and waits for the page to disappear (HAB-232).
  Future<void> saveEnterName(String name) async {
    await enterText(find.byKey(_nameField), name);
    await tester.tap(find.byKey(const Key('enter-name-save-button')));
    await tester.pump();
    await waitForGone(find.byKey(_nameField));
  }

  /// Taps EnterNameScreen's skip button and waits for the page to disappear (HAB-232).
  Future<void> skipEnterName() async {
    await tester.tap(find.byKey(const Key('enter-name-skip-button')));
    await tester.pump();
    await waitForGone(find.byKey(_nameField));
  }

  String get enterNameText => fieldText(find.byKey(_nameField));
}
