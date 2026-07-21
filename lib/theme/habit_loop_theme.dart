import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:habit_loop/theme/colors.dart';
import 'package:habit_loop/theme/typography.dart';

export 'package:habit_loop/theme/colors.dart' show HabitLoopColors;

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
      secondary: HabitLoopColors.growth,
      tertiary: HabitLoopColors.sunrise,
      tertiaryContainer: sunriseScheme.primaryContainer,
      onTertiaryContainer: sunriseScheme.onPrimaryContainer,
      error: HabitLoopColors.danger,
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

  static const cupertinoTheme = CupertinoThemeData(
    primaryColor: HabitLoopColors.primary,
    scaffoldBackgroundColor: CupertinoColors.systemBackground,
    barBackgroundColor: CupertinoColors.systemBackground,
    textTheme: AppTypography.cupertinoTextTheme,
  );
}
