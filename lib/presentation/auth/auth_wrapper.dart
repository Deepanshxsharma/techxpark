import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin/admin_dashboard_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../../widgets/main_shell.dart';
import '../../screens/splash/splash_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  Timer? _userDocTimeout;
  User? _user;
  Map<String, dynamic>? _userData;
  bool _authReady = false;
  bool _userDocLoading = false;
  Object? _userDocError;

  @override
  void initState() {
    super.initState();
    _authSub = FirebaseAuth.instance.userChanges().listen(
      _handleAuthUser,
      onError: (error) {
        debugPrint('AuthWrapper auth stream error: $error');
        if (!mounted) return;
        setState(() {
          _authReady = true;
          _user = null;
          _userData = null;
          _userDocLoading = false;
          _userDocError = error;
        });
      },
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userDocSub?.cancel();
    _userDocTimeout?.cancel();
    super.dispose();
  }

  void _handleAuthUser(User? user) {
    _userDocSub?.cancel();
    _userDocTimeout?.cancel();

    if (!mounted) return;

    if (user == null) {
      setState(() {
        _authReady = true;
        _user = null;
        _userData = null;
        _userDocLoading = false;
        _userDocError = null;
      });
      return;
    }

    setState(() {
      _authReady = true;
      _user = user;
      _userData = null;
      _userDocLoading = true;
      _userDocError = null;
    });

    _userDocTimeout = Timer(const Duration(seconds: 8), () {
      if (!mounted || _user?.uid != user.uid || !_userDocLoading) return;
      debugPrint('AuthWrapper user document load timed out; continuing.');
      setState(() {
        _userDocLoading = false;
        _userDocError = TimeoutException('User document load timed out');
      });
    });

    _userDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snap) {
            if (!mounted || _user?.uid != user.uid) return;
            _userDocTimeout?.cancel();
            setState(() {
              _userData = snap.data();
              _userDocLoading = false;
              _userDocError = null;
            });
          },
          onError: (error) {
            if (!mounted || _user?.uid != user.uid) return;
            _userDocTimeout?.cancel();
            debugPrint('AuthWrapper user document error: $error');
            setState(() {
              _userDocLoading = false;
              _userDocError = error;
            });
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    if (!_authReady) {
      return const SplashScreen();
    }

    final user = _user;
    if (user == null) {
      return const OnboardingScreen();
    }

    if (_userDocLoading) {
      return const SplashScreen();
    }

    final data = _userData ?? const <String, dynamic>{};
    if (data['banned'] == true || data['blocked'] == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FirebaseAuth.instance.signOut();
      });
      return const SplashScreen();
    }

    if (_userDocError != null) {
      debugPrint('AuthWrapper continuing without user role: $_userDocError');
    }

    final role = data['role']?.toString() ?? 'customer';
    if (role == 'admin') {
      return const AdminDashboardScreen();
    }

    return const MainShell();
  }
}
