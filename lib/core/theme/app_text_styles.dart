import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Titles
  static const TextStyle h1 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
    height: 1.2,
    letterSpacing: -0.2,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textDark,
    height: 1.35,
  );

  // Body Text
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textDark,
    height: 1.5,
  );

  // Small Text
  static const TextStyle small = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textDark,
    height: 1.45,
  );
}
