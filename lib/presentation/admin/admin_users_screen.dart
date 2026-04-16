import 'package:techxpark/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  // Brand Colors
  final Color _bgLight = const Color(0xFFF8FAFC);
  final Color _darkHeader = const Color(0xFF0F172A);
  final Color _primaryBlue = AppColors.primary;

  @override
  void dispose() {
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
                "User Database",
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
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: "Search name, email, or vehicle...",
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

          // ---------------- USER LIST ----------------
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection("users").snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(child: Center(child: CircularProgressIndicator()));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyState();
              }

              // CLIENT-SIDE SEARCH
              final allDocs = snapshot.data!.docs;
              final filteredDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data["name"] ?? "").toString().toLowerCase();
                final email = (data["email"] ?? "").toString().toLowerCase();
                final vehicle = (data["vehicle"]?["number"] ?? "").toString().toLowerCase();
                
                return name.contains(_searchQuery) || email.contains(_searchQuery) || vehicle.contains(_searchQuery);
              }).toList();

              if (filteredDocs.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(padding: EdgeInsets.only(top: 50), child: Center(child: Text("No users found"))),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 50),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final doc = filteredDocs[index];
                      return _buildUserCard(doc);
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
  // PREMIUM USER CARD
  // ---------------------------------------------------------------------------
  Widget _buildUserCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Parse Data
    final name = data["name"] ?? "Unnamed User";
    final email = data["email"] ?? "No Email";
    final phone = data["phone"] ?? "No Phone";
    
    // Vehicle Data
    final vehicle = data["vehicle"] as Map<String, dynamic>?;
    final vehicleNumber = vehicle?["number"] ?? "NO VEHICLE";
    final vehicleType = vehicle?["type"] ?? "Car";
    final hasVehicle = vehicleNumber != "NO VEHICLE";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. DYNAMIC AVATAR
                CircleAvatar(
                  radius: 26,
                  backgroundColor: _primaryBlue.withValues(alpha: 0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : "?",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryBlue),
                  ),
                ),
                const SizedBox(width: 16),

                // 2. USER INFO
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _darkHeader)),
                      const SizedBox(height: 4),
                      Text(email, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                      const SizedBox(height: 2),
                      Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. VEHICLE STRIP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade100), bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Icon(
                  vehicleType == "Bike" ? Icons.two_wheeler : Icons.directions_car_filled,
                  size: 18, color: hasVehicle ? _primaryBlue : Colors.grey
                ),
                const SizedBox(width: 10),
                Text(
                  hasVehicle ? vehicleNumber.toUpperCase() : "No Vehicle Registered",
                  style: TextStyle(
                    fontWeight: FontWeight.w700, 
                    color: hasVehicle ? _darkHeader : Colors.grey,
                    letterSpacing: hasVehicle ? 1.0 : 0,
                  ),
                ),
                const Spacer(),
                if (hasVehicle)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)),
                    child: Text(vehicleType.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                  )
              ],
            ),
          ),

          // 4. QUICK ACTIONS
          Row(
            children: [
              Expanded(
                child: _actionButton(Icons.email_outlined, "Email", () {
                   HapticFeedback.lightImpact();
                   // Add url_launcher logic here
                }),
              ),
              Container(width: 1, height: 20, color: Colors.grey.shade200),
              Expanded(
                child: _actionButton(Icons.phone_outlined, "Call", () {
                   HapticFeedback.lightImpact();
                   // Add url_launcher logic here
                }),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off_rounded, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text("No users found", style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}