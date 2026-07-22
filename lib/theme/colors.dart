import 'package:flutter/cupertino.dart';

abstract final class HabitLoopColors {
  static const primary = Color(0xFF00796B);
  static const primaryDark = Color(0xFF004D40);
  static const growth = Color(0xFF8BC34A);
  static const sunrise = Color(0xFFFFB74D);
  static const success = Color(0xFF2E7D32);
  static const danger = Color(0xFFC62828);
  static const pending = Color(0xFFF57C00);

  /// AA-compliant (>=4.5:1), dark-mode-adaptive muted/secondary text color.
  ///
  /// `CupertinoColors.secondaryLabel` only reaches ~3.4:1 against
  /// `systemBackground` — short of WCAG AA's 4.5:1 minimum for normal-sized
  /// text (a known iOS-HIG vs. WCAG mismatch, HAB-187 WU6).
  static Color secondaryText(BuildContext context) => const CupertinoDynamicColor.withBrightness(
        color: Color(0xFF616161),
        darkColor: Color(0xFFBDBDBD),
      ).resolveFrom(context);
}
