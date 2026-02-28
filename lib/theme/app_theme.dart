import 'package:flutter/material.dart';
import 'tokens.dart';

ThemeData buildLightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.bgPrimary,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
      surface: AppColors.bgSecondary,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.accentLight,
      error: AppColors.conditionPoor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bgPrimary,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: AppTypography.textBase,
        fontWeight: AppTypography.weightSemibold,
        color: AppColors.textPrimary,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.bgSecondary,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColors.textTertiary,
      selectedLabelStyle: TextStyle(fontSize: AppTypography.textXs),
      unselectedLabelStyle: TextStyle(fontSize: AppTypography.textXs),
      type: BottomNavigationBarType.fixed,
    ),
    cardTheme: CardThemeData(
      color: AppColors.bgSecondary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.bgTertiary,
      selectedColor: AppColors.accentBgStrong,
      labelStyle: const TextStyle(
        fontSize: AppTypography.textSm,
        color: AppColors.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      side: BorderSide.none,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: AppColors.bgTertiary,
      thumbColor: AppColors.accent,
      overlayColor: AppColors.accent.withValues(alpha: 0.12),
      trackHeight: 4,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: const TextStyle(
          fontSize: AppTypography.textBase,
          fontWeight: AppTypography.weightSemibold,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.accent),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: const TextStyle(
          fontSize: AppTypography.textBase,
          fontWeight: AppTypography.weightSemibold,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: const TextStyle(
          fontSize: AppTypography.textSm,
          fontWeight: AppTypography.weightMedium,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.border,
      thickness: 1,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: AppTypography.text2xl,
        fontWeight: AppTypography.weightBold,
        color: AppColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: AppTypography.textXl,
        fontWeight: AppTypography.weightSemibold,
        color: AppColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: AppTypography.textBase,
        fontWeight: AppTypography.weightSemibold,
        color: AppColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: AppTypography.textBase,
        color: AppColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: AppTypography.textSm,
        color: AppColors.textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: AppTypography.textXs,
        color: AppColors.textTertiary,
      ),
      labelLarge: TextStyle(
        fontSize: AppTypography.textSm,
        fontWeight: AppTypography.weightMedium,
        color: AppColors.textPrimary,
      ),
    ),
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColorsDark.bgPrimary,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
      surface: AppColorsDark.bgSecondary,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.accentLight,
      error: AppColors.conditionPoor,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColorsDark.bgPrimary,
      foregroundColor: AppColorsDark.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: AppTypography.textBase,
        fontWeight: AppTypography.weightSemibold,
        color: AppColorsDark.textPrimary,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColorsDark.bgSecondary,
      selectedItemColor: AppColors.accent,
      unselectedItemColor: AppColorsDark.textTertiary,
      selectedLabelStyle: TextStyle(fontSize: AppTypography.textXs),
      unselectedLabelStyle: TextStyle(fontSize: AppTypography.textXs),
      type: BottomNavigationBarType.fixed,
    ),
    cardTheme: CardThemeData(
      color: AppColorsDark.bgSecondary,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColorsDark.bgTertiary,
      selectedColor: AppColorsDark.accentBgStrong,
      labelStyle: const TextStyle(
        fontSize: AppTypography.textSm,
        color: AppColorsDark.textPrimary,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      side: BorderSide.none,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: AppColors.accent,
      inactiveTrackColor: AppColorsDark.bgTertiary,
      thumbColor: AppColors.accent,
      overlayColor: AppColors.accent.withValues(alpha: 0.12),
      trackHeight: 4,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: const TextStyle(
          fontSize: AppTypography.textBase,
          fontWeight: AppTypography.weightSemibold,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.accent),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: const TextStyle(
          fontSize: AppTypography.textBase,
          fontWeight: AppTypography.weightSemibold,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accent,
        textStyle: const TextStyle(
          fontSize: AppTypography.textSm,
          fontWeight: AppTypography.weightMedium,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: AppColorsDark.border,
      thickness: 1,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: AppTypography.text2xl,
        fontWeight: AppTypography.weightBold,
        color: AppColorsDark.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontSize: AppTypography.textXl,
        fontWeight: AppTypography.weightSemibold,
        color: AppColorsDark.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: AppTypography.textBase,
        fontWeight: AppTypography.weightSemibold,
        color: AppColorsDark.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontSize: AppTypography.textBase,
        color: AppColorsDark.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontSize: AppTypography.textSm,
        color: AppColorsDark.textSecondary,
      ),
      bodySmall: TextStyle(
        fontSize: AppTypography.textXs,
        color: AppColorsDark.textTertiary,
      ),
      labelLarge: TextStyle(
        fontSize: AppTypography.textSm,
        fontWeight: AppTypography.weightMedium,
        color: AppColorsDark.textPrimary,
      ),
    ),
  );
}
