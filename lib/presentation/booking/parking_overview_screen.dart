import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class ParkingOverviewScreen extends StatefulWidget {
  final String parkingId;

  const ParkingOverviewScreen({super.key, required this.parkingId});

  @override
  State<ParkingOverviewScreen> createState() => _ParkingOverviewScreenState();
}

class _ParkingOverviewScreenState extends State<ParkingOverviewScreen> {
  int selectedFloor = 1;

  // 🎨 App Theme Colors
  final Color _techBlue = const Color(0xFF0066FF);
  final Color _deepCharcoal = const Color(0xFF1E293B);
  final Color _slateBg = const Color(0xFFF8FAFC);
  final Color _asphalt = const Color(0xFF334155); // Dark road color
  final Color _occupiedRed = const Color(0xFFFF5252);
  final Color _freeGreen = const Color(0xFF00C853);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _slateBg,
      appBar: AppBar(
        title: Text(
          "Live Parking Grid",
          style: TextStyle(color: _deepCharcoal, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: _deepCharcoal),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Stats Header (White Card)
          _buildStatsHeader(),

          // 2. Floor Selector (Horizontal Chips)
          _buildFloorSelector(),

          // 3. Legend (Visual Guide)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendItem(_freeGreen, "Available"),
                const SizedBox(width: 20),
                _legendItem(_occupiedRed, "Occupied"),
                const SizedBox(width: 20),
                _legendItem(_techBlue, "Selected Floor"),
              ],
            ),
          ),

          // 4. The Parking Map (Asphalt Zone)
          Expanded(child: _buildParkingMap()),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsHeader() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("parking_locations")
          .doc(widget.parkingId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          );

        var data = snapshot.data!.data() as Map<String, dynamic>;
        int total = data['total_slots'] ?? 0;
        int available = data['available_slots'] ?? 0;
        int occupied = total - available;

        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statItem("Available", "$available", _freeGreen),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              _statItem("Occupied", "$occupied", _occupiedRed),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              _statItem("Total Capacity", "$total", _deepCharcoal),
            ],
          ),
        );
      },
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFloorSelector() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 3, // Assuming 3 floors, you can make this dynamic
        itemBuilder: (context, index) {
          int floorNum = index + 1;
          bool isSelected = selectedFloor == floorNum;
          return GestureDetector(
            onTap: () => setState(() => selectedFloor = floorNum),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? _techBlue : Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected ? _techBlue : Colors.grey.shade300,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _techBlue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                "Level $floorNum",
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildParkingMap() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _asphalt,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 15),
          // Road Markings
          Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          Text(
            "ENTRY",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.2),
              letterSpacing: 4,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 10),

          // The Grid
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("parking_locations")
                  .doc(widget.parkingId)
                  .collection("floors")
                  .doc("floor_$selectedFloor")
                  .collection("slots")
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );

                var slots = snapshot.data!.docs;
                if (slots.isEmpty)
                  return Center(
                    child: Text(
                      "No slots found",
                      style: TextStyle(color: Colors.white54),
                    ),
                  );

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  itemCount: (slots.length / 2).ceil(),
                  itemBuilder: (context, rowIndex) {
                    int leftIndex = rowIndex * 2;
                    int rightIndex = rowIndex * 2 + 1;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        children: [
                          // Left Bay
                          Expanded(
                            child: leftIndex < slots.length
                                ? _buildSlot(slots[leftIndex])
                                : const SizedBox(),
                          ),

                          // Road Divider
                          Container(
                            width: 50,
                            height: 60,
                            alignment: Alignment.center,
                            child: Container(
                              width: 2,
                              height: 30,
                              color: Colors.yellow.withValues(alpha: 0.4),
                            ),
                          ),

                          // Right Bay
                          Expanded(
                            child: rightIndex < slots.length
                                ? _buildSlot(slots[rightIndex])
                                : const SizedBox(),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlot(DocumentSnapshot doc) {
    String slotId = doc.id;
    bool isStaticTaken = doc['taken'] == true;

    // 🔥 SENSOR CONNECTION
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
            } catch (e) {
              print(e);
            }
          }
          return _parkingBayVisual(slotId, isLiveTaken, isLive: true);
        },
      );
    }

    return _parkingBayVisual(slotId, isStaticTaken);
  }

  Widget _parkingBayVisual(String name, bool isTaken, {bool isLive = false}) {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: isTaken
            ? _occupiedRed.withValues(alpha: 0.15)
            : _freeGreen.withValues(alpha: 0.15),
        border: Border.all(
          color: isTaken ? _occupiedRed : _freeGreen,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Slot Name
          Positioned(
            bottom: 4,
            child: Text(
              name,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ),

          // Car or Free Icon
          isTaken
              ? Icon(Icons.directions_car, color: _occupiedRed, size: 30)
              : Text(
                  "FREE",
                  style: TextStyle(
                    color: _freeGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),

          // Live Indicator Dot
          if (isLive)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isTaken ? _occupiedRed : _freeGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isTaken ? _occupiedRed : _freeGreen,
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
