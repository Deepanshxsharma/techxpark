import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminRevenueScreen extends StatefulWidget {
  const AdminRevenueScreen({super.key});

  @override
  State<AdminRevenueScreen> createState() => _AdminRevenueScreenState();
}

class _AdminRevenueScreenState extends State<AdminRevenueScreen> with SingleTickerProviderStateMixin {
  // State
  bool _isMonthly = false;

  // Theme Colors (Fintech Style)
  final Color _bgLight = const Color(0xFFF8FAFC);
  final Color _darkHeader = const Color(0xFF0F172A);
  final Color _moneyGreen = const Color(0xFF059669);
  final Color _moneyLight = const Color(0xFFD1FAE5);

  DateTime get _startDate {
    final now = DateTime.now();
    return _isMonthly
        ? DateTime(now.year, now.month, 1)
        : DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      appBar: AppBar(
        title: Text("Revenue Analytics", style: TextStyle(color: _darkHeader, fontWeight: FontWeight.w900, fontSize: 20)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: _darkHeader),
      ),
      
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("bookings")
            .where("created_at", isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 1. PROCESS DATA
          final docs = snapshot.data?.docs ?? [];
          double totalRevenue = 0;
          int transactionCount = 0;
          final Map<String, double> perParking = {};

          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            
            // Skip cancelled/refunded
            if (data["status"] == "cancelled" || data["status"] == "refunded") continue;

            final price = (data["total_price"] ?? 0).toDouble();
            final parking = data["parkingName"] ?? data["parking_name"] ?? "Unknown Location";

            totalRevenue += price;
            transactionCount++;
            perParking[parking] = (perParking[parking] ?? 0) + price;
          }

          // Sort: Highest revenue first
          final sortedParking = perParking.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // ---------------- TOGGLE ----------------
                      _buildCustomToggle(),
                      const SizedBox(height: 25),

                      // ---------------- MAIN CARD ----------------
                      _buildTotalRevenueCard(totalRevenue, transactionCount),
                      const SizedBox(height: 30),

                      // ---------------- BREAKDOWN HEADER ----------------
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Performance", style: TextStyle(color: _darkHeader, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text("Top Earner First", style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 15),
                    ],
                  ),
                ),
              ),

              // ---------------- BREAKDOWN LIST ----------------
              if (sortedParking.isEmpty)
                SliverToBoxAdapter(child: _buildEmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final entry = sortedParking[index];
                        // Calculate percentage for progress bar
                        final percent = totalRevenue == 0 ? 0.0 : (entry.value / totalRevenue);
                        return _buildPerformanceRow(entry.key, entry.value, percent);
                      },
                      childCount: sortedParking.length,
                    ),
                  ),
                ),
                
              const SliverPadding(padding: EdgeInsets.only(bottom: 50)),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // WIDGETS
  // ---------------------------------------------------------------------------

  Widget _buildCustomToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _toggleOption("Today", !_isMonthly),
          _toggleOption("This Month", _isMonthly),
        ],
      ),
    );
  }

  Widget _toggleOption(String text, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isMonthly = text == "This Month"),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? _darkHeader : Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalRevenueCard(double total, int txCount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF10B981), const Color(0xFF059669)], // Emerald Gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: const Color(0xFF10B981).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          // Background Decor
          Positioned(right: -20, top: -20, child: Icon(Icons.currency_rupee, size: 120, color: Colors.white.withOpacity(0.1))),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isMonthly ? "Monthly Income" : "Daily Income",
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Animated Counter
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: total),
                duration: const Duration(seconds: 2),
                curve: Curves.easeOutExpo,
                builder: (context, value, child) {
                  return Text(
                    "₹${value.toStringAsFixed(0)}",
                    style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text(
                "$txCount successful transactions",
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceRow(String name, double amount, double percent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _darkHeader)),
                    const SizedBox(height: 4),
                    Text("${(percent * 100).toStringAsFixed(1)}% of total", style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                  ],
                ),
              ),
              Text(
                "₹${amount.toStringAsFixed(0)}",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _moneyGreen),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Visual Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: _moneyLight, // Light Green bg
              valueColor: AlwaysStoppedAnimation<Color>(_moneyGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(Icons.savings_outlined, size: 60, color: Colors.grey.shade300),
            const SizedBox(height: 10),
            Text("No revenue yet", style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}