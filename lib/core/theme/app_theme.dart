import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  // LIGHT THEME
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.bgLight,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      background: AppColors.bgLight,
    ),
    cardColor: AppColors.cardLight,
    textTheme: const TextTheme(
      headlineLarge: AppTextStyles.h1,
      headlineMedium: AppTextStyles.h2,
      bodyLarge: AppTextStyles.body,
      bodyMedium: AppTextStyles.small,
    ),
  );

  // DARK THEME
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.bgDark,
    fontFamily: 'Inter',
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      background: AppColors.bgDark,
    ),
    cardColor: AppColors.cardDark,
    textTheme: const TextTheme(
      headlineLarge: AppTextStyles.h1,
      headlineMedium: AppTextStyles.h2,
      bodyLarge: AppTextStyles.body,
      bodyMedium: AppTextStyles.small,
    ),
  );
}
