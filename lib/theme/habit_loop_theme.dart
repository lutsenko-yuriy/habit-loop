import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:habit_loop/theme/colors.dart';
import 'package:habit_loop/theme/typography.dart';

abstract final class HabitLoopTheme {
  static ThemeData get materialTheme => _buildMaterialTheme(Brightness.light);

  static ThemeData get darkMaterialTheme => _buildMaterialTheme(Brightness.dark);

  static ThemeData _buildMaterialTheme(Brightness brightness) {
    // Derive tertiaryContainer/onTertiaryContainer from the sunrise seed so
    // the commitment warning box stays amber-toned in both light and dark mode.
    final sunriseScheme = ColorScheme.fromSeed(
      seedColor: HabitLoopColors.sunrise,
      brightness: brightness,
    );
    final colorScheme = ColorScheme.fromSeed(
      seedColor: HabitLoopColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: HabitLoopColors.primary,
      onPrimary: _onColorFor(HabitLoopColors.primary),
      secondary: HabitLoopColors.growth,
      onSecondary: _onColorFor(HabitLoopColors.growth),
      tertiary: HabitLoopColors.sunrise,
      onTertiary: _onColorFor(HabitLoopColors.sunrise),
      tertiaryContainer: sunriseScheme.primaryContainer,
      onTertiaryContainer: sunriseScheme.onPrimaryContainer,
      error: HabitLoopColors.danger,
      onError: _onColorFor(HabitLoopColors.danger),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: colorScheme.surfaceTint,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorScheme.primary),
      ),
    );
  }

  // ColorScheme.fromSeed's auto-derived "on*" colors are paired against its own
  // algorithmic tone for that role — not against a brand color overridden via
  // copyWith afterwards. Since our brand colors are fixed (brightness-independent),
  // their AA-safe contrasting text color is fixed too; estimateBrightnessForColor
  // picks black or white to match, exactly as Flutter's own defaults would if the
  // seed tone and the override happened to coincide.
  static Color _onColorFor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark ? Colors.white : Colors.black87;

  static const cupertinoTheme = CupertinoThemeData(
    primaryColor: HabitLoopColors.primary,
    scaffoldBackgroundColor: CupertinoColors.systemBackground,
    barBackgroundColor: CupertinoColors.systemBackground,
    textTheme: AppTypography.cupertinoTextTheme,
  );
}
