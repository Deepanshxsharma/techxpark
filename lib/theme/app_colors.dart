import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF2F2FE4);
  static const Color primaryLight = Color(0xFF5A5AF0);
  static const Color primaryDark = Color(0xFF1C1CB3);
  static const Color activeBlueLight = Color(0xFFEDEDFF);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primary, primaryLight],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primary, primaryLight],
  );

  static const Color bgLight = Color(0xFFF8F9FC);
  static const Color bgDark = Color(0xFF0B1120);

  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF111B31);

  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color textTertiaryDark = Color(0xFF94A3B8);

  static const Color borderLight = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF22304A);
  static const Color dividerLight = borderLight;
  static const Color dividerDark = borderDark;

  static const Color inputBgLight = Color(0xFFFFFFFF);
  static const Color inputBgDark = Color(0xFF162238);

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = primary;
  static const Color evGreen = Color(0xFF00C853);
  static const Color evGreenLight = Color(0xFFE0F7E9);

  static const Color background = bgLight;
  static const Color surface = surfaceLight;
  static const Color textPrimary = textPrimaryLight;
  static const Color textSecondary = textSecondaryLight;
  static const Color border = borderLight;

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
  ];
}
