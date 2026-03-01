import 'package:techxpark/theme/app_colors.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AdminLiveBookingsScreen extends StatefulWidget {
  const AdminLiveBookingsScreen({super.key});

  @override
  State<AdminLiveBookingsScreen> createState() => _AdminLiveBookingsScreenState();
}

class _AdminLiveBookingsScreenState extends State<AdminLiveBookingsScreen> {
  late Timer _timer;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Brand Colors
  final Color _bgLight = const Color(0xFFF8FAFC);
  final Color _darkHeader = const Color(0xFF0F172A);
  final Color _primaryBlue = AppColors.primary;
  final Color _urgentRed = const Color(0xFFEF4444);
  final Color _safeGreen = const Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    // Refresh UI every 30 seconds to update progress bars
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ---------------- APP BAR & SEARCH ----------------
          SliverAppBar(
            backgroundColor: _bgLight,
            expandedHeight: 120,
            pinned: true,
            elevation: 0,
            iconTheme: IconThemeData(color: _darkHeader),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 60),
              title: Text(
                "Live Operations",
                style: TextStyle(color: _darkHeader, fontWeight: FontWeight.w900, fontSize: 20),
              ),
              background: Container(color: _bgLight),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Container(
                height: 50,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: "Search plate number or location...",
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                    suffixIcon: _searchQuery.isNotEmpty 
                      ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        }) 
                      : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),

          // ---------------- LIVE LIST ----------------
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("bookings")
                .where("endTime", isGreaterThan: Timestamp.now()) // Only Active
                .orderBy("endTime") // Expiring soonest first
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 15),
                        Text("All Clear", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _darkHeader)),
                        const SizedBox(height: 5),
                        Text("No active sessions at the moment", style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  ),
                );
              }

              // CLIENT-SIDE SEARCH FILTER
              final allDocs = snapshot.data!.docs;
              final filteredDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final parking = (data["parkingName"] ?? data["parking_name"] ?? "").toString().toLowerCase();
                final vehicle = (data["vehicle"]?["number"] ?? "").toString().toLowerCase();
                return parking.contains(_searchQuery) || vehicle.contains(_searchQuery);
              }).toList();

              if (filteredDocs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 50),
                    child: Center(child: Text("No vehicle found", style: TextStyle(color: Colors.grey.shade500))),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = filteredDocs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      return _buildLiveSessionCard(context, doc.id, data);
                    },
                    childCount: filteredDocs.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PREMIUM CARD
  // ---------------------------------------------------------------------------
  Widget _buildLiveSessionCard(BuildContext context, String docId, Map<String, dynamic> data) {
    // Data Extraction
    final parking = data["parkingName"] ?? data["parking_name"] ?? "Unknown Location";
    final slot = data["slotId"] ?? data["slot_id"] ?? "--";
    final floor = (data["floor"] ?? 0) + 1;
    final vehicleMap = data["vehicle"] as Map<String, dynamic>? ?? {};
    final vehicleNo = vehicleMap["number"] ?? "UNKNOWN";
    final vehicleType = vehicleMap["type"] ?? "Car";

    // Time Logic
    final start = (data["startTime"] ?? data["start_ts"] as Timestamp).toDate();
    final end = (data["endTime"] ?? data["end_ts"] as Timestamp).toDate();
    final now = DateTime.now();
    
    final totalDuration = end.difference(start).inSeconds;
    final elapsed = now.difference(start).inSeconds;
    final remaining = end.difference(now);
    
    // Progress (0.0 to 1.0)
    double progress = (elapsed / totalDuration).clamp(0.0, 1.0);
    
    // Urgency Logic
    final isUrgent = remaining.inMinutes < 15;
    final statusColor = isUrgent ? _urgentRed : _safeGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          // ---- HEADER ----
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
                  child: Icon(vehicleType == "Bike" ? Icons.two_wheeler : Icons.directions_car, color: _primaryBlue),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicleNo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _darkHeader, letterSpacing: 1.0)),
                      const SizedBox(height: 4),
                      Text("$parking • Slot $slot (Fl $floor)", style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                _statusBadge(isUrgent),
              ],
            ),
          ),

          // ---- PROGRESS BAR ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Time Elapsed", style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                    Text(_formatRemaining(remaining), style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('hh:mm a').format(start), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    Text(DateFormat('hh:mm a').format(end), style: TextStyle(fontSize: 11, color: _darkHeader, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ---- ACTION BUTTONS ----
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                // Call Driver Button
                Expanded(
                  child: InkWell(
                    onTap: () => HapticFeedback.mediumImpact(), // Placeholder for url_launcher
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.call, size: 18, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text("Contact", style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(width: 1, height: 25, color: Colors.grey.shade200),
                // Force Stop Button
                Expanded(
                  child: InkWell(
                    onTap: () => _confirmCancel(context, docId),
                    borderRadius: const BorderRadius.only(bottomRight: Radius.circular(24)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.stop_circle_outlined, size: 20, color: _urgentRed),
                          const SizedBox(width: 8),
                          Text("End Session", style: TextStyle(fontWeight: FontWeight.w700, color: _urgentRed)),
                        ],
                      ),
                    ),
                  ),
                ),
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
  
  Widget _statusBadge(bool isUrgent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isUrgent ? _urgentRed.withOpacity(0.1) : _safeGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isUrgent ? _urgentRed.withOpacity(0.2) : _safeGreen.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: isUrgent ? _urgentRed : _safeGreen,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isUrgent ? "EXPIRING" : "ACTIVE",
            style: TextStyle(
              color: isUrgent ? _urgentRed : _safeGreen,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  String _formatRemaining(Duration d) {
    if (d.isNegative) return "OVERDUE";
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    if (hours > 0) return "${hours}h ${mins}m left";
    return "${mins}m left";
  }

  void _confirmCancel(BuildContext context, String bookingId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Force Stop Session", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          "Are you sure you want to end this booking immediately? The user will be notified.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _urgentRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance.collection("bookings").doc(bookingId).update({
                "endTime": Timestamp.fromDate(DateTime.now()),
                "status": "cancelled_admin",
              });
              HapticFeedback.heavyImpact();
            },
            child: const Text("End Session", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}