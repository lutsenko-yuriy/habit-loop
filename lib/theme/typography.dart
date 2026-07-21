import 'package:flutter/cupertino.dart';
import 'package:habit_loop/theme/colors.dart';

/// Shared typography tokens for the iOS pact-creation wizard.
///
/// [wizardStepTitle] and [wizardHeroNumber] replace the identical hand-rolled
/// `TextStyle(fontSize: ...)` literals that were previously duplicated across
/// every wizard step widget (HAB-187 WU3, checkup finding
/// `CHK-2026-07-20-heavy-8`). Android widgets keep using
/// `Theme.of(context).textTheme.*` and are not migrated to these tokens.
///
/// [cupertinoTextTheme] is wired into `HabitLoopTheme.cupertinoTheme` so the
/// tokens are also reachable via `CupertinoTheme.of(context).textTheme`. It
/// forwards the same [HabitLoopColors.primary] the theme already used
/// implicitly for action-button text, so wiring it in changes nothing
/// visually for any already-shipped screen — except `tabLabelTextStyle`,
/// which the app has no `CupertinoTabBar` consumer for yet, so it is safe to
/// give it a real value here (also lets a widget test prove the wiring is
/// live, not just defined and unused).
abstract final class AppTypography {
  /// Wizard step heading, e.g. "Reminder", "Schedule".
  static const TextStyle wizardStepTitle = TextStyle(fontSize: 22, fontWeight: FontWeight.bold);

  /// Large hero number display (e.g. the show-up duration in minutes).
  static const TextStyle wizardHeroNumber = TextStyle(fontSize: 36, fontWeight: FontWeight.bold);

  static const CupertinoTextThemeData cupertinoTextTheme = CupertinoTextThemeData(
    primaryColor: HabitLoopColors.primary,
    tabLabelTextStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: HabitLoopColors.primary),
  );
}
