import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin/admin_dashboard_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../../widgets/main_shell.dart';
import '../../screens/splash/splash_screen.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasError) {
          return const OnboardingScreen();
        }

        if (!snapshot.hasData) {
          return const OnboardingScreen();
        }

        final user = snapshot.data;
        if (user == null) {
          return const OnboardingScreen();
        }

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 10)),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }

            if (snap.hasError) {
              return const MainShell();
            }

            if (!snap.hasData || !snap.data!.exists) {
              return const MainShell();
            }

            final data = snap.data!.data() ?? const <String, dynamic>{};
            if (data['banned'] == true) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                FirebaseAuth.instance.signOut();
              });
              return const SplashScreen();
            }

            final role = data['role']?.toString() ?? 'customer';

            if (role == 'admin') {
              return const AdminDashboardScreen();
            }

            return const MainShell();
          },
        );
      },
    );
  }
}
