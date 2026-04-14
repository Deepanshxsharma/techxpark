import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// BuildContext extensions for theme-aware access to colors, typography, and i18n.
///
/// These make it easy to adapt widgets for dark mode and provide a clean API:
///   context.bgColor, context.typographyH1, context.tr('Hello')
extension ThemeContextExtension on BuildContext {
  // ── Brightness ─────────────────────────────────────────────────────────
  bool get _isDark => Theme.of(this).brightness == Brightness.dark;

  // ── Colors ─────────────────────────────────────────────────────────────
  Color get bgColor => _isDark ? AppColors.bgDark : AppColors.bgLight;
  Color get surfaceColor => _isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
  Color get borderColor => _isDark ? AppColors.borderDark : AppColors.borderLight;
  Color get textPrimary => _isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
  Color get textSecondary => _isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

  // ── Typography (theme-aware) ───────────────────────────────────────────
  TextStyle get typographyH1 =>
      (_isDark ? AppTextStyles.h1Dark : AppTextStyles.h1);
  TextStyle get typographyH2 =>
      (_isDark ? AppTextStyles.h2Dark : AppTextStyles.h2);
  TextStyle get typographyH3 =>
      (_isDark ? AppTextStyles.h3Dark : AppTextStyles.h3);
  TextStyle get typographyBody =>
      (_isDark ? AppTextStyles.body1Dark : AppTextStyles.body1);
  TextStyle get typographyBodySub =>
      (_isDark ? AppTextStyles.body2Dark : AppTextStyles.body2);
  TextStyle get typographyCaption =>
      (_isDark ? AppTextStyles.captionDark : AppTextStyles.caption);
  TextStyle get typographyCaptionSemiBold =>
      (_isDark ? AppTextStyles.captionBoldDark : AppTextStyles.captionBold);

  // ── Locale ─────────────────────────────────────────────────────────────
  /// Returns the current locale tag (e.g. 'en_US') for date formatters.
  String get localeTag {
    final locale = Localizations.localeOf(this);
    return '${locale.languageCode}_${locale.countryCode ?? ''}';
  }

  // ── Simple i18n passthrough ────────────────────────────────────────────
  /// Translates a key. Currently returns the key itself (no i18n backend).
  /// Supports optional [args] map for placeholder replacement.
  String tr(String key, {Map<String, dynamic>? args}) {
    var result = key;
    if (args != null) {
      args.forEach((k, v) {
        result = result.replaceAll('{$k}', v.toString());
      });
    }
    return result;
  }
}
