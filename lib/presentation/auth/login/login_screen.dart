import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:techxpark/services/google_auth_service.dart';
import 'package:techxpark/presentation/auth/signup/signup_screen.dart';
import 'package:techxpark/theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  String? _emailError;
  String? _passError;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000))
      ..forward();
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic);

    _emailFocus.addListener(() => setState(() {}));
    _passFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _validate() {
    setState(() {
      _emailError = null;
      _passError = null;

      final email = _emailCtrl.text.trim();
      final pass = _passCtrl.text.trim();

      if (email.isEmpty) {
        _emailError = "Email is required";
      } else if (!_isValidEmail(email)) {
        _emailError = "Enter a valid email address";
      }

      if (pass.isEmpty) {
        _passError = "Password is required";
      } else if (pass.length < 6) {
        _passError = "Password must be at least 6 characters";
      }
    });
  }

  Future<void> _handleLogin() async {
    _validate();
    if (_emailError != null || _passError != null) {
      HapticFeedback.lightImpact();
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      // AuthWrapper handles navigation automatically upon auth state change.
      HapticFeedback.heavyImpact(); 
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Login failed"),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isGoogleLoading = true);
    HapticFeedback.lightImpact();

    final user = await GoogleAuthService().signInWithGoogle();

    if (mounted) {
      setState(() => _isGoogleLoading = false);
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google Sign-In cancelled")),
        );
      } else {
        HapticFeedback.heavyImpact(); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine overall brightness for the scaffold
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // ─── TOP GRADIENT BACKGROUND ──────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 80, bottom: 60),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.local_parking_rounded,
                      size: 64,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "TechXPark",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Your digital parking companion",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // ─── OVERLAPPING WHITE CARD ──────────
              Transform.translate(
                offset: const Offset(0, -30),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        "Welcome Back",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── EMAIL INPUT ──
                      _buildInputField(
                        controller: _emailCtrl,
                        focusNode: _emailFocus,
                        hintText: "Enter your email",
                        icon: Icons.email_outlined,
                        errorText: _emailError,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 16),

                      // ── PASSWORD INPUT ──
                      _buildInputField(
                        controller: _passCtrl,
                        focusNode: _passFocus,
                        hintText: "Enter your password",
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        errorText: _passError,
                        isDark: isDark,
                      ),

                      // ── FORGOT PASSWORD ──
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          child: const Text(
                            "Forgot Password?",
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── LOGIN BUTTON ──
                      _buildPrimaryBtn(
                        text: "Login",
                        isLoading: _isLoading,
                        onPressed: _handleLogin,
                      ),
                      const SizedBox(height: 24),

                      // ── DIVIDER ──
                      Row(
                        children: [
                          Expanded(
                              child: Divider(
                                  color: isDark ? AppColors.borderDark : AppColors.borderLight)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              "or continue with",
                              style: TextStyle(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                              child: Divider(
                                  color: isDark ? AppColors.borderDark : AppColors.borderLight)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── GOOGLE BUTTON ──
                      OutlinedButton.icon(
                        onPressed: _isGoogleLoading ? null : _handleGoogleLogin,
                        icon: _isGoogleLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            : Image.asset("assets/images/google.png",
                                height: 20),
                        label: Text(
                          "Google",
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(
                              color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── SIGN UP LINK ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SignupScreen()),
                      );
                    },
                    child: const Text(
                      "Register",
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------------
  // COMPONENT BUILDERS
  // ----------------------------------------------------------------------

  Widget _buildInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    String? errorText,
    required bool isDark,
  }) {
    final bool hasError = errorText != null;
    final bool isFocused = focusNode.hasFocus;

    Color borderColor = Colors.transparent;
    if (hasError) borderColor = AppColors.error;
    else if (isFocused) borderColor = AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isDark ? AppColors.inputBgDark : AppColors.inputBgLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: isFocused || hasError ? 1.5 : 1.0,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: isPassword && _obscurePassword,
            keyboardType: isPassword
                ? TextInputType.text
                : TextInputType.emailAddress,
            cursorColor: AppColors.primary,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimaryLight,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
              prefixIcon: Icon(
                icon,
                color: hasError
                    ? AppColors.error
                    : (isFocused ? AppColors.primary : Colors.grey),
                size: 22,
              ),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword),
                    )
                  : null,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              errorText,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPrimaryBtn({
    required String text,
    required bool isLoading,
    required VoidCallback onPressed,
  }) {
    return StatefulBuilder(
      builder: (context, setStateBtn) {
        bool isPressed = false;
        
        bool isDisabled = _emailCtrl.text.isEmpty || _passCtrl.text.isEmpty;

        return GestureDetector(
          onTapDown: isDisabled || isLoading ? null : (_) => setStateBtn(() => isPressed = true),
          onTapUp: isDisabled || isLoading ? null : (_) {
            setStateBtn(() => isPressed = false);
            onPressed();
          },
          onTapCancel: () => setStateBtn(() => isPressed = false),
          child: AnimatedScale(
            scale: isPressed ? 0.97 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 54,
              decoration: BoxDecoration(
                color: isDisabled || isLoading ? AppColors.primary.withOpacity(0.5) : AppColors.primary,
                borderRadius: BorderRadius.circular(14),
                boxShadow: isDisabled || isLoading ? [] : [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showForgotPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController();
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: Text(
            "Reset Password",
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: resetEmailController,
            decoration: InputDecoration(
              hintText: "Enter your registered email",
              labelText: "Email",
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final email = resetEmailController.text.trim();
                if (email.isEmpty) return;
                try {
                  await FirebaseAuth.instance
                      .sendPasswordResetEmail(email: email);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Reset link sent to your email!"),
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Error: $e"),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              },
              child: const Text("Send Link"),
            ),
          ],
        );
      },
    );
  }
}