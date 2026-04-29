import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  static const TextStyle h1 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: 0,
    height: 1.2,
    color: AppColors.textPrimaryLight,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.25,
    color: AppColors.textPrimaryLight,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.3,
    color: AppColors.textPrimaryLight,
  );

  static const TextStyle h4 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.3,
    color: AppColors.textPrimaryLight,
  );

  static const TextStyle body1 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textPrimaryLight,
  );

  static const TextStyle body1SemiBold = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.textPrimaryLight,
  );

  static const TextStyle body1Bold = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.5,
    color: AppColors.textPrimaryLight,
  );

  static const TextStyle body2 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondaryLight,
  );

  static const TextStyle body2SemiBold = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.5,
    color: AppColors.textPrimaryLight,
  );

  static const TextStyle body3 = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.textSecondaryLight,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryLight,
  );

  static const TextStyle captionBold = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.4,
    color: AppColors.textSecondaryLight,
  );

  static const TextStyle label = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppColors.textTertiaryLight,
  );

  static const TextStyle buttonText = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static const TextStyle textButton = TextStyle(
    fontFamily: 'Poppins',
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.primary,
  );

  static TextStyle get h1Dark => h1.copyWith(color: AppColors.textPrimaryDark);
  static TextStyle get h2Dark => h2.copyWith(color: AppColors.textPrimaryDark);
  static TextStyle get h3Dark => h3.copyWith(color: AppColors.textPrimaryDark);
  static TextStyle get body1Dark =>
      body1.copyWith(color: AppColors.textPrimaryDark);
  static TextStyle get body1BoldDark =>
      body1Bold.copyWith(color: AppColors.textPrimaryDark);
  static TextStyle get body2Dark =>
      body2.copyWith(color: AppColors.textSecondaryDark);
  static TextStyle get body2SemiBoldDark =>
      body2SemiBold.copyWith(color: AppColors.textPrimaryDark);
  static TextStyle get captionDark =>
      caption.copyWith(color: AppColors.textSecondaryDark);
  static TextStyle get captionBoldDark =>
      captionBold.copyWith(color: AppColors.textSecondaryDark);
}
