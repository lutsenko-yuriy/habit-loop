import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/l10n/generated/app_localizations.dart';

/// Finds the [AppLocalizations] for the current widget tree.
///
/// Uses the [Navigator] element (which is inside MaterialApp's Localizations
/// widget) so that AppLocalizations.of() can walk up to the Localizations
/// ancestor and return the resolved instance.
AppLocalizations l10n(WidgetTester tester) {
  final context = tester.element(find.byType(Navigator).first);
  return AppLocalizations.of(context)!;
}

/// Pumps until [finder] has at least one match or [timeout] expires.
///
/// Prefer over a raw [WidgetTester.pumpAndSettle] when provider rebuilds or
/// async DB work may span more than one frame.
Future<void> waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = tester.binding.clock.now().add(timeout);
  while (!finder.evaluate().isNotEmpty) {
    if (tester.binding.clock.now().isAfter(deadline)) {
      throw TestFailure('waitFor timed out: $finder');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps until [finder] has no matches or [timeout] expires — the inverse of
/// [waitFor], for asserting a widget has actually been removed rather than
/// just tapped away (HAB-232).
Future<void> waitForGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = tester.binding.clock.now().add(timeout);
  while (finder.evaluate().isNotEmpty) {
    if (tester.binding.clock.now().isAfter(deadline)) {
      throw TestFailure('waitForGone timed out: still present: $finder');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Polls [condition] every 100 ms, pumping between checks; throws [TestFailure] on timeout.
Future<void> waitUntil(
  WidgetTester tester,
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
