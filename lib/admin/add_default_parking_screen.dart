import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'generate_slots.dart';   // ⭐ IMPORTANT: import our slot generator

class AddDefaultParkingScreen extends StatelessWidget {
  const AddDefaultParkingScreen({super.key});

  // =========================================================
  // ADD DEFAULT PARKINGS
  // =========================================================
  Future<void> addDefaultParkings(BuildContext context) async {
    final CollectionReference ref =
        FirebaseFirestore.instance.collection('parking_locations');

    final List<Map<String, dynamic>> parkings = [
      {
        "name": "City Center Parking – Crossings Republik",
        "lat": 28.64752,
        "lng": 77.44281,
        "distance": 150,
        "rating": 4.5,
        "price": 40,
        "image": "park1.png",
      },
      {
        "name": "Gaur City Mall Parking",
        "lat": 28.62065,
        "lng": 77.44030,
        "distance": 3100,
        "rating": 4.3,
        "price": 50,
        "image": "park1.png",
      },
      {
        "name": "Mahagun Mart Parking",
        "lat": 28.62941,
        "lng": 77.44174,
        "distance": 2000,
        "rating": 4.1,
        "price": 30,
        "image": "park1.png",
      },
      {
        "name": "ABES Engineering College Parking",
        "lat": 28.64843,
        "lng": 77.44219,
        "distance": 180,
        "rating": 4.2,
        "price": 20,
        "image": "park1.png",
      },
      {
        "name": "Eco Village 2 Market Parking",
        "lat": 28.60992,
        "lng": 77.45411,
        "distance": 4100,
        "rating": 4.0,
        "price": 20,
        "image": "park1.png",
      },
      {
        "name": "Ryan International School Parking",
        "lat": 28.63912,
        "lng": 77.45013,
        "distance": 1200,
        "rating": 4.1,
        "price": 10,
        "image": "park1.png",
      },
      {
        "name": "Galleria Market Parking",
        "lat": 28.63177,
        "lng": 77.45391,
        "distance": 2400,
        "rating": 4.4,
        "price": 30,
        "image": "park1.png",
      },
    ];

    try {
      for (var p in parkings) {
        await ref.add(p);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All default parkings added successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  // =========================================================
  // UI
  // =========================================================
  @override
  Widget build(BuildContext context) {
    TextEditingController idController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Tools"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // BUTTON — ADD DEFAULT PARKINGS
            ElevatedButton(
              onPressed: () => addDefaultParkings(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 40),
              ),
              child: const Text(
                "Add All Default Parkings",
                style: TextStyle(fontSize: 18),
              ),
            ),

            const SizedBox(height: 40),

            // TEXT FIELD — ENTER PARKING ID
            TextField(
              controller: idController,
              decoration: InputDecoration(
                labelText: "Enter Parking Document ID",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // BUTTON — GENERATE SLOTS FOR THAT ID
            ElevatedButton(
              onPressed: () async {
                if (idController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Enter a valid Parking Document ID")),
                  );
                  return;
                }

                await generateSlotsForParking(idController.text.trim());

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Slots generated successfully!"),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding:
                    const EdgeInsets.symmetric(vertical: 15, horizontal: 40),
              ),
              child: const Text(
                "Generate Slots",
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
