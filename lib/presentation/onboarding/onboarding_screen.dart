import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:techxpark/theme/app_colors.dart';
import 'package:techxpark/presentation/auth/login/login_screen.dart';

/// Premium onboarding screen — Stitch design: light gradient bg, skip button,
/// centered illustration, title/subtitle, dot indicator, rounded "Next" button.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  late final List<_OnboardingPage> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _OnboardingPage(
        imageWidget: Container(
          width: 320,
          height: 320,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Image.asset('assets/images/onboarding1.png', fit: BoxFit.cover),
          ),
        ),
        title: 'Find Parking Instantly',
        subtitle: 'Locate available slots near you in real time. No more circling the block.',
      ),
      _OnboardingPage(
        imageWidget: _buildPhoneMockupWidget(),
        title: 'Book in 30 Seconds',
        subtitle: 'Reserve your slot before you arrive. Your spot waits for you.',
      ),
      _OnboardingPage(
        imageWidget: Container(
          width: 320,
          height: 380, // slightly taller for exact aspect ratio of the walk
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Image.asset('assets/images/onboarding3.png', fit: BoxFit.cover),
          ),
        ),
        title: 'Pay & Go Hassle Free',
        subtitle: 'Pay digitally, get receipts instantly. No cash needed.',
      ),
    ];
  }

  Widget _buildPhoneMockupWidget() {
    return Container(
      width: 320,
      height: 350,
      alignment: Alignment.center,
      child: Container(
        width: 170,
        height: 340,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B), // slate-800
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: const Color(0xFF0F172A), width: 6), // slate-900 border
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top notch/speaker
              Container(
                margin: const EdgeInsets.only(bottom: 40),
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // QR Code box
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.04),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Loading/scanning line representation
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 60), // Space to push QR up
            ],
          ),
        ),
      ),
    );
  }

  void _nextPage() {
    if (_currentPage == _pages.length - 1) {
      _navigateToAuth();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _navigateToAuth() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2FF),
        body: SafeArea(
          child: Column(
            children: [
              // ── Skip button ───────────────────────────────────────
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 20),
                  child: TextButton(
                    onPressed: _navigateToAuth,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondaryLight,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      'Skip',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Page content ──────────────────────────────────────
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        children: [
                          const Spacer(flex: 1),

                          // Illustration card / Widget
                          page.imageWidget,

                          const SizedBox(height: 48),

                          // Title
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimaryLight,
                              height: 1.2,
                              letterSpacing: -0.5,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Subtitle
                          Text(
                            page.subtitle,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondaryLight,
                              height: 1.6,
                            ),
                          ),

                          const Spacer(flex: 2),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // ── Dot indicator ─────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? AppColors.primary
                          : AppColors.borderLight,
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ── Next / Get Started button ─────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  24, 0, 24, bottomPadding + 20,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _currentPage == _pages.length - 1
                              ? 'Get Started'
                              : 'Next',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_currentPage < _pages.length - 1) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage {
  final Widget imageWidget;
  final String title;
  final String subtitle;

  _OnboardingPage({
    required this.imageWidget,
    required this.title,
    required this.subtitle,
  });
}
