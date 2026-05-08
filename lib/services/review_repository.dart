import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/review_model.dart';

/// Centralised Firestore logic for the Rating & Review system.
class ReviewRepository {
  ReviewRepository._();
  static final instance = ReviewRepository._();

  final _firestore = FirebaseFirestore.instance;
  User? get _user => FirebaseAuth.instance.currentUser;

  /* ── References ────────────────────────────────────────────────────────── */
  CollectionReference<Map<String, dynamic>> get _reviewsCol =>
      _firestore.collection('reviews');

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  CHECK IF ALREADY REVIEWED                                             */
  /* ═══════════════════════════════════════════════════════════════════════ */
  Future<bool> hasReviewed(String bookingId) async {
    if (_user == null) return false;
    // Check booking doc for reviewed flag first (fast path)
    final bookingDoc = await _firestore
        .collection('bookings')
        .doc(bookingId)
        .get();
    if (bookingDoc.exists) {
      final data = bookingDoc.data() as Map<String, dynamic>;
      if (data['reviewed'] == true) return true;
    }
    return false;
  }

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  SUBMIT REVIEW (with transaction for safe aggregation)                 */
  /* ═══════════════════════════════════════════════════════════════════════ */
  Future<void> submitReview({
    required String parkingId,
    required String bookingId,
    required int rating,
    String reviewText = '',
    List<String> tags = const [],
  }) async {
    final user = _user;
    if (user == null) throw Exception('Not authenticated');

    // Get user name
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final userName = userDoc.data()?['name'] ?? 'User';

    final review = ReviewModel(
      id: '',
      userId: user.uid,
      userName: userName,
      bookingId: bookingId,
      parkingId: parkingId,
      rating: rating,
      reviewText: reviewText,
      tags: tags,
    );

    // Add review to top-level reviews collection
    await _reviewsCol.add(review.toMap());

    // Update parking aggregation using transaction
    final parkingRef = _firestore
        .collection('parking_locations')
        .doc(parkingId);
    await _firestore.runTransaction((tx) async {
      final parkingSnap = await tx.get(parkingRef);
      final data = parkingSnap.data() ?? {};

      final oldAvg = (data['ratingAverage'] as num?)?.toDouble() ?? 0.0;
      final oldCount = (data['ratingCount'] as num?)?.toInt() ?? 0;

      final newCount = oldCount + 1;
      final newAvg = ((oldAvg * oldCount) + rating) / newCount;

      tx.update(parkingRef, {
        'ratingAverage': double.parse(newAvg.toStringAsFixed(1)),
        'ratingCount': newCount,
      });
    });

    // Mark booking as reviewed
    await _firestore.collection('bookings').doc(bookingId).update({
      'reviewed': true,
    });
  }

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  FETCH REVIEWS                                                         */
  /* ═══════════════════════════════════════════════════════════════════════ */
  Stream<List<ReviewModel>> reviewsStream(String parkingId) {
    return _reviewsCol
        .where('parkingId', isEqualTo: parkingId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => ReviewModel.fromMap(d.id, d.data()))
              .toList(),
        );
  }
}
