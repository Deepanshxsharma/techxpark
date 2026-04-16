import 'package:techxpark/theme/app_colors.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Add intl: ^0.18.0

class AdminLiveBookingsScreen extends StatefulWidget {
  const AdminLiveBookingsScreen({super.key});

  @override
  State<AdminLiveBookingsScreen> createState() => _AdminLiveBookingsScreenState();
}

class _AdminLiveBookingsScreenState extends State<AdminLiveBookingsScreen> {
  // ---------------- STATE ----------------
  Timer? _ticker;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = "";

  // ---------------- THEME ----------------
  final Color _bgLight = const Color(0xFFF8FAFC);
  final Color _darkHeader = const Color(0xFF0F172A);
  final Color _primaryBlue = AppColors.primary;
  final Color _urgentRed = const Color(0xFFEF4444);
  final Color _safeGreen = const Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    // ⏱️ LIVE CLOCK: Refresh UI every 30 seconds to update progress bars
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _searchCtrl.dispose();
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
              titlePadding: const EdgeInsets.only(left: 20, bottom: 65),
              title: Text(
                "Live Traffic",
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
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: "Search plate, slot, or location...",
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                    suffixIcon: _searchQuery.isNotEmpty 
                        ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() { _searchCtrl.clear(); _searchQuery = ""; })) 
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),

          // ---------------- LIVE STREAM ----------------
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("bookings")
                .where("endTime", isGreaterThan: Timestamp.now()) // Only Active
                .orderBy("endTime") // Showing expiring soonest first
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              // 🔎 CLIENT-SIDE FILTERING
              final allDocs = snapshot.data!.docs;
              final filtered = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final combinedText = "${data['parkingName'] ?? data['parking_name']} ${data['slotId'] ?? data['slot_id']} ${data['vehicle']?['number']}".toLowerCase();
                return combinedText.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.only(top: 50), child: Center(child: Text("No matches found"))),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 50),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = filtered[index];
                      return _buildPremiumCard(context, doc);
                    },
                    childCount: filtered.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text("All Clear", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _darkHeader)),
            const SizedBox(height: 5),
            Text("No active bookings right now.", style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PREMIUM CARD UI
  // ---------------------------------------------------------------------------
  Widget _buildPremiumCard(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse Data
    final parking = data["parkingName"] ?? data["parking_name"] ?? "Unknown";
    final slot = data["slotId"] ?? data["slot_id"] ?? "-";
    final floor = (data["floor"] ?? 0) + 1;
    final vehicleMap = data["vehicle"] as Map<String, dynamic>? ?? {};
    final vehicleNo = vehicleMap["number"] ?? "UNKNOWN";
    final vehicleType = vehicleMap["type"] ?? "Car";
    final amount = (data["total_price"] ?? 0).toDouble();

    // Time Logic
    final start = (data["startTime"] ?? data["start_ts"] as Timestamp).toDate();
    final end = (data["endTime"] ?? data["end_ts"] as Timestamp).toDate();
    final now = DateTime.now();

    // Progress Bar Logic
    final totalDuration = end.difference(start).inSeconds;
    final elapsed = now.difference(start).inSeconds;
    final progress = (elapsed / totalDuration).clamp(0.0, 1.0);
    
    // Urgency Logic (< 15 mins left = RED)
    final remaining = end.difference(now);
    final isUrgent = remaining.inMinutes < 15;
    final statusColor = isUrgent ? _urgentRed : _safeGreen;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // HEADER
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _primaryBlue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: Icon(vehicleType == "Bike" ? Icons.two_wheeler : Icons.directions_car_filled, color: _primaryBlue),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicleNo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _darkHeader)),
                      const SizedBox(height: 4),
                      Text("$parking • Slot $slot (Fl $floor)", style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                _statusBadge(isUrgent),
              ],
            ),
          ),

          // PROGRESS BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey.shade100,
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Entry: ${DateFormat('hh:mm a').format(start)}", style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                    Text(
                      remaining.isNegative ? "OVERDUE" : "${remaining.inMinutes} mins left",
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.grey.shade100),

          // ACTIONS ROW
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text("₹${amount.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                ),
              ),
              Container(width: 1, height: 20, color: Colors.grey.shade200),
              Expanded(
                child: TextButton.icon(
                  onPressed: () => _confirmCancel(context, doc.id),
                  icon: Icon(Icons.cancel_outlined, size: 18, color: _urgentRed),
                  label: Text("Cancel", style: TextStyle(color: _urgentRed, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS & DIALOGS
  // ---------------------------------------------------------------------------

  Widget _statusBadge(bool isUrgent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isUrgent ? _urgentRed.withValues(alpha: 0.1) : _safeGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isUrgent ? _urgentRed.withValues(alpha: 0.2) : _safeGreen.withValues(alpha: 0.2)),
      ),
      child: Text(
        isUrgent ? "EXPIRING" : "ACTIVE",
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isUrgent ? _urgentRed : _safeGreen),
      ),
    );
  }

  void _confirmCancel(BuildContext context, String bookingId) {
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Force Cancellation", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("This will immediately end the booking and release the slot.", style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            const SizedBox(height: 15),
            TextField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                labelText: "Reason (Required)",
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Keep Booking", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _urgentRed, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              if (reasonCtrl.text.trim().isEmpty) return; // Validation

              await FirebaseFirestore.instance.collection("bookings").doc(bookingId).update({
                "status": "cancelled",
                "cancelled_by": "admin",
                "cancel_reason": reasonCtrl.text.trim(),
                "endTime": Timestamp.fromDate(DateTime.now()), // Ensure it stops appearing in active list
                "cancelled_at": FieldValue.serverTimestamp(),
              });

              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Booking cancelled successfully"), backgroundColor: Colors.green));
              }
            },
            child: const Text("Confirm Cancel", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}