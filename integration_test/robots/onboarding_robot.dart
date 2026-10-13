import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../primitives.dart' as p;
import 'base_robot.dart';

class OnboardingRobot extends BaseRobot {
  OnboardingRobot(super.tester);

  static const _nameField = Key('enter-name-text-field');

  /// Enters [name] into EnterNameScreen's field, taps save, and waits for the page to disappear (HAB-232).
  Future<void> saveEnterName(String name) async {
    await enterText(enterNameField, name);
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

  Finder get enterNameField => find.byKey(_nameField);

  String get enterNameText => fieldText(enterNameField);

  Finder get languagePickerButton => find.byKey(const Key('language-picker-button'));

  /// Swipes slide 0 left to slide 1. 300 px stays on one page even on the <=320 dp CI AVD; 50 ms keeps fling velocity.
  Future<void> swipeToSlide1() async {
    final strings = p.l10n(tester);
    await tester.timedDrag(
      find.text(strings.onboardingSlide0Title),
      const Offset(-300, 0),
      const Duration(milliseconds: 50),
    );
    await waitFor(find.text(strings.onboardingSlide1Title));
    await tester.pumpAndSettle();
  }

  /// Swipes slide 1 right back to slide 0.
  Future<void> swipeBackToSlide0() async {
    final strings = p.l10n(tester);
    await tester.timedDrag(
      find.text(strings.onboardingSlide1Title),
      const Offset(400, 0),
      const Duration(milliseconds: 50),
    );
    await waitFor(find.text(strings.onboardingSlide0Title));
  }

  /// Taps the carousel footer's "Language" button.
  Future<void> openLanguagePicker() => tapAndSettle(find.text(p.l10n(tester).languagePickerTitle));
}
