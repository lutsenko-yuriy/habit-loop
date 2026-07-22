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
///
/// The tokens below (HAB-187 WU10) replace hand-rolled `TextStyle`/`fontSize`
/// literals that were duplicated 2+ times across iOS/Android/generic widgets.
/// None of them carry a `color` — call sites that need one apply it via
/// `.copyWith(color: ...)` so a token's rendered colour is unaffected by
/// adopting it (colour/contrast correctness stays WU6's job). Genuinely
/// one-off styles are left as raw literals at their call site.
abstract final class AppTypography {
  /// Wizard step heading, e.g. "Reminder", "Schedule".
  static const TextStyle wizardStepTitle = TextStyle(fontSize: 22, fontWeight: FontWeight.bold);

  /// Large hero number display (e.g. the show-up duration in minutes).
  static const TextStyle wizardHeroNumber = TextStyle(fontSize: 36, fontWeight: FontWeight.bold);

  /// Screen/section heading outside the wizard (About, pact detail, pact edit
  /// summary, showup detail). Same visual size as [wizardStepTitle] but kept
  /// as a separate named token since these screens aren't wizard steps.
  static const TextStyle sectionTitle = TextStyle(fontSize: 22, fontWeight: FontWeight.bold);

  /// Default body text.
  static const TextStyle body = TextStyle(fontSize: 14);

  /// Body text with relaxed line height, for multi-line banners/paragraphs
  /// (e.g. the commitment-rules warning).
  static const TextStyle bodyRelaxed = TextStyle(fontSize: 14, height: 1.5);

  /// Secondary/muted small text.
  static const TextStyle caption = TextStyle(fontSize: 13);

  /// Secondary small text, italicised (e.g. timeline note/current-state lines).
  static const TextStyle captionItalic = TextStyle(fontSize: 13, fontStyle: FontStyle.italic);

  /// Smaller italic caption used for date labels next to timeline milestones.
  static const TextStyle dateCaption = TextStyle(fontSize: 12, fontStyle: FontStyle.italic);

  /// All-caps divider/section label with tracked-out letter spacing.
  static const TextStyle overline = TextStyle(fontSize: 11, letterSpacing: 0.4);

  /// Semibold weight on top of the ambient font size — used where only the
  /// weight (not the size) needs emphasis, e.g. timeline milestone titles.
  static const TextStyle emphasis = TextStyle(fontWeight: FontWeight.w600);

  /// Emphasised value/number display (e.g. stat-card values, timeline outcomes).
  static const TextStyle valueEmphasis = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);

  static const CupertinoTextThemeData cupertinoTextTheme = CupertinoTextThemeData(
    primaryColor: HabitLoopColors.primary,
    tabLabelTextStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: HabitLoopColors.primary),
  );
}
