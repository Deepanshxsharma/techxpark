import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart'; // Required for kIsWeb

import '../../theme/app_colors.dart';

class ParkingLandscapeScreen extends StatefulWidget {
  final String parkingId;

  const ParkingLandscapeScreen({super.key, required this.parkingId});

  @override
  State<ParkingLandscapeScreen> createState() => _ParkingLandscapeScreenState();
}

class _ParkingLandscapeScreenState extends State<ParkingLandscapeScreen> {
  int selectedFloor = 1;

  // 🖥️ Web Dashboard Theme
  final Color _bg = const Color(0xFF101418);
  final Color _panelColor = const Color(0xFF1E293B);
  final Color _freeGreen = const Color(0xFF00E676);
  final Color _occupiedRed = const Color(0xFFFF1744);

  @override
  Widget build(BuildContext context) {
    // 📏 Responsive Layout Logic
    double width = MediaQuery.of(context).size.width;

    // On Web, use more columns (6 for desktop, 4 for tablet size)
    int gridColumns = width > 1200 ? 6 : (width > 800 ? 4 : 3);

    // Sidebar width is fixed on desktop, slightly smaller on tablets
    double sidebarWidth = width > 1000 ? 300 : 250;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          "Dashboard Mode",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _panelColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Row(
        children: [
          // ------------------------------------------------
          // 1. LEFT PANEL (Fixed Width Sidebar)
          // ------------------------------------------------
          Container(
            width: sidebarWidth,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _panelColor,
              border: const Border(right: BorderSide(color: Colors.white10)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_parking_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      "STATUS",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                  ],
                ),

                const Divider(color: Colors.white10, height: 40),

                // Live Stats
                Expanded(
                  child: _buildSidebarStats(),
                ), // Uses Expanded to avoid overflow

                const Divider(color: Colors.white10, height: 40),

                // Floor Toggles
                const Text(
                  "SELECT LEVEL",
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                _buildCompactFloorTabs(),
              ],
            ),
          ),

          // ------------------------------------------------
          // 2. RIGHT PANEL (The Grid - Takes remaining space)
          // ------------------------------------------------
          Expanded(
            child: Column(
              children: [
                // Grid Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: _bg,
                    border: const Border(
                      bottom: BorderSide(color: Colors.white10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "LEVEL $selectedFloor",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                      _legendRow(),
                    ],
                  ),
                ),

                // The Grid (Scrollable)
                Expanded(child: _buildLandscapeGrid(gridColumns)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _legendRow() {
    return Row(
      children: [
        _dot(_freeGreen),
        const SizedBox(width: 8),
        const Text(
          "Free",
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const SizedBox(width: 24),
        _dot(_occupiedRed),
        const SizedBox(width: 8),
        const Text(
          "Busy",
          style: TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ],
    );
  }

  Widget _dot(Color c) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );

  Widget _buildSidebarStats() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("parking_locations")
          .doc(widget.parkingId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        var data = snapshot.data!.data() as Map<String, dynamic>;

        int total = data['total_slots'] ?? 0;
        int available = data['available_slots'] ?? 0;
        int occupied = total - available;

        return Column(
          children: [
            _statCard("FREE", "$available", _freeGreen),
            const SizedBox(height: 20),
            _statCard("BUSY", "$occupied", _occupiedRed),
          ],
        );
      },
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactFloorTabs() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [1, 2, 3].map((i) {
        bool isSelected = selectedFloor == i;
        return InkWell(
          onTap: () => setState(() => selectedFloor = i),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 60,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.white10,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.transparent,
              ),
            ),
            child: Text(
              "$i",
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white38,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLandscapeGrid(int crossAxisCount) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("parking_locations")
          .doc(widget.parkingId)
          .collection("floors")
          .doc("floor_$selectedFloor")
          .collection("slots")
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var slots = snapshot.data!.docs;
        if (slots.isEmpty)
          return const Center(
            child: Text("No Slots", style: TextStyle(color: Colors.white24)),
          );

        return GridView.builder(
          padding: const EdgeInsets.all(32),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 2.0, // Wider cards for Desktop monitors
          ),
          itemCount: slots.length,
          itemBuilder: (context, index) {
            return _buildSlotCard(slots[index]);
          },
        );
      },
    );
  }

  Widget _buildSlotCard(DocumentSnapshot doc) {
    String slotId = doc.id;
    bool isStaticTaken = doc['taken'] == true;

    // 🔥 SENSOR LOGIC
    if (slotId == "F1A04" && widget.parkingId == 'gardenia_apartment_parking') {
      return StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref("sensor_slots/$slotId").onValue,
        builder: (context, sensorSnap) {
          bool isLiveTaken = false;
          if (sensorSnap.hasData && sensorSnap.data!.snapshot.value != null) {
            try {
              final val = sensorSnap.data!.snapshot.value;
              if (val is Map)
                isLiveTaken = val['taken'] == true;
              else if (val is bool)
                isLiveTaken = val;
            } catch (_) {}
          }
          return _visualCard(slotId, isLiveTaken);
        },
      );
    }
    return _visualCard(slotId, isStaticTaken);
  }

  Widget _visualCard(String id, bool isOccupied) {
    Color bg = isOccupied
        ? _occupiedRed.withValues(alpha: 0.15)
        : _freeGreen.withValues(alpha: 0.15);
    Color border = isOccupied ? _occupiedRed : _freeGreen;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border.withValues(alpha: 0.6), width: 2),
          boxShadow: [
            BoxShadow(color: border.withValues(alpha: 0.15), blurRadius: 12),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                id,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              isOccupied
                  ? Icon(Icons.directions_car, color: _occupiedRed, size: 36)
                  : Text(
                      "FREE",
                      style: TextStyle(
                        color: _freeGreen,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
