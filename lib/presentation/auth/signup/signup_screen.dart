import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../login/login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  bool isValidEmail(String email) {
    final regex =
        RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F2FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Create Your Account",
              style: Theme.of(context)
                  .textTheme
                  .headlineLarge!
                  .copyWith(
                    color: const Color(0xff2D265E),
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Join TechXPark and start booking parking instantly.",
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 30),

            _input("Full Name", nameController, Icons.person_outline),
            const SizedBox(height: 20),

            _input("Email", emailController, Icons.email_outlined),
            const SizedBox(height: 20),

            _input(
              "Password",
              passwordController,
              Icons.lock_outline,
              obscure: obscurePassword,
              toggle: () =>
                  setState(() => obscurePassword = !obscurePassword),
            ),
            const SizedBox(height: 20),

            _input(
              "Confirm Password",
              confirmPasswordController,
              Icons.lock_outline,
              obscure: obscureConfirmPassword,
              toggle: () => setState(
                  () => obscureConfirmPassword = !obscureConfirmPassword),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: signupUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff4D6FFF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Already have an account?"),
                TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    "Login",
                    style: TextStyle(
                      color: Color(0xff4D6FFF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  Widget _input(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool obscure = false,
    VoidCallback? toggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black12.withOpacity(0.05),
                blurRadius: 8,
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(
              prefixIcon: Icon(icon),
              suffixIcon: toggle != null
                  ? IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: toggle,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 🔥 FINAL SIGNUP LOGIC (AUTH + FIRESTORE)
  // ---------------------------------------------------------------------------
  Future<void> signupUser() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final pass = passwordController.text.trim();
    final confirm = confirmPasswordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        pass.isEmpty ||
        confirm.isEmpty) {
      showSnack("Please fill all fields");
      return;
    }

    if (!isValidEmail(email)) {
      showSnack("Enter a valid email");
      return;
    }

    if (pass.length < 6) {
      showSnack("Password must be at least 6 characters");
      return;
    }

    if (pass != confirm) {
      showSnack("Passwords do not match");
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1️⃣ Create Firebase Auth user
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );

      final user = cred.user;

      // 2️⃣ Create Firestore user document
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'phone': '',
          'provider': 'email',
          'role': 'customer',
          'blocked': false,
          'banned': false,
          'isOnline': false,
          'accessStatus': 'none',
          'assignedLotId': null,
          'fcmToken': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      Navigator.pop(context);
      // ✅ DO NOT navigate manually
      // AuthWrapper will redirect automatically

    } on FirebaseAuthException catch (e) {
      Navigator.pop(context);
      showSnack(e.message ?? "Signup failed");
    }
  }

  void showSnack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}
