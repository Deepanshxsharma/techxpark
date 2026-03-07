import 'package:cloud_firestore/cloud_firestore.dart';

Future<int> getActiveBookingCount(String userId) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('bookings')
      .where('userId', isEqualTo: userId)
      .where('status', whereIn: ['active', 'upcoming'])
      .get();
  return snapshot.docs.length;
}
