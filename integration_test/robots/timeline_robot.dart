import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'base_robot.dart';

class TimelineRobot extends BaseRobot {
  TimelineRobot(super.tester);

  /// Opens the detail of [showupId] from its timeline tile and pumps past the push.
  Future<void> openShowupDetail(String showupId) async {
    final tile = find.byKey(Key('timeline-milestone-$showupId'));
    await waitFor(tile);
    await tester.tap(tile);
    await pushTransition();
  }
}
