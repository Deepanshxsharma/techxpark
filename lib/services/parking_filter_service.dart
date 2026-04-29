import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ParkingFilterService {
  ParkingFilterService._();

  static const String evFilterLabel = 'EV Charging';
  static const String allFilterLabel = 'All Lots';

  static bool isEvFilter(String filter) {
    final normalized = filter.trim().toLowerCase();
    return normalized == 'ev' ||
        normalized == 'ev charging' ||
        normalized == 'evcharging';
  }

  static String filterKey(String filter) => isEvFilter(filter) ? 'ev' : 'all';

  static Query<Map<String, dynamic>> parkingQuery(
    String filter, {
    String collectionName = 'parking_locations',
    int limit = 50,
  }) {
    debugPrint('FILTER: ${filterKey(filter)}');

    return FirebaseFirestore.instance.collection(collectionName).limit(limit);
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> streamParking(
    String filter, {
    String collectionName = 'parking_locations',
    int limit = 50,
  }) {
    return parkingQuery(
      filter,
      collectionName: collectionName,
      limit: limit,
    ).snapshots();
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> fetchParking(
    String filter, {
    String collectionName = 'parking_locations',
    int limit = 50,
  }) {
    return parkingQuery(
      filter,
      collectionName: collectionName,
      limit: limit,
    ).get();
  }
}
