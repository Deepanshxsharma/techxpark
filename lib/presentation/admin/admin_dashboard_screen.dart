import 'package:techxpark/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../services/google_auth_service.dart';
import '../../utils/navigation_utils.dart';
import 'manage_parkings_screen.dart';
import 'admin_live_bookings_screen.dart';
import 'admin_revenue_screen.dart';
import 'admin_users_screen.dart';
import 'admin_support_chats_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  // Animation Controller for Staggered Entrance
  late AnimationController _controller;

  // Premium Color Palette
  final Color _bgLight = const Color(0xFFF8FAFC);
  final Color _darkHeader = const Color(0xFF0F172A);
  final Color _primaryBlue = AppColors.primary;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ---------------- APP BAR ----------------
          SliverAppBar(
            backgroundColor: _bgLight,
            elevation: 0,
            pinned: true,
            expandedHeight: 80,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                "Admin Console",
                style: TextStyle(
                  color: _darkHeader,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                  ),
                  onPressed: () => _confirmLogout(context),
                ),
              ),
            ],
          ),

          // ---------------- CONTENT ----------------
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildDateHeader(),
                const SizedBox(height: 25),

                // STATS ROW
                Row(
                  children: [
                    Expanded(
                      child: _buildGradientStatCard(
                        "Total Locations",
                        FirebaseFirestore.instance
                            .collection("parking_locations")
                            .snapshots(),
                        Icons.map,
                        [AppColors.primary, AppColors.primary], // Blue Gradient
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildGradientStatCard(
                        "Live Bookings",
                        FirebaseFirestore.instance
                            .collection("bookings")
                            .where("endTime", isGreaterThan: Timestamp.now())
                            .snapshots(),
                        Icons.directions_car_filled,
                        [
                          const Color(0xFFF59E0B),
                          const Color(0xFFD97706),
                        ], // Amber Gradient
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 35),
                Text(
                  "Management",
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 15),
              ]),
            ),
          ),

          // ---------------- GRID MENU ----------------
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildListDelegate([
                _buildAnimatedMenuTile(
                  0,
                  "Parkings",
                  Icons.local_parking_rounded,
                  AppColors.primary,
                  () => _nav(const ManageParkingsScreen()),
                ),
                _buildAnimatedMenuTile(
                  1,
                  "Bookings",
                  Icons.confirmation_number_rounded,
                  Colors.orange,
                  () => _nav(const AdminLiveBookingsScreen()),
                ),
                _buildAnimatedMenuTile(
                  2,
                  "Revenue",
                  Icons.bar_chart_rounded,
                  Colors.green,
                  () => _nav(const AdminRevenueScreen()),
                ),
                _buildAnimatedMenuTile(
                  3,
                  "Users",
                  Icons.group_rounded,
                  AppColors.primary,
                  () => _nav(const AdminUsersScreen()),
                ),
                _buildAnimatedMenuTile(
                  4,
                  "Support",
                  Icons.headset_mic_rounded,
                  Colors.teal,
                  () => _nav(const AdminSupportChatsScreen()),
                ),
              ]),
            ),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  void _nav(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  // ------------------------------------------------------------------
  // WIDGETS
  // ------------------------------------------------------------------

  Widget _buildDateHeader() {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          DateFormat('EEEE, d MMMM').format(now).toUpperCase(),
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Text(
              "Overview",
              style: TextStyle(
                color: _darkHeader,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _primaryBlue,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGradientStatCard(
    String title,
    Stream<QuerySnapshot> stream,
    IconData icon,
    List<Color> colors,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (_, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return Container(
          height: 140,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: colors[0].withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Watermark Icon
              Positioned(
                right: -10,
                bottom: -10,
                child: Icon(
                  icon,
                  size: 80,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              // Content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        count.toString(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnimatedMenuTile(
    int index,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    // Staggered Animation Logic
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval((index * 0.1), 1.0, curve: Curves.easeOutBack),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - animation.value)), // Slide up effect
          child: Opacity(opacity: animation.value, child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          // Micro-interaction: slight delay for visual feedback
          Future.delayed(const Duration(milliseconds: 100), onTap);
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF94A3B8).withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: _darkHeader,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Sign Out",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text("Are you sure you want to end your session?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await GoogleAuthService().signOut();
              if (context.mounted) safeShowAuthState(context);
            },
            child: const Text(
              "Sign Out",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
