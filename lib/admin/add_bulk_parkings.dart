import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

Future<void> main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  final ref = firestore.collection('parking_locations');

  print("🚀 Uploading 50 parking locations...");

  final List<Map<String, dynamic>> parkings = [

    // =============================
    // FIRST 10 PARKINGS YOU ALREADY GOT
    // =============================

    {
      "name": "Gaur Central Mall Parking",
      "lat": 28.62741,
      "lng": 77.43978,
      "price": 48,
      "rating": 4.6,
      "distance": 0.32,
      "image": "park1.png"
    },
    {
      "name": "Mahagun Metro Mall Parking",
      "lat": 28.64688,
      "lng": 77.33262,
      "price": 42,
      "rating": 4.1,
      "distance": 9.88,
      "image": "park2.png"
    },
    {
      "name": "Shipra Mall Parking",
      "lat": 28.63089,
      "lng": 77.37209,
      "price": 55,
      "rating": 4.4,
      "distance": 5.74,
      "image": "park3.png"
    },
    {
      "name": "Indirapuram Habitat Centre Parking",
      "lat": 28.64201,
      "lng": 77.37407,
      "price": 35,
      "rating": 4.0,
      "distance": 5.94,
      "image": "park1.png"
    },
    {
      "name": "Jaipuria Mall Parking",
      "lat": 28.64510,
      "lng": 77.36951,
      "price": 29,
      "rating": 3.9,
      "distance": 6.16,
      "image": "park2.png"
    },
    {
      "name": "Opulent Mall Parking",
      "lat": 28.66584,
      "lng": 77.43969,
      "price": 45,
      "rating": 4.5,
      "distance": 4.34,
      "image": "park3.png"
    },
    {
      "name": "Gaur City Mall Parking",
      "lat": 28.61927,
      "lng": 77.43428,
      "price": 51,
      "rating": 4.7,
      "distance": 0.87,
      "image": "park1.png"
    },
    {
      "name": "Rajhans Plaza Parking",
      "lat": 28.63572,
      "lng": 77.38521,
      "price": 24,
      "rating": 3.8,
      "distance": 5.08,
      "image": "park2.png"
    },
    {
      "name": "Angel Mega Mall Parking",
      "lat": 28.66391,
      "lng": 77.32401,
      "price": 58,
      "rating": 4.7,
      "distance": 12.11,
      "image": "park3.png"
    },
    {
      "name": "Spectrum Mall Parking",
      "lat": 28.61992,
      "lng": 77.37503,
      "price": 33,
      "rating": 4.2,
      "distance": 6.21,
      "image": "park1.png"
    },

    // =============================
    // 40 MORE AUTO-GENERATED PARKINGS
    // NEAR 28.626953, 77.436460
    // =============================

  ]..addAll(List.generate(40, (i) {
      double baseLat = 28.626953;
      double baseLng = 77.436460;

      return {
        "name": "Parking Spot ${i + 11}",
        "lat": baseLat + (0.01 * (i % 5)) - 0.005,
        "lng": baseLng + (0.01 * ((i ~/ 5) % 5)) - 0.005,
        "price": 20 + (i % 40),
        "rating": 3.5 + ((i % 13) * 0.1),
        "distance": (i + 1) * 0.35,
        "image": "park${(i % 3) + 1}.png",
      };
    }));

  // =============================
  // UPLOAD TO FIRESTORE
  // =============================
  for (var p in parkings) {
    await ref.add(p);
    print("✔ Added: ${p['name']}");
  }

  print("🎉 DONE — All 50 parkings uploaded successfully!");
}
