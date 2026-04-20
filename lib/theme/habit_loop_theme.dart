import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class HabitLoopColors {
  static const primary = Color(0xFF00796B);
  static const primaryDark = Color(0xFF004D40);
  static const growth = Color(0xFF8BC34A);
  static const sunrise = Color(0xFFFFB74D);
  static const success = Color(0xFF2E7D32);
  static const danger = Color(0xFFC62828);
  static const pending = Color(0xFFF57C00);
}

abstract final class HabitLoopTheme {
  static ThemeData get materialTheme => _buildMaterialTheme(Brightness.light);

  static ThemeData get darkMaterialTheme => _buildMaterialTheme(Brightness.dark);

  static ThemeData _buildMaterialTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: HabitLoopColors.primary,
      brightness: brightness,
    ).copyWith(
      primary: HabitLoopColors.primary,
      secondary: HabitLoopColors.growth,
      tertiary: HabitLoopColors.sunrise,
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
  );
}
