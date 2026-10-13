import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'base_robot.dart';

class BreakRobot extends BaseRobot {
  BreakRobot(super.tester);

  static const _submitButton = Key('break-submit-button');

  /// Taps "Start break" on showup detail and pumps past the push.
  Future<void> startFromShowupDetail() async {
    await tester.tap(find.byKey(const Key('showup-detail-start-break-button')));
    await pushTransition();
  }

  /// Toggles "Until pact ends", then settles the end-date row's AnimatedSwitcher collapse.
  Future<void> toggleUntilPactEnds() async {
    await tester.tap(find.byKey(const Key('break-until-pact-ends-switch')));
    await tester.pumpAndSettle();
  }

  /// Taps Submit as-is; callers assert whether the screen popped.
  Future<void> tapSubmit() async {
    await tester.tap(find.byKey(_submitButton));
    await tester.pump(const Duration(milliseconds: 350));
  }

  /// Types [rationale] and submits; drags to Submit since the HAB-215 hint row pushes it past the realized extent.
  Future<void> enterRationaleAndSubmit(String rationale) async {
    await enterText(find.byKey(const Key('break-rationale-field')), rationale);
    await tester.dragUntilVisible(find.byKey(_submitButton), find.byType(ListView), const Offset(0, -100));
    await tester.pump();
    await tester.tap(find.byKey(_submitButton));
    await tester.pump(const Duration(milliseconds: 450));
  }
}
