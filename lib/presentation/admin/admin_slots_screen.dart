import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSlotsScreen extends StatelessWidget {
  final String parkingId;
  final String floorId;
  final int floorNumber;

  const AdminSlotsScreen({
    super.key,
    required this.parkingId,
    required this.floorId,
    required this.floorNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Floor $floorNumber Slots"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.black,
        child: const Icon(Icons.add),
        onPressed: () async {
          final slotCountSnap = await FirebaseFirestore.instance
              .collection("parking_locations")
              .doc(parkingId)
              .collection("floors")
              .doc(floorId)
              .collection("slots")
              .get();

          final nextSlotNumber = slotCountSnap.docs.length + 1;

          await FirebaseFirestore.instance
              .collection("parking_locations")
              .doc(parkingId)
              .collection("floors")
              .doc(floorId)
              .collection("slots")
              .add({
            "slot_number": "S$nextSlotNumber",
            "taken": false,
            "enabled": true,
            "created_at": FieldValue.serverTimestamp(),
          });
        },
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("parking_locations")
            .doc(parkingId)
            .collection("floors")
            .doc(floorId)
            .collection("slots")
            .orderBy("created_at")
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final slots = snapshot.data!.docs;

          if (slots.isEmpty) {
            return const Center(
              child: Text("No slots created yet"),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: slots.length,
            itemBuilder: (_, i) {
              final doc = slots[i];
              final data = doc.data() as Map<String, dynamic>;
              final enabled = data["enabled"] == true;

              return GestureDetector(
                onTap: () async {
                  await doc.reference.update({
                    "enabled": !enabled,
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: enabled
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data["slot_number"],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          enabled ? "ENABLED" : "DISABLED",
                          style: TextStyle(
                            fontSize: 12,
                            color: enabled
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
