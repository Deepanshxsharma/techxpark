import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized Text Styles for TechXPark — Poppins font.
/// Ensures a consistent, modern typography hierarchy.
class AppTextStyles {
  static const String _fontFamily = 'Poppins';

  // ─── Headers ─────────────────────────────────────────────────────────────

  static const TextStyle h1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimaryLight,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const TextStyle h2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static const TextStyle h3 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    height: 1.4,
  );

  // ─── Body Text ───────────────────────────────────────────────────────────

  static const TextStyle body1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimaryLight,
    height: 1.5,
  );

  static const TextStyle body1SemiBold = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    height: 1.5,
  );

  static const TextStyle body1Bold = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimaryLight,
    height: 1.5,
  );

  static const TextStyle body2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryLight,
    height: 1.5,
  );

  static const TextStyle body2SemiBold = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    height: 1.5,
  );

  // ─── Captions & Small Text ───────────────────────────────────────────────

  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryLight,
    height: 1.45,
    letterSpacing: 0.1,
  );

  static const TextStyle captionBold = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondaryLight,
    height: 1.45,
    letterSpacing: 0.2,
  );

  // ─── Buttons ─────────────────────────────────────────────────────────────

  static const TextStyle buttonText = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.2,
  );

  static const TextStyle textButton = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.primary,
  );

  // ─── Dark Mode Variations ────────────────────────────────────────────────

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
