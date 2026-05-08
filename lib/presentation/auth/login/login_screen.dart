import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/legal_links.dart';
import '../../../services/google_auth_service.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/navigation_utils.dart';
import 'email_login_screen.dart';
import 'phone_login_screen.dart';

/// Auth Gateway Screen — matches the Stitch design.
/// Four sign-in options: Phone, Apple, Google, Email.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // ─── Google Sign-In ────────────────────────────────────────
  Future<void> _handleGoogleLogin() async {
    setState(() => _isGoogleLoading = true);
    HapticFeedback.lightImpact();

    try {
      final userCredential = await GoogleAuthService().signInWithGoogle(
        context,
      );
      if (userCredential != null) {
        HapticFeedback.heavyImpact();
        if (mounted) safeShowAuthState(context);
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  // ─── Apple Sign-In ─────────────────────────────────────────
  Future<void> _handleAppleLogin() async {
    setState(() => _isAppleLoading = true);
    HapticFeedback.lightImpact();

    try {
      final userCredential = await GoogleAuthService().signInWithApple(context);
      if (userCredential != null) {
        HapticFeedback.heavyImpact();
        if (mounted) safeShowAuthState(context);
      }
    } finally {
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }

  Future<void> _openLegalLink(Future<bool> Function() opener) async {
    final opened = await opener();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this link. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0B1120)
            : const Color(0xFFF8FAFC),
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        Container(
                          height: MediaQuery.of(context).size.height * 0.42,
                          width: double.infinity,
                          clipBehavior: Clip.antiAlias,
                          decoration: const BoxDecoration(
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(32),
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.asset(
                                'assets/images/login_skyline.jpg',
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    Container(color: AppColors.primaryDark),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.55),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 28,
                                left: 28,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      clipBehavior: Clip.antiAlias,
                                      child: Image.asset(
                                        'assets/icons/app_icon.png',
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.local_parking_rounded,
                                          color: AppColors.primary,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'TechXPark',
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Smart Parking for\nYour Modern Life',
                                style: GoogleFonts.poppins(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Join TechXPark and discover the easiest\nway to find and book parking spots.',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 32),
                              _AuthButton(
                                label: 'Continue with Phone',
                                icon: Icons.phone_rounded,
                                backgroundColor: AppColors.primary,
                                textColor: Colors.white,
                                shadowColor: AppColors.primary.withValues(
                                  alpha: 0.22,
                                ),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const PhoneLoginScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                              _AuthButton(
                                label: 'Continue with Apple',
                                svgIcon: _appleIcon(),
                                backgroundColor: Colors.black,
                                textColor: Colors.white,
                                isLoading: _isAppleLoading,
                                onTap: _isAppleLoading
                                    ? null
                                    : _handleAppleLogin,
                              ),
                              const SizedBox(height: 12),
                              _AuthButton(
                                label: 'Continue with Google',
                                customIcon: Image.asset(
                                  'assets/images/google.png',
                                  width: 20,
                                  height: 20,
                                ),
                                backgroundColor: isDark
                                    ? const Color(0xFF111B31)
                                    : Colors.white,
                                textColor: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                borderColor: const Color(0xFFE2E8F0),
                                isLoading: _isGoogleLoading,
                                onTap: _isGoogleLoading
                                    ? null
                                    : _handleGoogleLogin,
                              ),
                              const SizedBox(height: 12),
                              _AuthButton(
                                label: 'Continue with Email',
                                icon: Icons.mail_outline_rounded,
                                backgroundColor: isDark
                                    ? const Color(0xFF111B31)
                                    : Colors.white,
                                textColor: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                borderColor: const Color(0xFFE2E8F0),
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const EmailLoginScreen(),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              Center(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      'By continuing, you agree to our ',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.textTertiaryDark
                                            : AppColors.textTertiaryLight,
                                      ),
                                    ),
                                    _LegalTextButton(
                                      label: 'Terms of Service',
                                      onTap: () => _openLegalLink(
                                        LegalLinks.openTermsOfService,
                                      ),
                                    ),
                                    Text(
                                      ' and ',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: isDark
                                            ? AppColors.textTertiaryDark
                                            : AppColors.textTertiaryLight,
                                      ),
                                    ),
                                    _LegalTextButton(
                                      label: 'Privacy Policy',
                                      onTap: () => _openLegalLink(
                                        LegalLinks.openPrivacyPolicy,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _appleIcon() {
    return const Icon(Icons.apple, size: 22);
  }
}

class _LegalTextButton extends StatelessWidget {
  const _LegalTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// AUTH BUTTON — Reusable for all sign-in methods
// ═══════════════════════════════════════════════════════════════
class _AuthButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Widget? svgIcon;
  final Widget? customIcon;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final Color? shadowColor;
  final bool isLoading;
  final VoidCallback? onTap;

  const _AuthButton({
    required this.label,
    this.icon,
    this.svgIcon,
    this.customIcon,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.shadowColor,
    this.isLoading = false,
    this.onTap,
  });

  @override
  State<_AuthButton> createState() => _AuthButtonState();
}

class _AuthButtonState extends State<_AuthButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget;
    if (widget.isLoading) {
      iconWidget = SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: widget.textColor,
        ),
      );
    } else if (widget.customIcon != null) {
      iconWidget = widget.customIcon!;
    } else if (widget.svgIcon != null) {
      iconWidget = IconTheme(
        data: IconThemeData(color: widget.textColor, size: 22),
        child: widget.svgIcon!,
      );
    } else {
      iconWidget = Icon(widget.icon, color: widget.textColor, size: 22);
    }

    return GestureDetector(
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _isPressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => _isPressed = false);
              widget.onTap!();
            },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: widget.borderColor != null
                ? Border.all(color: widget.borderColor!, width: 1.5)
                : null,
            boxShadow: widget.shadowColor != null
                ? [
                    BoxShadow(
                      color: widget.shadowColor!,
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              iconWidget,
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: widget.textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
