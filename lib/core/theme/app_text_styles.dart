import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTextStyles {
  static TextStyle h1({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
        color: color,
      );

  static TextStyle h2({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: color,
      );

  static TextStyle h3({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle h4({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: color,
      );

  static TextStyle body({Color color = AppColors.textPrimary}) =>
      GoogleFonts.poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: color,
      );

  static TextStyle caption({Color color = AppColors.textSecondary}) =>
      GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle label({Color color = AppColors.textHint}) =>
      GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: color,
      );
}
