import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:techxpark/theme/app_colors.dart';

class AddDefaultParkingScreen extends StatefulWidget {
  const AddDefaultParkingScreen({super.key});

  @override
  State<AddDefaultParkingScreen> createState() =>
      _AddDefaultParkingScreenState();
}

class _AddDefaultParkingScreenState extends State<AddDefaultParkingScreen> {
  bool loading = false;

  final List<Map<String, dynamic>> defaultParkings = [
    {
      "name": "City Center Parking",
      "lat": 37.428,
      "lng": -122.083,
      "price": 40,
      "rating": 4.5,
      "distance": 100,
      "image": "park1.png",
    },
    {
      "name": "Central Mall Parking",
      "lat": 37.429,
      "lng": -122.087,
      "price": 30,
      "rating": 4.0,
      "distance": 250,
      "image": "park2.png",
    },
    {
      "name": "Hospital Multi Parking",
      "lat": 37.426,
      "lng": -122.086,
      "price": 20,
      "rating": 3.8,
      "distance": 300,
      "image": "park3.png",
    },
    {
      "name": "West End Parking Lot",
      "lat": 37.427,
      "lng": -122.089,
      "price": 45,
      "rating": 4.6,
      "distance": 190,
      "image": "park1.png",
    },
  ];

  Future<void> addDefaultParkings() async {
    setState(() => loading = true);

    final ref = FirebaseFirestore.instance.collection("parking_locations");

    for (var parking in defaultParkings) {
      // Check if parking already exists
      final existing = await ref
          .where("name", isEqualTo: parking["name"])
          .get();

      if (existing.docs.isEmpty) {
        await ref.add(parking);
      }
    }

    setState(() => loading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Default parkings added successfully!"),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ADMIN — Add Default Parkings"),
        centerTitle: true,
      ),

      body: Center(
        child: loading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 18,
                  ),
                ),
                onPressed: addDefaultParkings,
                child: const Text(
                  "Add Default Parkings",
                  style: TextStyle(fontSize: 18),
                ),
              ),
      ),
    );
  }
}
