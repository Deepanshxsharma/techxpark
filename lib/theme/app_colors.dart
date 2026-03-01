import 'package:flutter/material.dart';

/// Centralized color system for the TechXPark app.
/// This ensures consistency across all screens and components.
class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF2845D6); // Premium Royal Blue
  static const Color primaryLight = Color(0xFF4C63E8);
  static const Color primaryDark = Color(0xFF1E36B5);

  // Status Colors
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color error = Color(0xFFEF4444); // Muted Red
  static const Color warning = Color(0xFFF59E0B); // Soft Amber
  static const Color info = Color(0xFF2845D6); // Soft Blue

  // Background Colors
  static const Color bgLight = Color(0xFFF8FAFC); // Very light grey blue
  static const Color bgDark = Color(0xFF0F172A); // Deep slate
  
  // Surface Colors (Cards, Dialogs)
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF1E293B);

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textTertiaryLight = Color(0xFF94A3B8);
  
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Borders & Dividers
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF334155);

  // Input Backgrounds
  static const Color inputBgLight = Color(0xFFF1F5F9);
  static const Color inputBgDark = Color(0xFF0F172A);
}
