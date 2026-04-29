import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Reusable pill-shaped search bar matching the TechXPark design spec.
///
/// Usage:
/// ```dart
/// AppSearchBar(
///   onTap: () => Navigator.push(...SearchScreen),
///   onFilterTap: () => showFilterSheet(),
/// )
/// ```
class AppSearchBar extends StatelessWidget {
  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final VoidCallback? onFilterTap;
  final bool autofocus;
  final bool readOnly;

  const AppSearchBar({
    super.key,
    this.hintText = 'Search parking lots...',
    this.controller,
    this.onChanged,
    this.onTap,
    this.onFilterTap,
    this.autofocus = false,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F1A1953),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onTap: onTap,
        autofocus: autofocus,
        readOnly: readOnly,
        style: const TextStyle(
          color: Color(0xFF0D1117),
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: Color(0xFF9AA5BC),
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 16, right: 8),
            child: Icon(Icons.location_on, color: AppColors.primary, size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 20,
          ),
          suffixIcon: onFilterTap != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: onFilterTap,
                    icon: const Icon(
                      Icons.tune,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    splashRadius: 20,
                  ),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
