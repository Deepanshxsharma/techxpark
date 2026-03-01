import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized Text Styles for the TechXPark app.
/// Ensures a consistent, modern typography hierarchy (H1, H2, Body, Caption).
class AppTextStyles {
  // ─── Headers ─────────────────────────────────────────────────────────────
  
  static const TextStyle h1 = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimaryLight,
    height: 1.2,
    letterSpacing: -0.5,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimaryLight,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    height: 1.4,
  );

  // ─── Body Text ───────────────────────────────────────────────────────────

  static const TextStyle body1 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimaryLight,
    height: 1.5,
  );

  static const TextStyle body1SemiBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    height: 1.5,
  );

  static const TextStyle body1Bold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimaryLight,
    height: 1.5,
  );

  static const TextStyle body2 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondaryLight,
    height: 1.5,
  );

  static const TextStyle body2SemiBold = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimaryLight,
    height: 1.5,
  );

  // ─── Captions & Small Text ───────────────────────────────────────────────

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondaryLight,
    letterSpacing: 0.2,
  );

  static const TextStyle captionBold = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondaryLight,
    letterSpacing: 0.5,
  );

  // ─── Buttons ─────────────────────────────────────────────────────────────

  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    letterSpacing: 0.2,
  );

  static const TextStyle textButton = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.primary,
  );

  // ─── Dark Mode Variations ────────────────────────────────────────────────
  
  static TextStyle get h1Dark => h1.copyWith(color: AppColors.textPrimaryDark);
  static TextStyle get h2Dark => h2.copyWith(color: AppColors.textPrimaryDark);
  static TextStyle get h3Dark => h3.copyWith(color: AppColors.textPrimaryDark);
  
  static TextStyle get body1Dark => body1.copyWith(color: AppColors.textPrimaryDark);
  static TextStyle get body1BoldDark => body1Bold.copyWith(color: AppColors.textPrimaryDark);
  static TextStyle get body2Dark => body2.copyWith(color: AppColors.textSecondaryDark);
  static TextStyle get body2SemiBoldDark => body2SemiBold.copyWith(color: AppColors.textPrimaryDark);
  
  static TextStyle get captionDark => caption.copyWith(color: AppColors.textSecondaryDark);
  static TextStyle get captionBoldDark => captionBold.copyWith(color: AppColors.textSecondaryDark);
}
