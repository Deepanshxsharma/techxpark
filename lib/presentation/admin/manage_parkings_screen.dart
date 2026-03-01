import 'package:techxpark/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'add_parking_screen.dart';
import 'edit_parking_screen.dart';
import 'admin_floors_screen.dart';

class ManageParkingsScreen extends StatefulWidget {
  const ManageParkingsScreen({super.key});

  @override
  State<ManageParkingsScreen> createState() => _ManageParkingsScreenState();
}

class _ManageParkingsScreenState extends State<ManageParkingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Brand Colors
  final Color _bgLight = const Color(0xFFF8FAFC);
  final Color _darkHeader = const Color(0xFF0F172A);
  final Color _primaryBlue = AppColors.primary;
  final Color _activeGreen = const Color(0xFF10B981);
  final Color _inactiveRed = const Color(0xFFEF4444);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      
      // ➕ FLOATING ADD BUTTON
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddParkingScreen()));
        },
        backgroundColor: _darkHeader,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Location", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 4,
      ),

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
              titlePadding: const EdgeInsets.only(left: 20, bottom: 60), // Adjust for search bar
              title: Text(
                "Parking Locations",
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
                    hintText: "Search by name or area...",
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

          // ---------------- LIST CONTENT ----------------
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection("parking_locations").snapshots(),
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
                        Icon(Icons.map_outlined, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        Text("No locations added yet", style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              }

              // CLIENT-SIDE SEARCH FILTER
              final allDocs = snapshot.data!.docs;
              final filteredDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data["name"] ?? "").toString().toLowerCase();
                final address = (data["address"] ?? "").toString().toLowerCase();
                return name.contains(_searchQuery) || address.contains(_searchQuery);
              }).toList();

              if (filteredDocs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 50),
                    child: Center(child: Text("No results found", style: TextStyle(color: Colors.grey.shade500))),
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
                      return _buildPremiumParkingCard(context, doc.id, data);
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
  // PREMIUM CARD UI
  // ---------------------------------------------------------------------------
  Widget _buildPremiumParkingCard(BuildContext context, String parkingId, Map<String, dynamic> data) {
    // Data Extraction
    final name = data["name"] ?? "Unknown Parking";
    final address = data["address"] ?? "No address provided";
    final price = data["price_per_hour"] ?? 0;
    final status = data["status"] ?? "active";
    final floors = data["floors"] ?? data["total_floors"] ?? 1; // Handle varied field names
    
    final isActive = status == "active";

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF94A3B8).withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          // ---- TOP SECTION (Icon + Info + Status) ----
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Avatar
                Container(
                  height: 50, width: 50,
                  decoration: BoxDecoration(
                    color: _primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.local_parking_rounded, color: _primaryBlue, size: 28),
                ),
                const SizedBox(width: 16),
                
                // Text Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _darkHeader, height: 1.1)),
                      const SizedBox(height: 6),
                      Text(address, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.4)),
                    ],
                  ),
                ),
                
                // Status Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isActive ? _activeGreen.withOpacity(0.1) : _inactiveRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isActive ? "ACTIVE" : "INACTIVE",
                    style: TextStyle(
                      color: isActive ? _activeGreen : _inactiveRed,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.5
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---- STATS DIVIDER ----
          Container(height: 1, color: Colors.grey.shade100),

          // ---- STATS ROW ----
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _statItem(Icons.currency_rupee, "₹$price/hr", "Price"),
                Container(width: 1, height: 30, color: Colors.grey.shade200),
                _statItem(Icons.layers_rounded, "$floors Floors", "Capacity"),
                Container(width: 1, height: 30, color: Colors.grey.shade200),
                _statItem(Icons.circle, isActive ? "Online" : "Offline", "System"),
              ],
            ),
          ),

          // ---- ACTION BUTTONS ----
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Row(
              children: [
                // Edit Button
                Expanded(
                  child: _actionButton(
                    icon: Icons.edit_rounded,
                    label: "Edit",
                    color: _darkHeader,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EditParkingScreen(parkingId: parkingId, parkingData: data))),
                  ),
                ),
                const SizedBox(width: 10),
                
                // Slots Button
                Expanded(
                  child: _actionButton(
                    icon: Icons.grid_view_rounded,
                    label: "Slots",
                    color: _primaryBlue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminFloorsScreen(parkingId: parkingId, totalFloors: floors))),
                  ),
                ),
                
                // Toggle Status Button (Icon only)
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => _toggleStatus(parkingId, !isActive),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isActive ? _inactiveRed.withOpacity(0.1) : _activeGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isActive ? _inactiveRed.withOpacity(0.2) : _activeGreen.withOpacity(0.2)),
                    ),
                    child: Icon(
                      Icons.power_settings_new_rounded, 
                      color: isActive ? _inactiveRed : _activeGreen,
                      size: 22,
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
  
  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(icon, size: 14, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: _darkHeader, fontSize: 14)),
          ],
        ),
        Text(label, style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _actionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleStatus(String docId, bool newStatus) async {
    HapticFeedback.mediumImpact();
    await FirebaseFirestore.instance.collection("parking_locations").doc(docId).update({
      "status": newStatus ? "active" : "cancelled",
    });
  }
}