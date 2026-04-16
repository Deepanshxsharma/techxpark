import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../services/google_auth_service.dart';
import '../../../theme/app_colors.dart';
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
      final user = await GoogleAuthService().signInWithGoogle();

      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': user.displayName ?? '',
          'email': user.email ?? '',
          'phone': user.phoneNumber ?? '',
          'provider': 'google',
          'role': 'customer',
          'banned': false,
          'isOnline': false,
          'accessStatus': 'none',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        HapticFeedback.heavyImpact();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Google Sign-In cancelled'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
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
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(oauthCredential);
      final user = userCredential.user;

      if (user != null) {
        // Apple only returns name on first sign-in
        String displayName = user.displayName ?? '';
        if (displayName.isEmpty) {
          final givenName = appleCredential.givenName ?? '';
          final familyName = appleCredential.familyName ?? '';
          displayName = '$givenName $familyName'.trim();
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'name': displayName,
          'email': user.email ?? appleCredential.email ?? '',
          'phone': '',
          'provider': 'apple',
          'role': 'customer',
          'banned': false,
          'isOnline': false,
          'accessStatus': 'none',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        HapticFeedback.heavyImpact();
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        // User cancelled — do nothing
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Apple Sign-In failed: ${e.message}'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Apple Sign-In failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAppleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;


    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF111321) : const Color(0xFFF6F6F8),
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SafeArea(
            child: Column(
              children: [
                // ═══════════════════════════════════════
                // TOP APP BAR
                // ═══════════════════════════════════════
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      // App logo
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Image.asset(
                          'assets/icons/app_icon.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'TechXPark',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                // ═══════════════════════════════════════
                // ILLUSTRATION + TEXT + BUTTONS
                // ═══════════════════════════════════════
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // ── Hero Illustration ────────────
                        _buildHeroIllustration(isDark),

                        const SizedBox(height: 32),

                        // ── Headline ─────────────────────
                        Text(
                          'Smart Parking for\nYour Modern Life',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Join TechXPark and discover the easiest\nway to find and book parking spots.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 36),

                        // ═══════════════════════════════════
                        // AUTH BUTTONS
                        // ═══════════════════════════════════

                        // 1) Continue with Phone
                        _AuthButton(
                          label: 'Continue with Phone',
                          icon: Icons.smartphone,
                          backgroundColor: AppColors.primary,
                          textColor: Colors.white,
                          shadowColor: AppColors.primary.withValues(alpha: 0.2),
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

                        // 2) Continue with Apple
                        _AuthButton(
                          label: 'Continue with Apple',
                          svgIcon: _appleIcon(),
                          backgroundColor: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                          textColor: isDark
                              ? const Color(0xFF0F172A)
                              : Colors.white,
                          shadowColor: const Color(0xFF0F172A)
                              .withValues(alpha: 0.1),
                          isLoading: _isAppleLoading,
                          onTap: _isAppleLoading ? null : _handleAppleLogin,
                        ),
                        const SizedBox(height: 12),

                        // 3) Continue with Google
                        _AuthButton(
                          label: 'Continue with Google',
                          customIcon: Image.asset(
                            'assets/images/google.png',
                            width: 20,
                            height: 20,
                          ),
                          backgroundColor: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          textColor: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                          borderColor: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          isLoading: _isGoogleLoading,
                          onTap:
                              _isGoogleLoading ? null : _handleGoogleLogin,
                        ),
                        const SizedBox(height: 12),

                        // 4) Continue with Email
                        _AuthButton(
                          label: 'Continue with Email',
                          icon: Icons.mail_outline_rounded,
                          backgroundColor: isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                          textColor: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                          borderColor: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
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

                        const SizedBox(height: 32),

                        // ── Footer ───────────────────────
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Text.rich(
                            TextSpan(
                              text: 'By continuing, you agree to our ',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                                height: 1.5,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
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

  // ═══════════════════════════════════════════════════════════════
  // HERO ILLUSTRATION — Image
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeroIllustration(bool isDark) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: const DecorationImage(
            image: AssetImage('assets/images/login_skyline.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                (isDark ? const Color(0xFF111321) : const Color(0xFFF6F6F8)).withValues(alpha: 0.8),
                Colors.transparent,
              ],
              stops: const [0.0, 0.5],
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
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _isPressed = true),
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
                style: TextStyle(
                  fontFamily: 'Inter',
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

// ═══════════════════════════════════════════════════════════════
// GRID PATTERN PAINTER — Subtle background decoration
// ═══════════════════════════════════════════════════════════════
class _GridPatternPainter extends CustomPainter {
  final Color color;

  _GridPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5;

    const spacing = 30.0;

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}