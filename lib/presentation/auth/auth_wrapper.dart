import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


import '../admin/admin_dashboard_screen.dart';
import 'login/login_screen.dart';
import '../../widgets/main_shell.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        debugPrint('🔄 AuthWrapper: connectionState=${snapshot.connectionState}, hasData=${snapshot.hasData}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Handle stream error
        if (snapshot.hasError) {
          debugPrint('❌ AuthWrapper stream error: ${snapshot.error}');
          return LoginScreen();
        }

        if (!snapshot.hasData) {
          debugPrint('👤 AuthWrapper: No user, showing login');
          return LoginScreen();
        }

        final user = snapshot.data!;
        debugPrint('👤 AuthWrapper: User found: ${user.email}');

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection("users")
              .doc(user.uid)
              .get()
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  debugPrint('⏰ AuthWrapper: Firestore user doc fetch timed out');
                  throw Exception('Firestore timeout');
                },
              ),
          builder: (context, snap) {
            debugPrint('🔄 AuthWrapper FutureBuilder: connectionState=${snap.connectionState}, hasData=${snap.hasData}, hasError=${snap.hasError}');

            if (snap.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Handle Firestore errors (timeout, network, permission)
            if (snap.hasError) {
              debugPrint('❌ AuthWrapper Firestore error: ${snap.error}');
              // On error, try to show dashboard anyway (user IS authenticated)
              return const MainShell();
            }

            if (!snap.hasData || !snap.data!.exists) {
              debugPrint('⚠️ AuthWrapper: User doc does not exist, showing dashboard');
              return const MainShell();
            }

            final data = snap.data!.data() as Map<String, dynamic>?;
            final role = data?["role"] ?? "user";
            debugPrint('👤 AuthWrapper: role=$role');

            // 🔐 ADMIN ROUTE
            if (role == "admin") {
              return const AdminDashboardScreen();
            }

            // 👤 NORMAL USER
            return const MainShell();
          },
        );
      },
    );
  }
}
