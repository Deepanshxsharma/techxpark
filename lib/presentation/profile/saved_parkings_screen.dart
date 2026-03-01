import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SavedParkingsScreen extends StatelessWidget {
  const SavedParkingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please login again")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Saved Parkings")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData =
              userSnap.data!.data() as Map<String, dynamic>? ?? {};

          final List savedIds =
              userData["saved_parkings"] ?? [];

          if (savedIds.isEmpty) {
            return const Center(
              child: Text("No saved parkings yet"),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: savedIds.length,
            itemBuilder: (context, index) {
              final parkingId = savedIds[index];

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("parking_locations")
                    .doc(parkingId)
                    .snapshots(),
                builder: (context, parkSnap) {
                  if (!parkSnap.hasData) {
                    return const SizedBox();
                  }

                  final parking =
                      parkSnap.data!.data() as Map<String, dynamic>?;

                  if (parking == null) return const SizedBox();

                  return _parkingCard(
                    context,
                    parkingId,
                    parking,
                    user.uid,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ================= CARD =================

  Widget _parkingCard(
    BuildContext context,
    String parkingId,
    Map<String, dynamic> parking,
    String uid,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListTile(
        title: Text(
          parking["name"] ?? "Parking",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          parking["address"] ?? "",
        ),
        trailing: IconButton(
          icon: const Icon(Icons.bookmark_remove, color: Colors.red),
          onPressed: () async {
            await FirebaseFirestore.instance
                .collection("users")
                .doc(uid)
                .update({
              "saved_parkings": FieldValue.arrayRemove([parkingId])
            });
          },
        ),
        onTap: () {
          // 👉 Later: navigate to Parking Details / Map
        },
      ),
    );
  }
}
