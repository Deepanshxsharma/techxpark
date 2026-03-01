import 'package:flutter/material.dart';
import 'package:techxpark/presentation/auth/login/login_screen.dart'; // 👈 IMPORT ADDED

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int pageIndex = 0;

  final List<Map<String, String>> pages = [
    {
      "image": "assets/images/park1.png",
      "title": "Find Parking Easily",
      "desc": "Locate nearby parking spots in seconds."
    },
    {
      "image": "assets/images/park2.png",
      "title": "Book Before You Reach",
      "desc": "Reserve your parking and avoid the hassle."
    },
    {
      "image": "assets/images/park3.png",
      "title": "Safe & Secure",
      "desc": "Track your parking and enjoy peace of mind."
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F2FF), // Soft purple-white
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() {
                    pageIndex = index;
                  });
                },
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  final page = pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // --- IMAGE CARD (Parkir style) ---
                        Container(
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.only(top: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12.withOpacity(0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Image.asset(
                            page["image"]!,
                            height: 280,
                            fit: BoxFit.contain,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // --- TITLE ---
                        Text(
                          page["title"]!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Color(0xff2D265E),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // --- DESCRIPTION ---
                        Text(
                          page["desc"]!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black54,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 10),

            // --- DOT INDICATOR ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.all(4),
                  width: pageIndex == index ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: pageIndex == index
                        ? const Color(0xff4D6FFF)
                        : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // --- BOTTOM BUTTON ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              margin: const EdgeInsets.only(bottom: 20),
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff4D6FFF),
                  minimumSize: const Size(double.infinity, 55),
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  if (pageIndex == pages.length - 1) {
                    // ✔ Navigate to Login Screen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: Text(
                  pageIndex == pages.length - 1 ? "Get Started" : "Next",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
