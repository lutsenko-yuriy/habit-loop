import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:habit_loop/theme/colors.dart';

class WizardStyle {
  final Color activeStepColor;
  final Color pastStepColor;
  final Color inactiveStepColor;
  final Color hintTextColor;
  final Color labelColor;
  final Color cardColor;
  final Color? dividerColor;

  const WizardStyle({
    required this.activeStepColor,
    required this.pastStepColor,
    required this.inactiveStepColor,
    required this.hintTextColor,
    required this.labelColor,
    required this.cardColor,
    this.dividerColor,
  });

  factory WizardStyle.cupertino(BuildContext context) => WizardStyle(
        activeStepColor: HabitLoopColors.primary,
        pastStepColor: HabitLoopColors.primary.withValues(alpha: 0.3),
        inactiveStepColor: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        hintTextColor: CupertinoColors.systemGrey.resolveFrom(context),
        labelColor: CupertinoColors.systemGrey.resolveFrom(context),
        cardColor: CupertinoColors.tertiarySystemFill.resolveFrom(context),
        dividerColor: CupertinoColors.separator.resolveFrom(context),
      );

  static WizardStyle material(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return WizardStyle(
      activeStepColor: cs.primary,
      pastStepColor: cs.primary.withValues(alpha: 0.3),
      inactiveStepColor: cs.surfaceContainerHighest,
      hintTextColor: cs.onSurfaceVariant,
      labelColor: cs.onSurfaceVariant,
      cardColor: cs.surfaceContainerHighest,
    );
  }
}
