import 'package:techxpark/theme/app_colors.dart';
import 'package:techxpark/theme/app_text_styles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'parking_ticket_screen.dart';
import 'parking_timer_screen.dart';
import 'rating_bottom_sheet.dart';
import 'indoor_navigation_screen.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Please login again")),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(
          "My History",
          style: AppTextStyles.h2,
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: CircleAvatar(
            backgroundColor: Colors.white,
            child: Icon(Icons.arrow_back, color: AppColors.textPrimaryLight),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("bookings")
            .where("userId", isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                snapshot.error.toString(),
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final bookings = snapshot.data!.docs;

          // Compute active booking count
          int activeCount = 0;
          for (var doc in bookings) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? '';
            if (status == 'active' || status == 'upcoming') {
              activeCount++;
            }
          }

          // Sort by start time (latest first)
          bookings.sort((a, b) {
            final t1 = (a.data() as Map)["startTime"] as Timestamp?;
            final t2 = (b.data() as Map)["startTime"] as Timestamp?;
            if (t1 == null || t2 == null) return 0;
            return t2.compareTo(t1);
          });

          return Column(
            children: [
              _buildProgressCard(activeCount),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: bookings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final doc = bookings[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _buildBookingCard(context, doc.id, data);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SUMMARY PROGRESS CARD
  // ---------------------------------------------------------------------------
  Widget _buildProgressCard(int activeCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_parking_rounded, color: Color(0xFF2563EB), size: 24),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Active Bookings",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "$activeCount active parking ${activeCount == 1 ? 'slot' : 'slots'}",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY STATE
  // ---------------------------------------------------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 80, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            "No Bookings Found",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Try booking a slot first!",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BOOKING CARD
  // ---------------------------------------------------------------------------
  Widget _buildBookingCard(
    BuildContext context,
    String bookingId,
    Map<String, dynamic> data,
  ) {
    final parkingName = data["parkingName"] ?? data["parking_name"] ?? "Parking Location";
    final slot = data["slotId"] ?? data["slot_id"] ?? "--";
    final floorIndex = data["floor"] ?? 0;
    final vehicle = data["vehicle"] ?? {};
    final status = data["status"] ?? "active";
    final start = (data["startTime"] ?? data["start_ts"] as Timestamp).toDate();
    final end = (data["endTime"] ?? data["end_ts"] as Timestamp).toDate();

    final isCancelled = data['status'] == 'cancelled';
    final isUpcoming = !isCancelled && DateTime.now().isBefore(start);
    final isActive =
        !isCancelled && DateTime.now().isAfter(start) && DateTime.now().isBefore(end);
    final isCompleted = !isUpcoming && !isActive && !isCancelled;
    final isReviewed = data['reviewed'] == true;
    final parkingLocationId = data['parkingId'] ?? data['parking_id'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statusIcon(isActive, isUpcoming, isCancelled),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parkingName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Slot $slot • Floor ${floorIndex + 1}",
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                isCancelled
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "CANCELLED",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.red.shade600,
                          ),
                        ),
                      )
                    : Text(
                        "FREE",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
              ],
            ),
          ),

          _ticketDivider(),

          // BODY
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _infoColumn("VEHICLE",
                          vehicle["number"].toString().toUpperCase()),
                    ),
                    Expanded(
                      child: _infoColumn(
                          "DATE", DateFormat("d MMM").format(start)),
                    ),
                    Expanded(
                      child: _infoColumn(
                        "TIME",
                        "${DateFormat('HH:mm').format(start)} - ${DateFormat('HH:mm').format(end)}",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ParkingTicketScreen(
                                parking: {
                                  "name": parkingName,
                                  "address":
                                      data["address"] ?? "TechXPark Location",
                                  "latitude": data["latitude"],
                                  "longitude": data["longitude"],
                                },
                                slot: slot,
                                floorIndex: floorIndex,
                                start: start,
                                end: end,
                                vehicle: vehicle,
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimaryLight,
                          side:
                              BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                        ),
                        child: const Text(
                          "View Ticket",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (isActive || isUpcoming) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ParkingTimerScreen(
                                  bookingId: bookingId,
                                  parking: {"name": parkingName},
                                  slot: slot,
                                  floorIndex: floorIndex,
                                  start: start,
                                  end: end,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.textPrimaryLight,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                          child: const Text(
                            "Open Timer",
                            style:
                                TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                    if (isActive || isUpcoming) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => IndoorNavigationScreen(
                                  parkingId: parkingLocationId,
                                  parkingName: parkingName,
                                  bookedSlotId: slot,
                                  bookedFloor: floorIndex is int ? floorIndex : 0,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.navigation_rounded, size: 16),
                          label: const Text(
                            'Navigate',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                    if (isCompleted && !isReviewed && parkingLocationId.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showRatingBottomSheet(
                              context: context,
                              parkingId: parkingLocationId,
                              parkingName: parkingName,
                              bookingId: bookingId,
                            );
                          },
                          icon: const Icon(Icons.star_rounded, size: 18),
                          label: const Text('Rate',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFBBF24),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  Widget _statusIcon(bool isActive, bool isUpcoming, bool isCancelled) {
    Color color;
    IconData icon;

    if (isCancelled) {
      color = Colors.red;
      icon = Icons.cancel_rounded;
    } else if (isActive) {
      color = Colors.green;
      icon = Icons.local_parking_rounded;
    } else if (isUpcoming) {
      color = Colors.orange;
      icon = Icons.schedule_rounded;
    } else {
      color = Colors.grey;
      icon = Icons.history_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _ticketDivider() {
    return SizedBox(
      height: 20,
      child: Stack(
        children: [
          const Center(
            child: Divider(
              color: Color(0xFFEEEEEE),
              thickness: 1.5,
              indent: 20,
              endIndent: 20,
            ),
          ),
          Positioned(
            left: -10,
            top: 0,
            bottom: 0,
             child: CircleAvatar(radius: 10, backgroundColor: AppColors.bgLight),
          ),
          Positioned(
            right: -10,
            top: 0,
            bottom: 0,
             child: CircleAvatar(radius: 10, backgroundColor: AppColors.bgLight),
          ),
        ],
      ),
    );
  }

  Widget _infoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style:
              TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimaryLight),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ],
    );
  }
}
