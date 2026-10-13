import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoButton, CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../harness.dart' as harness;

/// Shared robot mechanics; domain/fake assertions stay in scenarios.
abstract class BaseRobot {
  BaseRobot(this.tester);

  final WidgetTester tester;

  /// Pumps until [finder] has a match (see the harness `waitFor`).
  Future<void> waitFor(Finder finder, {Duration timeout = const Duration(seconds: 30)}) =>
      harness.waitFor(tester, finder, timeout: timeout);

  /// Pumps until [finder] has no match (see the harness `waitForGone`).
  Future<void> waitForGone(Finder finder, {Duration timeout = const Duration(seconds: 30)}) =>
      harness.waitForGone(tester, finder, timeout: timeout);

  /// Polls [condition] every 100 ms, pumping between checks; throws [TestFailure] on timeout.
  Future<void> waitUntil(
    FutureOr<bool> Function() condition, {
    Duration timeout = const Duration(seconds: 30),
    String description = 'condition',
  }) async {
    final deadline = tester.binding.clock.now().add(timeout);
    while (!await condition()) {
      if (tester.binding.clock.now().isAfter(deadline)) {
        throw TestFailure('waitUntil timed out: $description');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Scrolls [target] into view, then settles before any tap (HAB-211).
  Future<void> scrollIntoView(Finder target, Finder scrollable, {Offset moveStep = const Offset(0, -100)}) async {
    await tester.dragUntilVisible(target, scrollable, moveStep);
    await tester.pumpAndSettle();
  }

  Future<void> scrollIntoViewAndTap(Finder target, Finder scrollable, {Offset moveStep = const Offset(0, -100)}) async {
    await scrollIntoView(target, scrollable, moveStep: moveStep);
    await tester.tap(target);
  }

  Future<void> tapAndSettle(Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Pumps past a route push transition (350 ms + 100 ms).
  Future<void> pushTransition() async {
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> enterText(Finder finder, String text) => tester.enterText(finder, text);

  /// Whether the Material or Cupertino button at [finder] has an `onPressed` handler.
  bool isEnabled(Finder finder) {
    final w = tester.widget(finder);
    if (w is ButtonStyleButton) return w.onPressed != null;
    return (w as CupertinoButton).onPressed != null;
  }

  /// Current text of the Material or Cupertino text field at [finder].
  String fieldText(Finder finder) {
    final w = tester.widget(finder);
    if (w is TextField) return w.controller?.text ?? '';
    return (w as CupertinoTextField).controller?.text ?? '';
  }
}
