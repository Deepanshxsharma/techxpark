import 'package:cloud_firestore/cloud_firestore.dart';

class BookingCleanupService {
  BookingCleanupService._();

  static final BookingCleanupService instance = BookingCleanupService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isRunning = false;

  Future<void> cleanupExpiredBookings() async {
    if (_isRunning) return;
    _isRunning = true;

    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('bookings')
          .where('status', whereIn: const ['active', 'upcoming'])
          .where('endTime', isLessThan: Timestamp.fromDate(now))
          .limit(25)
          .get();

      for (final doc in snapshot.docs) {
        await _firestore.runTransaction((tx) async {
          final bookingRef = doc.reference;
          final bookingSnap = await tx.get(bookingRef);
          if (!bookingSnap.exists) return;

          final data = bookingSnap.data() ?? <String, dynamic>{};
          final status = data['status']?.toString() ?? '';
          if (status != 'active' && status != 'upcoming') return;

          final endTime = (data['endTime'] as Timestamp?)?.toDate();
          if (endTime == null || endTime.isAfter(now)) return;

          final nextStatus = status == 'upcoming' ? 'cancelled' : 'completed';
          tx.update(bookingRef, {
            'status': nextStatus,
            'updatedAt': FieldValue.serverTimestamp(),
            if (nextStatus == 'completed')
              'completedAt': FieldValue.serverTimestamp(),
            if (nextStatus == 'cancelled')
              'cancelledAt': FieldValue.serverTimestamp(),
          });

          final parkingId = data['parkingId']?.toString() ?? '';
          final slotId = data['slotId']?.toString() ?? '';
          if (parkingId.isNotEmpty && slotId.isNotEmpty) {
            final parkingRef = _firestore
                .collection('parking_locations')
                .doc(parkingId);
            final slotRef = parkingRef.collection('slots').doc(slotId);
            final slotSnap = await tx.get(slotRef);

            if (slotSnap.exists) {
              tx.update(slotRef, {
                'taken': false,
                'isOccupied': false,
                'isReserved': false,
                'status': 'available',
                'lastUpdated': FieldValue.serverTimestamp(),
              });
            }

            tx.update(parkingRef, {
              'availableSlots': FieldValue.increment(1),
              'available_slots': FieldValue.increment(1),
              'lastUpdated': FieldValue.serverTimestamp(),
            });
          }

          final userId = data['userId']?.toString() ?? '';
          if (userId.isNotEmpty) {
            tx.set(_firestore.collection('users').doc(userId), {
              'activeBookings': FieldValue.increment(-1),
              'currentBookingId': FieldValue.delete(),
            }, SetOptions(merge: true));
          }
        });
      }
    } catch (_) {
      // Best effort cleanup only.
    } finally {
      _isRunning = false;
    }
  }
}