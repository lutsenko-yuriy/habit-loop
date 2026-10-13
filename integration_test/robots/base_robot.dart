import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoButton, CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../primitives.dart' as p;

/// Shared robot mechanics; domain/fake assertions stay in scenarios.
abstract class BaseRobot {
  BaseRobot(this.tester);

  final WidgetTester tester;

  /// See the top-level `waitFor`.
  Future<void> waitFor(Finder finder, {Duration timeout = const Duration(seconds: 30)}) =>
      p.waitFor(tester, finder, timeout: timeout);

  /// See the top-level `waitForGone`.
  Future<void> waitForGone(Finder finder, {Duration timeout = const Duration(seconds: 30)}) =>
      p.waitForGone(tester, finder, timeout: timeout);

  /// See the top-level `waitUntil`.
  Future<void> waitUntil(
    FutureOr<bool> Function() condition, {
    Duration timeout = const Duration(seconds: 30),
    String description = 'condition',
  }) =>
      p.waitUntil(tester, condition, timeout: timeout, description: description);

  /// Scrolls [target] into view, then settles: a pre-built lazy-list item may not be painted in place yet (HAB-211).
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

  /// Backgrounds and resumes the app; the install watcher throttles to 5 s of wall-clock time, so real time passes first.
  Future<void> backgroundAndResume() async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 5100)));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  Future<void> enterText(Finder finder, String text) => tester.enterText(finder, text);

  /// Whether the Material or Cupertino button at [finder] has an `onPressed` handler.
  bool isEnabled(Finder finder) => _onPressed(finder) != null;

  /// Calls the button's `onPressed` directly, for buttons whose hit target can sit off-screen.
  void invokeOnPressed(Finder finder) => _onPressed(finder)?.call();

  VoidCallback? _onPressed(Finder finder) => switch (tester.widget(finder)) {
        final ButtonStyleButton w => w.onPressed,
        final IconButton w => w.onPressed,
        final CupertinoButton w => w.onPressed,
        final w => throw ArgumentError('Unsupported button: ${w.runtimeType}'),
      };

  /// Current text of the Material or Cupertino text field at [finder].
  String fieldText(Finder finder) {
    final w = tester.widget(finder);
    if (w is TextField) return w.controller?.text ?? '';
    return (w as CupertinoTextField).controller?.text ?? '';
  }
}
