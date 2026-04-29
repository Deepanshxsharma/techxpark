// lib/presentation/saved/saved_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_colors.dart';
import '../../services/bookmark_service.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<Map<String, dynamic>> savedParkings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadBookmarks();
  }

  Future<void> loadBookmarks() async {
    final list = await BookmarkService.getBookmarks();
    setState(() {
      savedParkings = list;
      isLoading = false;
    });
  }

  Future<void> removeItem(String id, int index) async {
    await BookmarkService.removeBookmark(id);

    setState(() {
      savedParkings.removeAt(index);
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Removed from saved")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Parkings"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : savedParkings.isEmpty
          ? const Center(
              child: Text(
                "No saved parkings yet",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: savedParkings.length,
              itemBuilder: (context, index) {
                final park = savedParkings[index];

                return _parkingCard(park, index);
              },
            ),
    );
  }

  Widget _parkingCard(Map<String, dynamic> park, int index) {
    final String id = park["id"] ?? "";
    final String name = park["name"] ?? "Parking Spot";
    final String address = park["address"] ?? "No address";
    final int price = park["price_per_hour"] ?? 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        contentPadding: const EdgeInsets.all(14),
        title: Text(
          name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(address, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 4),
              Text(
                "₹$price / hour",
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        trailing: IconButton(
          icon: const Icon(Icons.bookmark_remove, color: Colors.red),
          onPressed: () => removeItem(id, index),
        ),

        onTap: () {
          // Open location in Firestore
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ParkingDetailsFromSaved(id: id)),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------
// OPEN PARKING DETAILS FROM FIRESTORE (LIVE)
// ---------------------------------------------------------------------

class ParkingDetailsFromSaved extends StatelessWidget {
  final String id;

  const ParkingDetailsFromSaved({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection("parking_locations")
        .doc(id);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Parking Details"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: ref.get(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.data!.exists) {
            return const Center(child: Text("Parking no longer exists"));
          }

          final park = snap.data!.data() as Map<String, dynamic>;

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  park["name"] ?? "Parking",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "₹${park['price_per_hour']} / hour",
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 10),
                Text("Floors: ${park['total_floors']}"),
                Text("Spots per Floor: ${park['spots_per_floor']}"),
                Text("Address: ${park['address'] ?? 'N/A'}"),

                const Spacer(),

                ElevatedButton(
                  onPressed: () {
                    // maybe go to booking screen later
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text("Book Parking"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
