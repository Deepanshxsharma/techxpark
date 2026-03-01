import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MostUsedParkingService {
  static Future<List<String>> fetchMostUsedParkings(
      {int limit = 3}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: user.uid)
        .get();

    final Map<String, int> parkingCount = {};

    for (var doc in snapshot.docs) {
      final name = doc['parkingName'] ?? doc['parking_name'];
      if (name != null) {
        parkingCount[name] = (parkingCount[name] ?? 0) + 1;
      }
    }

    final sorted = parkingCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => e.key).toList();
  }
}
