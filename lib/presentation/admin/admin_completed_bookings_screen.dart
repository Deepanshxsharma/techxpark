import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminCompletedBookingsScreen extends StatelessWidget {
  const AdminCompletedBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final now = Timestamp.now();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("bookings")
          .where("endTime", isLessThanOrEqualTo: now)
          .orderBy("endTime", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final bookings = snapshot.data!.docs;

        if (bookings.isEmpty) {
          return const Center(child: Text("No completed bookings"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          itemBuilder: (_, i) {
            final data = bookings[i].data() as Map<String, dynamic>;
            final vehicle = data["vehicle"] ?? {};

            return _bookingCard(
              parking: data["parkingName"] ?? data["parking_name"],
              slot: data["slotId"] ?? data["slot_id"],
              floor: data["floor"],
              vehicleNo: vehicle["vehicleNumber"] ?? vehicle["number"] ?? "UNKNOWN",
              amount: data["total_price"],
            );
          },
        );
      },
    );
  }

  Widget _bookingCard({
    required String parking,
    required String slot,
    required int floor,
    required String vehicleNo,
    required int amount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(parking,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text("Slot: $slot • Floor ${floor + 1}"),
          const SizedBox(height: 6),
          Text("Vehicle: $vehicleNo"),
          const SizedBox(height: 10),
          Text(
            "₹$amount",
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
