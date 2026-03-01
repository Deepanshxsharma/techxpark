import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'admin_slots_screen.dart';

class AdminFloorsScreen extends StatelessWidget {
  final String parkingId;
  final int totalFloors;

  const AdminFloorsScreen({
    super.key,
    required this.parkingId,
    required this.totalFloors,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Floors"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: totalFloors,
        itemBuilder: (_, i) {
          final floorNumber = i + 1;
          final floorId = "floor_$floorNumber";

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              title: Text(
                "Floor $floorNumber",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                // 🔥 Ensure floor document exists
                await FirebaseFirestore.instance
                    .collection("parking_locations")
                    .doc(parkingId)
                    .collection("floors")
                    .doc(floorId)
                    .set({
                  "floor_number": floorNumber,
                }, SetOptions(merge: true));

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminSlotsScreen(
                      parkingId: parkingId,
                      floorId: floorId,
                      floorNumber: floorNumber,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
