import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:techxpark/presentation/auth/login/login_screen.dart';
import 'package:techxpark/utils/navigation_utils.dart';
import 'package:techxpark/theme/app_colors.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_OnboardingContent> _pages = const [
    _OnboardingContent(
      title: 'Find Parking Instantly',
      description:
          'Locate available slots near you in real time. No more circling the block.',
      assetPath: 'assets/images/onboarding1.png',
    ),
    _OnboardingContent(
      title: 'Book in 30 Seconds',
      description:
          'Reserve your slot before you arrive. Your spot waits for you.',
      assetPath: 'assets/images/onboarding2.png',
    ),
    _OnboardingContent(
      title: 'Pay & Go Hassle Free',
      description: 'Pay digitally, get receipts instantly. No cash needed.',
      assetPath: 'assets/images/onboarding3.png',
    ),
  ];

  void _goNext() {
    if (_currentPage == _pages.length - 1) {
      _openAuth();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  void _openAuth() {
  safePushReplacement(context, const LoginScreen());
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              if (_currentPage < 2)
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, right: 16),
                    child: TextButton(
                      onPressed: _openAuth,
                      child: Text(
                        'Skip',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 54),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final topHeight = constraints.maxHeight * 0.55;
                        return Column(
                          children: [
                            Container(
                              height: topHeight,
                              width: double.infinity,
                              decoration: const BoxDecoration(
                                borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(32),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Image.asset(
                                    page.assetPath,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: const Color(0xFFEAF0FF),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        index == 1
                                            ? Icons.qr_code_2_rounded
                                            : Icons.local_parking_rounded,
                                        color: AppColors.primary,
                                        size: 72,
                                      ),
                                    ),
                                  ),
                                  if (index == 0)
                                    Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.4),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(28),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: List.generate(
                                        _pages.length,
                                        (dotIndex) => AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 250,
                                          ),
                                          margin: const EdgeInsets.only(
                                            right: 8,
                                          ),
                                          width: _currentPage == dotIndex
                                              ? 24
                                              : 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: _currentPage == dotIndex
                                                ? AppColors.primary
                                                : AppColors.borderLight,
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(
                                      page.title,
                                      style: GoogleFonts.poppins(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimaryLight,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 280,
                                      ),
                                      child: Text(
                                        page.description,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                          height: 1.6,
                                          color: AppColors.textSecondaryLight,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: _goNext,
                                        style: ElevatedButton.styleFrom(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          _currentPage == 2
                                              ? 'Get Started'
                                              : 'Next →',
                                          style: GoogleFonts.poppins(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_currentPage == 2) ...[
                                      const SizedBox(height: 12),
                                      Center(
                                        child: TextButton(
                                          onPressed: _openAuth,
                                          child: Text(
                                            'Already have an account? Sign In',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingContent {
  final String title;
  final String description;
  final String assetPath;

  const _OnboardingContent({
    required this.title,
    required this.description,
    required this.assetPath,
  });
}
