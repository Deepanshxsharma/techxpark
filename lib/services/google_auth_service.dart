import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class GoogleAuthService {
  GoogleAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  Future<UserCredential?> signInWithGoogle(BuildContext context) async {
    try {
      final googleSignIn = GoogleSignIn(scopes: const ['email', 'profile']);
      await googleSignIn.signOut();

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final auth = await googleUser.authentication;
      if (auth.idToken == null) {
        throw Exception('No ID token');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) {
        throw Exception('No user returned');
      }

      if (!context.mounted) return null;
      final allowed = await syncUserAfterSignIn(
        context,
        user,
        provider: 'google',
      );
      return allowed ? userCredential : null;
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return null;
      _handleAuthError(context, e.code);
      return null;
    } on PlatformException catch (e) {
      debugPrint('Google sign in platform error: ${e.code}');
      if (!context.mounted) return null;
      _handleAuthError(context, e.code);
      return null;
    } catch (e) {
      debugPrint('Google sign in error: $e');
      if (!context.mounted) return null;
      _showError(context, 'Sign in failed. Please try again.');
      return null;
    }
  }

  Future<UserCredential?> signInWithApple(BuildContext context) async {
    try {
      final nonce = _generateNonce();
      final nonceHash = _sha256ofString(nonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonceHash,
      );

      final identityToken = appleCredential.identityToken;
      if (identityToken == null) {
        throw Exception('Missing Apple identity token');
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: identityToken,
        rawNonce: nonce,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = userCredential.user;
      if (user == null) {
        throw Exception('No user returned');
      }

      if ((user.displayName ?? '').trim().isEmpty) {
        final givenName = appleCredential.givenName ?? '';
        final familyName = appleCredential.familyName ?? '';
        final displayName = '$givenName $familyName'.trim();
        if (displayName.isNotEmpty) {
          await user.updateDisplayName(displayName);
        }
      }

      if (!context.mounted) return null;
      final allowed = await syncUserAfterSignIn(
        context,
        user,
        provider: 'apple',
        fallbackName: '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
            .trim(),
      );
      return allowed ? userCredential : null;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (!context.mounted) return null;
      if (e.code != AuthorizationErrorCode.canceled) {
        _showError(context, 'Apple sign in failed: ${e.message}');
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return null;
      _handleAuthError(context, e.code);
      return null;
    } catch (e) {
      debugPrint('Apple sign in error: $e');
      if (!context.mounted) return null;
      _showError(context, 'Sign in failed. Please try again.');
      return null;
    }
  }

  Future<bool> syncUserAfterSignIn(
    BuildContext context,
    User user, {
    required String provider,
    String? fallbackName,
  }) async {
    try {
      await _createOrUpdateUserDoc(
        user,
        provider: provider,
        fallbackName: fallbackName,
      );
      return true;
    } on _BannedUserException {
      await signOut();
      if (!context.mounted) return false;
      _showError(
        context,
        'Your account has been suspended. Contact support@techxpark.in',
      );
      return false;
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return false;
      _handleAuthError(context, e.code);
      return false;
    } catch (e) {
      debugPrint('User sync error: $e');
      if (!context.mounted) return false;
      _showError(context, 'Sign in failed. Please try again.');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {
      // Ignore cached Google sign-out failures.
    }
    await _auth.signOut();
  }

  Future<void> _createOrUpdateUserDoc(
    User user, {
    required String provider,
    String? fallbackName,
  }) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final doc = await ref.get();
    final data = doc.data() ?? const <String, dynamic>{};

    if (data['banned'] == true) {
      throw const _BannedUserException();
    }

    final resolvedName = _resolveDisplayName(
      user: user,
      fallbackName: fallbackName,
      data: data,
    );

    if (!doc.exists) {
      await ref.set({
        'uid': user.uid,
        'name': resolvedName,
        'email': user.email ?? '',
        'phone': user.phoneNumber ?? '',
        'photoUrl': user.photoURL ?? '',
        'provider': provider,
        'role': 'customer',
        'createdAt': FieldValue.serverTimestamp(),
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        'fcmToken': null,
        'banned': false,
        'blocked': false,
        'accessStatus': 'none',
        'assignedLotId': null,
        'totalBookings': 0,
        'totalHours': 0,
      });
    } else {
      await ref.set({
        'provider': provider,
        'isOnline': true,
        'lastSeen': FieldValue.serverTimestamp(),
        if (resolvedName.isNotEmpty) 'name': resolvedName,
        if ((user.email ?? '').isNotEmpty) 'email': user.email,
        if ((user.phoneNumber ?? '').isNotEmpty) 'phone': user.phoneNumber,
        if ((user.photoURL ?? '').isNotEmpty) 'photoUrl': user.photoURL,
      }, SetOptions(merge: true));
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await ref.set({'fcmToken': token}, SetOptions(merge: true));
    }
  }

  String _resolveDisplayName({
    required User user,
    required Map<String, dynamic> data,
    String? fallbackName,
  }) {
    final displayName = user.displayName?.trim() ?? '';
    if (displayName.isNotEmpty) return displayName;

    final fallback = fallbackName?.trim() ?? '';
    if (fallback.isNotEmpty) return fallback;

    final stored = data['name']?.toString().trim() ?? '';
    if (stored.isNotEmpty) return stored;

    return 'TechXPark User';
  }

  void _handleAuthError(BuildContext context, String code) {
    final message = switch (code) {
      'account-exists-with-different-credential' =>
        'This email is already linked to another sign-in method.',
      'invalid-credential' => 'The sign-in credential is invalid or expired.',
      'user-disabled' => 'This account has been disabled.',
      'network-request-failed' => 'Network error. Check your connection and try again.',
      'sign_in_failed' => 'Google sign in failed. Please try again.',
      'sign_in_canceled' => 'Sign in was canceled.',
      _ => 'Sign in failed. Please try again.',
    };
    _showError(context, message);
  }

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _generateNonce([int length = 32]) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

class _BannedUserException implements Exception {
  const _BannedUserException();
}
