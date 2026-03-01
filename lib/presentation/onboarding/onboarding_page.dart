import 'package:flutter/material.dart';
import 'onboarding_data.dart';

class OnboardingPage extends StatelessWidget {
  final OnboardingData data;

  const OnboardingPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),

        // IMAGE
        SizedBox(
          height: 300,
          child: Image.asset(data.image),
        ),

        const SizedBox(height: 40),

        // TITLE
        Text(
          data.title,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        // SUBTITLE
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            data.subtitle,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.black54,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
