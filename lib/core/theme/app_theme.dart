import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  // LIGHT THEME
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.bgLight,
    fontFamily: 'Poppins',
    colorScheme: ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.bgLight,
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
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.bgDark,
    fontFamily: 'Poppins',
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.bgDark,
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
