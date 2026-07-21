import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habit_loop/slices/pact/ui/generic/wizard_style.dart';
import 'package:habit_loop/theme/colors.dart';
import 'package:habit_loop/theme/habit_loop_theme.dart';

void main() {
  group('WizardStyle.cupertino', () {
    testWidgets('activeStepColor is HabitLoopColors.primary', (tester) async {
      late WizardStyle style;
      await tester.pumpWidget(CupertinoApp(home: Builder(builder: (ctx) {
        style = WizardStyle.cupertino(ctx);
        return const SizedBox();
      })));
      expect(style.activeStepColor, HabitLoopColors.primary);
    });

    testWidgets('pastStepColor is faded primary', (tester) async {
      late WizardStyle style;
      await tester.pumpWidget(CupertinoApp(home: Builder(builder: (ctx) {
        style = WizardStyle.cupertino(ctx);
        return const SizedBox();
      })));
      expect(style.pastStepColor, HabitLoopColors.primary.withValues(alpha: 0.3));
    });

    testWidgets('inactiveStepColor resolves from Cupertino context', (tester) async {
      late WizardStyle style;
      late BuildContext capturedCtx;
      await tester.pumpWidget(CupertinoApp(home: Builder(builder: (ctx) {
        capturedCtx = ctx;
        style = WizardStyle.cupertino(ctx);
        return const SizedBox();
      })));
      expect(style.inactiveStepColor, CupertinoColors.tertiarySystemFill.resolveFrom(capturedCtx));
    });

    testWidgets('hintTextColor resolves from Cupertino systemGrey', (tester) async {
      late WizardStyle style;
      late BuildContext capturedCtx;
      await tester.pumpWidget(CupertinoApp(home: Builder(builder: (ctx) {
        capturedCtx = ctx;
        style = WizardStyle.cupertino(ctx);
        return const SizedBox();
      })));
      expect(style.hintTextColor, CupertinoColors.systemGrey.resolveFrom(capturedCtx));
    });
  });

  group('WizardStyle.material', () {
    testWidgets('activeStepColor matches theme primary', (tester) async {
      late WizardStyle style;
      late ThemeData theme;
      await tester.pumpWidget(MaterialApp(
        theme: HabitLoopTheme.materialTheme,
        home: Builder(builder: (ctx) {
          theme = Theme.of(ctx);
          style = WizardStyle.material(ctx);
          return const SizedBox();
        }),
      ));
      expect(style.activeStepColor, theme.colorScheme.primary);
    });

    testWidgets('pastStepColor is faded theme primary', (tester) async {
      late WizardStyle style;
      late ThemeData theme;
      await tester.pumpWidget(MaterialApp(
        theme: HabitLoopTheme.materialTheme,
        home: Builder(builder: (ctx) {
          theme = Theme.of(ctx);
          style = WizardStyle.material(ctx);
          return const SizedBox();
        }),
      ));
      expect(style.pastStepColor, theme.colorScheme.primary.withValues(alpha: 0.3));
    });

    testWidgets('inactiveStepColor matches surfaceContainerHighest', (tester) async {
      late WizardStyle style;
      late ThemeData theme;
      await tester.pumpWidget(MaterialApp(
        theme: HabitLoopTheme.materialTheme,
        home: Builder(builder: (ctx) {
          theme = Theme.of(ctx);
          style = WizardStyle.material(ctx);
          return const SizedBox();
        }),
      ));
      expect(style.inactiveStepColor, theme.colorScheme.surfaceContainerHighest);
    });

    testWidgets('hintTextColor matches onSurfaceVariant', (tester) async {
      late WizardStyle style;
      late ThemeData theme;
      await tester.pumpWidget(MaterialApp(
        theme: HabitLoopTheme.materialTheme,
        home: Builder(builder: (ctx) {
          theme = Theme.of(ctx);
          style = WizardStyle.material(ctx);
          return const SizedBox();
        }),
      ));
      expect(style.hintTextColor, theme.colorScheme.onSurfaceVariant);
    });
  });
}
