import 'package:cloud_firestore/cloud_firestore.dart';

/// Call this once to auto-create slots for a parking.
/// parkingId = Firestore document ID in `parkings` collection.
/// floors = number of floors (default 3)
/// slotsPerFloor = how many slots per floor (default 8)

Future<void> generateSlotsForParking(String parkingId,
    {int floors = 3, int slotsPerFloor = 8}) async {
  final Map<String, bool> slotMap = {};

  for (int f = 1; f <= floors; f++) {
    for (int s = 1; s <= slotsPerFloor; s++) {
      final slotId = 'F${f}A${s.toString().padLeft(2, '0')}';
      slotMap[slotId] = false; // all free initially
    }
  }

  await FirebaseFirestore.instance
      .collection('parking_locations')
      .doc(parkingId)
      .update({"slots": slotMap});

  print("✅ Slots added for parking $parkingId");
}
