import 'package:flutter/material.dart';

/// Centralized color system for TechXPark — synced with Stitch design system.
/// Primary: #1C31D4 (Deep Royal Blue), Roundness: 12px, Saturation: 2
class AppColors {
  // ── Brand Colors (Stitch Design System) ───────────────────────────────
  static const Color primary = Color(0xFF1C31D4); // Deep Royal Blue
  static const Color primaryLight = Color(0xFF4558E8);
  static const Color primaryDark = Color(0xFF1526A8);
  static const Color primarySurface = Color(0xFFE8EAFF); // Light blue surface

  // ── Gradient (Stitch blue header gradient) ────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1C31D4), Color(0xFF3B4FEF)],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1526A8), Color(0xFF1C31D4), Color(0xFF3B4FEF)],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1C31D4), Color(0xFF4558E8)],
  );

  // ── Status Colors ─────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981); // Emerald Green
  static const Color error = Color(0xFFEF4444); // Muted Red
  static const Color warning = Color(0xFFF59E0B); // Soft Amber
  static const Color info = Color(0xFF1C31D4); // Primary Blue

  // ── Background Colors ─────────────────────────────────────────────────
  static const Color bgLight = Color(0xFFF8FAFC); // Very light grey blue
  static const Color bgDark = Color(0xFF0F172A); // Deep slate

  // ── Surface Colors (Cards, Dialogs) ───────────────────────────────────
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF1E293B);

  // ── Text Colors ───────────────────────────────────────────────────────
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // ── Borders & Dividers ────────────────────────────────────────────────
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF334155);

  // ── Input Backgrounds ─────────────────────────────────────────────────
  static const Color inputBgLight = Color(0xFFF1F5F9);
  static const Color inputBgDark = Color(0xFF0F172A);

  // ── Shadows ───────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.15),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];
}
