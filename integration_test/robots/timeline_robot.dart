import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../primitives.dart' as p;
import 'base_robot.dart';

class TimelineRobot extends BaseRobot {
  TimelineRobot(super.tester);

  /// The timeline tile of [showupId].
  Finder milestone(String showupId) => find.byKey(Key('timeline-milestone-$showupId'));

  /// Waits until the timeline screen title is shown.
  Future<void> waitLoaded() => waitFor(find.textContaining(p.l10n(tester).pactTimelineTitle));

  /// Opens the detail of [showupId] from its timeline tile and pumps past the push.
  Future<void> openShowupDetail(String showupId) async {
    await waitFor(milestone(showupId));
    await tester.tap(milestone(showupId));
    await pushTransition();
  }
}
