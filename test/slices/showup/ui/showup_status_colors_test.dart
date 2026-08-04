import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/domain/showup/showup_status.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_status_colors.dart';
import 'package:habit_loop/slices/showup/ui/generic/showup_ui_state.dart';
import 'package:habit_loop/theme/colors.dart';

void main() {
  // Helper to pump a widget under a CupertinoTheme and capture the BuildContext.
  Future<BuildContext> buildContext(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
  }) async {
    late BuildContext captured;
    await tester.pumpWidget(
      CupertinoApp(
        theme: CupertinoThemeData(brightness: brightness),
        home: Builder(builder: (ctx) {
          captured = ctx;
          return const SizedBox.shrink();
        }),
      ),
    );
    return captured;
  }

  group('ShowupStatusColors — Cupertino resolved palette', () {
    testWidgets('forStatus maps done → resolved activeGreen', (tester) async {
      final ctx = await buildContext(tester);
      final colors = ShowupStatusColors.cupertino(ctx);
      expect(colors.forStatus(ShowupStatus.done), CupertinoColors.activeGreen.resolveFrom(ctx));
    });

    testWidgets('forStatus maps failed → resolved destructiveRed', (tester) async {
      final ctx = await buildContext(tester);
      final colors = ShowupStatusColors.cupertino(ctx);
      expect(colors.forStatus(ShowupStatus.failed), CupertinoColors.destructiveRed.resolveFrom(ctx));
    });

    testWidgets('forStatus maps pending → resolved systemGrey', (tester) async {
      final ctx = await buildContext(tester);
      final colors = ShowupStatusColors.cupertino(ctx);
      expect(colors.forStatus(ShowupStatus.pending), CupertinoColors.systemGrey.resolveFrom(ctx));
    });

    testWidgets('done colour differs between light and dark mode', (tester) async {
      final lightCtx = await buildContext(tester, brightness: Brightness.light);
      final lightDone = ShowupStatusColors.cupertino(lightCtx).done;

      final darkCtx = await buildContext(tester, brightness: Brightness.dark);
      final darkDone = ShowupStatusColors.cupertino(darkCtx).done;

      expect(lightDone, isNot(equals(darkDone)));
    });

    testWidgets('failed colour differs between light and dark mode', (tester) async {
      final lightCtx = await buildContext(tester, brightness: Brightness.light);
      final lightFailed = ShowupStatusColors.cupertino(lightCtx).failed;

      final darkCtx = await buildContext(tester, brightness: Brightness.dark);
      final darkFailed = ShowupStatusColors.cupertino(darkCtx).failed;

      expect(lightFailed, isNot(equals(darkFailed)));
    });

    testWidgets('pending colour is the resolved systemGrey for the current brightness', (tester) async {
      final lightCtx = await buildContext(tester, brightness: Brightness.light);
      final pendingLight = ShowupStatusColors.cupertino(lightCtx).pending;
      // Verify the pending colour is the correctly resolved systemGrey, not the raw unresolved Color.
      expect(pendingLight, CupertinoColors.systemGrey.resolveFrom(lightCtx));
    });

    testWidgets('overflow is grey while any showup is pending', (tester) async {
      final ctx = await buildContext(tester);
      final colors = ShowupStatusColors.cupertino(ctx);
      expect(
        colors.overflow(doneCount: 2, failedCount: 1, pendingCount: 1),
        CupertinoColors.systemGrey.resolveFrom(ctx),
      );
      expect(
        colors.overflow(doneCount: 0, failedCount: 0, pendingCount: 4),
        CupertinoColors.systemGrey.resolveFrom(ctx),
      );
    });

    testWidgets('overflow is green when resolved and done >= failed', (tester) async {
      final ctx = await buildContext(tester);
      final colors = ShowupStatusColors.cupertino(ctx);
      expect(
        colors.overflow(doneCount: 2, failedCount: 2, pendingCount: 0),
        CupertinoColors.activeGreen.resolveFrom(ctx),
      );
      expect(
        colors.overflow(doneCount: 4, failedCount: 0, pendingCount: 0),
        CupertinoColors.activeGreen.resolveFrom(ctx),
      );
    });

    testWidgets('overflow is red when resolved and failed > done', (tester) async {
      final ctx = await buildContext(tester);
      final colors = ShowupStatusColors.cupertino(ctx);
      expect(
        colors.overflow(doneCount: 1, failedCount: 3, pendingCount: 0),
        CupertinoColors.destructiveRed.resolveFrom(ctx),
      );
    });

    testWidgets('forUiState maps onBreak → resolved systemBlue', (tester) async {
      final ctx = await buildContext(tester);
      final colors = ShowupStatusColors.cupertino(ctx);
      expect(colors.forUiState(ShowupUiState.onBreak), CupertinoColors.systemBlue.resolveFrom(ctx));
    });

    testWidgets('overflowForUiState is onBreak color when ALL showups are on break', (tester) async {
      final ctx = await buildContext(tester);
      final colors = ShowupStatusColors.cupertino(ctx);
      expect(
        colors.overflowForUiState([ShowupUiState.onBreak, ShowupUiState.onBreak]),
        CupertinoColors.systemBlue.resolveFrom(ctx),
      );
    });

    testWidgets('overflowForUiState falls back to amber when only some showups are on break, amid active', (
      tester,
    ) async {
      final ctx = await buildContext(tester);
      final colors = ShowupStatusColors.cupertino(ctx);
      expect(
        colors.overflowForUiState([ShowupUiState.onBreak, ShowupUiState.active]),
        CupertinoColors.systemYellow.resolveFrom(ctx),
      );
    });

    testWidgets('overflowForUiState falls back to grey when only some showups are on break, amid planned', (
      tester,
    ) async {
      final ctx = await buildContext(tester);
      final colors = ShowupStatusColors.cupertino(ctx);
      expect(
        colors.overflowForUiState([ShowupUiState.onBreak, ShowupUiState.planned]),
        CupertinoColors.systemGrey.resolveFrom(ctx),
      );
    });

    testWidgets('overflowForUiState falls back to green when only some showups are on break, amid done', (
      tester,
    ) async {
      final ctx = await buildContext(tester);
      final colors = ShowupStatusColors.cupertino(ctx);
      expect(
        colors.overflowForUiState([ShowupUiState.onBreak, ShowupUiState.done, ShowupUiState.done]),
        CupertinoColors.activeGreen.resolveFrom(ctx),
      );
    });

    testWidgets('overflowForUiState falls back to red when only some showups are on break, amid failed', (
      tester,
    ) async {
      final ctx = await buildContext(tester);
      final colors = ShowupStatusColors.cupertino(ctx);
      expect(
        colors.overflowForUiState([ShowupUiState.onBreak, ShowupUiState.failed, ShowupUiState.failed]),
        CupertinoColors.destructiveRed.resolveFrom(ctx),
      );
    });

    testWidgets('overflowForUiState on an empty list is unchanged — falls through to done', (tester) async {
      final ctx = await buildContext(tester);
      final colors = ShowupStatusColors.cupertino(ctx);
      expect(
        colors.overflowForUiState(const []),
        CupertinoColors.activeGreen.resolveFrom(ctx),
      );
    });
  });

  group('ShowupStatusColors.material', () {
    // Build a colorScheme we can assert against.
    final colorScheme = ColorScheme.fromSeed(seedColor: const Color(0xFF00796B));
    final colors = ShowupStatusColors.material(colorScheme);

    test('maps done → secondary, failed → error, pending → onSurfaceVariant', () {
      expect(colors.forStatus(ShowupStatus.done), colorScheme.secondary);
      expect(colors.forStatus(ShowupStatus.failed), colorScheme.error);
      expect(colors.forStatus(ShowupStatus.pending), colorScheme.onSurfaceVariant);
    });

    test('overflow is onSurfaceVariant while any showup is pending', () {
      expect(colors.overflow(doneCount: 2, failedCount: 1, pendingCount: 1), colorScheme.onSurfaceVariant);
    });

    test('overflow is secondary when resolved and done >= failed', () {
      expect(colors.overflow(doneCount: 2, failedCount: 2, pendingCount: 0), colorScheme.secondary);
    });

    test('overflow is error when resolved and failed > done', () {
      expect(colors.overflow(doneCount: 1, failedCount: 3, pendingCount: 0), colorScheme.error);
    });

    test('forUiState maps onBreak → HabitLoopColors.onBreak', () {
      expect(colors.forUiState(ShowupUiState.onBreak), HabitLoopColors.onBreak);
    });

    test('overflowForUiState is onBreak color when ALL showups are on break', () {
      expect(
        colors.overflowForUiState([ShowupUiState.onBreak, ShowupUiState.onBreak]),
        HabitLoopColors.onBreak,
      );
    });

    test('overflowForUiState falls back to done color when only some showups are on break, amid done', () {
      expect(
        colors.overflowForUiState([ShowupUiState.onBreak, ShowupUiState.done, ShowupUiState.done]),
        colorScheme.secondary,
      );
    });

    test('overflowForUiState falls back to amber when only some showups are on break, amid active', () {
      expect(
        colors.overflowForUiState([ShowupUiState.onBreak, ShowupUiState.active]),
        HabitLoopColors.sunrise,
      );
    });

    test('overflowForUiState falls back to grey when only some showups are on break, amid planned', () {
      expect(
        colors.overflowForUiState([ShowupUiState.onBreak, ShowupUiState.planned]),
        colorScheme.onSurfaceVariant,
      );
    });

    test('overflowForUiState falls back to red when only some showups are on break, amid failed', () {
      expect(
        colors.overflowForUiState([ShowupUiState.onBreak, ShowupUiState.failed, ShowupUiState.failed]),
        colorScheme.error,
      );
    });

    test('overflowForUiState on an empty list is unchanged — falls through to done', () {
      expect(colors.overflowForUiState(const []), colorScheme.secondary);
    });
  });
}
