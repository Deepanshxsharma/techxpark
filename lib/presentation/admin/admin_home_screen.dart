import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Add intl: ^0.18.0 to pubspec.yaml

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  // Theme Colors
  final Color _bgOffWhite = const Color(0xFFF8FAFC);
  final Color _darkGrey = const Color(0xFF1E293B);
  final Color _techBlue = const Color(0xFF2563EB);

  DateTime get _todayStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgOffWhite,
      appBar: AppBar(
        title: Text("Admin Console", style: TextStyle(color: _darkGrey, fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {}, 
            icon: CircleAvatar(
              backgroundColor: Colors.white, 
              child: Icon(Icons.person, color: _darkGrey)
            )
          )
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Overview", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 15),
            
            // ---------------- OVERVIEW GRID ----------------
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _totalParkingsCard(),
                _activeParkingsCard(),
                _activeBookingsCard(), // Warning: Needs Index
                _todayRevenueCard(),
              ],
            ),

            const SizedBox(height: 30),
            
            // ---------------- RECENT ACTIVITY ----------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Recent Bookings", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _darkGrey)),
                TextButton(onPressed: (){}, child: const Text("View All"))
              ],
            ),
            const SizedBox(height: 10),
            _buildRecentBookingsList(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STAT CARDS
  // ---------------------------------------------------------------------------
  Widget _totalParkingsCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("parking_locations").snapshots(),
      builder: (_, snap) => _statCard(
        title: "Total Locations",
        value: (snap.data?.docs.length ?? 0).toString(),
        icon: Icons.map_rounded,
        color: Colors.blue,
      ),
    );
  }

  Widget _activeParkingsCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection("parking_locations").where("status", isEqualTo: "active").snapshots(),
      builder: (_, snap) => _statCard(
        title: "Active Spots",
        value: (snap.data?.docs.length ?? 0).toString(),
        icon: Icons.check_circle_rounded,
        color: Colors.green,
      ),
    );
  }

  Widget _activeBookingsCard() {
    final now = Timestamp.fromDate(DateTime.now());
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("bookings")
          // NOTE: This query usually requires a Composite Index in Firestore Console!
          .where("startTime", isLessThanOrEqualTo: now)
          .where("endTime", isGreaterThanOrEqualTo: now)
          .snapshots(),
      builder: (_, snap) {
        if (snap.hasError) return _errorCard();
        return _statCard(
          title: "Live Vehicles",
          value: (snap.data?.docs.length ?? 0).toString(),
          icon: Icons.directions_car_filled_rounded,
          color: Colors.orange,
        );
      },
    );
  }

  Widget _todayRevenueCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("bookings")
          .where("created_at", isGreaterThanOrEqualTo: Timestamp.fromDate(_todayStart))
          .snapshots(),
      builder: (_, snap) {
        double total = 0;
        for (final doc in snap.data?.docs ?? []) {
          total += (doc["total_price"] ?? 0).toDouble();
        }
        return _statCard(
          title: "Today's Revenue",
          value: "₹${total.toStringAsFixed(0)}",
          icon: Icons.currency_rupee_rounded,
          color: Colors.purple,
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // RECENT BOOKINGS LIST
  // ---------------------------------------------------------------------------
  Widget _buildRecentBookingsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("bookings")
          .orderBy("created_at", descending: true)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Text("No recent activity");

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_,__) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final vehicle = data['vehicle'] as Map<String, dynamic>? ?? {'number': 'Unknown'};
            final date = (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now();

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10)],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.receipt_long, color: Colors.blue),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['parkingName'] ?? data['parking_name'] ?? "Unknown Parking", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text("${vehicle['vehicleNumber'] ?? vehicle['number']} • ${DateFormat('hh:mm a').format(date)}", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ),
                  Text("₹${data['total_price']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS
  // ---------------------------------------------------------------------------
  Widget _statCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Text("+2.4%", style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)), // Dummy trend
              )
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _darkGrey)),
              Text(title, style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(20)),
      child: const Center(child: Text("Index Missing\nCheck Console", textAlign: TextAlign.center, style: TextStyle(color: Colors.red, fontSize: 10))),
    );
  }
}