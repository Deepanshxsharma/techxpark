import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Logs suspicious and failed booking actions to `booking_audit_log`.
/// Used for fraud detection, analytics, and potential soft-ban decisions.
class AbuseMonitor {
  AbuseMonitor._();
  static final instance = AbuseMonitor._();

  final _fs = FirebaseFirestore.instance;

  /// Log a failed or suspicious booking action.
  Future<void> logEvent({
    required String action,
    required String reason,
    Map<String, dynamic> metadata = const {},
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await _fs.collection('booking_audit_log').add({
        'userId': user?.uid ?? 'anonymous',
        'action': action,
        'reason': reason,
        'metadata': metadata,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('⚠️ AbuseMonitor log failed: $e');
    }
  }

  /// Check if user has too many recent failed attempts (potential abuse).
  /// Returns true if suspicious (>5 failures in last 10 minutes).
  Future<bool> isSuspicious(String userId) async {
    try {
      final tenMinAgo = DateTime.now().subtract(const Duration(minutes: 10));
      final snap = await _fs
          .collection('booking_audit_log')
          .where('userId', isEqualTo: userId)
          .where('timestamp',
              isGreaterThan: Timestamp.fromDate(tenMinAgo))
          .get();

      return snap.docs.length > 5;
    } catch (e) {
      debugPrint('⚠️ AbuseMonitor check failed: $e');
      return false;
    }
  }
}
