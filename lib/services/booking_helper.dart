import 'package:cloud_firestore/cloud_firestore.dart';

import 'booking_status_helper.dart';

import 'booking_status_helper.dart';

Future<int> getActiveBookingCount(String userId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('bookings')
      .where('userId', isEqualTo: userId)
      .where('status', whereIn: BookingStatusHelper.blockingStatuses)
      .get();
  return snapshot.docs.length;
}
