import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

import '../booking/my_bookings_screen.dart';
import '../notifications/notifications_screen.dart';
import '../messages/messages_screen.dart';
import '../vehicle/my_vehicle_screen.dart';
import 'edit_profile_screen.dart';
import 'privacy_security_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  int _totalBookings = 0;
  int _activeBookings = 0;
  int _vehiclesCount = 0;
  int _unreadNotifs = 0;
  double _totalSpent = 0;
  String _mostVisited = 'N/A';
  int _timeParkedHrs = 0;
  bool _isLoadingStats = true;
  bool _isUploadingPhoto = false;

  late AnimationController _ringController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _fetchStats();
  }

  @override
  void dispose() {
    _ringController.dispose();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Bookings counts & stats
      final bookingsQuery = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .get();

      int totalB = bookingsQuery.docs.length;
      int activeB = 0;
      double totalSp = 0;
      int totalHours = 0;
      Map<String, int> parkingFreq = {};

      for (var doc in bookingsQuery.docs) {
        final data = doc.data();
        final status = data['status'] ?? '';
        if (status == 'active' || status == 'upcoming') activeB++;

        final price = (data['price'] ?? 0) as num;
        totalSp += price.toDouble();

        final start = data['startTime'] as Timestamp?;
        final end = data['endTime'] as Timestamp?;
        if (start != null && end != null) {
          final diff = end.toDate().difference(start.toDate()).inHours;
          if (diff > 0) totalHours += diff;
        }

        final pName = data['parkingName'] as String?;
        if (pName != null) {
          parkingFreq[pName] = (parkingFreq[pName] ?? 0) + 1;
        }
      }

      String mostVis = 'N/A';
      if (parkingFreq.isNotEmpty) {
        var sorted = parkingFreq.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        mostVis = sorted.first.key;
      }

      // Vehicles
      final vehiclesQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('vehicles')
          .count()
          .get();

      // Notifications
      final notifQuery = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .count()
          .get();

      if (mounted) {
        setState(() {
          _totalBookings = totalB;
          _activeBookings = activeB;
          _vehiclesCount = vehiclesQuery.count ?? 0;
          _unreadNotifs = notifQuery.count ?? 0;
          _totalSpent = totalSp;
          _timeParkedHrs = totalHours;
          _mostVisited = mostVis;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF0F172A)
            : AppColors.bgLight,
        body: Center(
          child: Text('Please log in to view your profile.', style: AppTextStyles.body1),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : AppColors.bgLight;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
             // Fallback while loading
             return Container(
                color: bgColor,
                child: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
             );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                _buildHeader(context, data, user, isDark).animate().fade(duration: 600.ms),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                  child: Column(
                    children: [
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        delay: const Duration(milliseconds: 150),
                        child: _buildAccountCard(data, isDark, user),
                      ),
                      const SizedBox(height: 16),
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        delay: const Duration(milliseconds: 300),
                        child: _buildParkingStatsCard(isDark),
                      ),
                      const SizedBox(height: 16),
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        delay: const Duration(milliseconds: 450),
                        child: _buildActionsCard(context, isDark),
                      ),
                      const SizedBox(height: 16),
                      FadeInUp(
                        duration: const Duration(milliseconds: 600),
                        delay: const Duration(milliseconds: 600),
                        child: _buildLogoutCard(context, isDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  HEADER — Premium Gradient Hero                                         */
  /* ═══════════════════════════════════════════════════════════════════════ */
  Widget _buildHeader(BuildContext context, Map<String, dynamic> data, User user, bool isDark) {
    final name = data['name'] ?? 'User';
    final photoUrl = data['photoUrl'] as String?;
    final isVerified = user.emailVerified;

    return Container(
      width: double.infinity,
      height: 340,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          // Subtle Mesh Pattern Overlay
          Positioned.fill(
             child: Opacity(
               opacity: 0.1,
               child: CustomPaint(
                 painter: _MeshPainter(),
               ),
             ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Avatar with Animated Rings
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showPhotoBottomSheet(context, user);
                  },
                  child: AnimatedBuilder(
                    animation: _ringController,
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          for (int i = 0; i < 3; i++)
                            Transform.rotate(
                              angle: _ringController.value * 2 * 3.14159 * (i % 2 == 0 ? 1 : -1),
                              child: Container(
                                width: 104.0 + (i * 20),
                                height: 104.0 + (i * 20),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withOpacity([0.2, 0.1, 0.05][i]),
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          child!,
                        ],
                      );
                    },
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                            child: photoUrl == null
                                ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.bold))
                                : null,
                          ),
                        ).animate().scale(duration: 800.ms, curve: Curves.elasticOut),
                        if (_isUploadingPhoto)
                           const Positioned.fill(
                             child: CircularProgressIndicator(color: Colors.white),
                           ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                            ),
                            child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB), size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Name & Verified Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                    if (isVerified) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: "Verified Account",
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                          child: const Icon(Icons.check, color: Colors.white, size: 12),
                        ),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 4),
                Text(user.email ?? '', style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 14)),
                const SizedBox(height: 24),
                
                // Stat Pills
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStatPill("🅿️", "$_totalBookings Bookings", 100),
                    const SizedBox(width: 12),
                    _buildStatPill("🔥", "$_activeBookings Active", 200),
                    const SizedBox(width: 12),
                    _buildStatPill("🚗", "$_vehiclesCount Vehicles", 300),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String emoji, String text, int delay) {
    return FadeInUp(
      delay: Duration(milliseconds: delay),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 4),
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  ACCOUNT INFO CARD                                                     */
  /* ═══════════════════════════════════════════════════════════════════════ */
  Widget _buildAccountCard(Map<String, dynamic> data, bool isDark, User user) {
    final phone = data['phone'] ?? 'Not added';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final memberSince = createdAt != null ? DateFormat('MMMM yyyy').format(createdAt) : '—';
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark? 0.2 : 0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Account ID Row
          Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
               _infoRow(Icons.badge_outlined, 'Account ID', user.uid.substring(0, 8).toUpperCase(), textColor),
               IconButton(
                 icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
                 onPressed: () async {
                   await Clipboard.setData(ClipboardData(text: user.uid));
                   if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User ID copied!')));
                 },
               ),
             ],
          ),
          Divider(height: 24, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
          
          // Phone
          _infoRow(Icons.phone_outlined, 'Phone', phone, textColor),
          Divider(height: 24, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
          
          // Member Since
          _infoRow(Icons.calendar_today_outlined, 'Member since', memberSince, textColor),
          Divider(height: 24, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9)),
          
          // Verified Status
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.mark_email_read_outlined, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email Status', style: AppTextStyles.caption.copyWith(color: Colors.grey)),
                  const SizedBox(height: 4),
                  if (user.emailVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Text('Verified ✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    )
                  else
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Text('Not Verified', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                             await user.sendEmailVerification();
                             if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification email sent!')));
                          },
                          child: const Text('Send Link', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, Color textColor) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.caption.copyWith(color: Colors.grey)),
            const SizedBox(height: 2),
            Text(value, style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700, color: textColor)),
          ],
        ),
      ],
    );
  }

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  PARKING STATS CARD                                                    */
  /* ═══════════════════════════════════════════════════════════════════════ */
  Widget _buildParkingStatsCard(bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark? 0.2 : 0.04), blurRadius: 16, offset: const Offset(0, 4))],
        gradient: isDark ? null : LinearGradient(
          colors: [Colors.blue.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Your Parking Stats 📊", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatColumn("🅿️", _isLoadingStats ? "..." : _totalBookings.toString(), "Total\nBookings", textColor),
              _buildStatColumn("⏱️", _isLoadingStats ? "..." : "$_timeParkedHrs hrs", "Time\nParked", textColor),
              _buildStatColumn("💰", _isLoadingStats ? "..." : "₹${_totalSpent.toStringAsFixed(0)}", "Total\nSpent", textColor),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
               Icon(Icons.place, size: 14, color: Colors.grey.shade600),
               const SizedBox(width: 4),
               Expanded(child: Text("Most visited: $_mostVisited", style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String emoji, String val, String label, Color textColor) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 8),
        _isLoadingStats 
            ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(val, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor))
              .animate().fade(duration: 800.ms).scale(),
        const SizedBox(height: 4),
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
      ],
    );
  }

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  ACTIONS CARD                                                          */
  /* ═══════════════════════════════════════════════════════════════════════ */
  Widget _buildActionsCard(BuildContext context, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final dividerColor = isDark ? Colors.white10 : const Color(0xFFF1F5F9);

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark? 0.2 : 0.04), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          _actionRow(
            icon: Icons.person_outline_rounded,
            iconColor: const Color(0xFF2563EB), // Blue
            title: 'Edit Profile',
            isDark: isDark,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
          ),
          Divider(height: 1, indent: 64, color: dividerColor),
          _actionRow(
            icon: Icons.directions_car_outlined,
            iconColor: const Color(0xFF7C3AED), // Purple
            title: 'My Vehicles',
            hint: '$_vehiclesCount vehicles',
            isDark: isDark,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyVehicleScreen())),
          ),
          Divider(height: 1, indent: 64, color: dividerColor),
          _actionRow(
            icon: Icons.receipt_long_rounded,
            iconColor: const Color(0xFF16A34A), // Green
            title: 'Booking History',
            hint: '$_totalBookings bookings',
            isDark: isDark,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyBookingsScreen())),
          ),
          Divider(height: 1, indent: 64, color: dividerColor),
          _actionRow(
            icon: Icons.notifications_none_rounded,
            iconColor: const Color(0xFFEA580C), // Orange
            title: 'Notifications',
            hint: _unreadNotifs > 0 ? '$_unreadNotifs unread' : null,
            showDot: _unreadNotifs > 0,
            isDark: isDark,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
          Divider(height: 1, indent: 64, color: dividerColor),
          _actionRow(
            icon: Icons.shield_outlined,
            iconColor: const Color(0xFF475569), // Slate
            title: 'Privacy & Security',
            isDark: isDark,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySecurityScreen())),
          ),
          Divider(height: 1, indent: 64, color: dividerColor),
          _actionRow(
            icon: Icons.headset_mic_outlined,
            iconColor: const Color(0xFF0891B2), // Cyan
            title: 'Help & Support',
            isDark: isDark,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen())),
          ),
          Divider(height: 1, indent: 64, color: dividerColor),
          _actionRow(
            icon: Icons.star_border_rounded,
            iconColor: const Color(0xFFEAB308), // Yellow
            title: 'Rate the App',
            isDark: isDark,
            onTap: () async {
               HapticFeedback.lightImpact();
               const url = "market://details?id=com.techxpark.app";
               final uri = Uri.parse(url);
               if(await canLaunchUrl(uri)) {
                  await launchUrl(uri);
               } else {
                  await launchUrl(Uri.parse("https://play.google.com/store/apps/details?id=com.techxpark.app"));
               }
            },
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
    String? hint,
    bool showDot = false,
  }) {
    return _AnimatedScaleButton(
      onPressed: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Stack(
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  if (showDot)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                    )
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppColors.textPrimaryLight),
              ),
            ),
            if (hint != null)
              Text(hint, style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : AppColors.borderLight, size: 24),
          ],
        ),
      ),
    );
  }

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  LOGOUT CARD                                                           */
  /* ═══════════════════════════════════════════════════════════════════════ */
  Widget _buildLogoutCard(BuildContext context, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.error.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: _AnimatedScaleButton(
        onPressed: () => _confirmSignOut(context, isDark),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), shape: BoxShape.circle),
                child: const Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
              ),
              const SizedBox(width: 16),
              Text('Sign Out', style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700, color: AppColors.error)),
            ],
          ),
        ),
      ),
    );
  }

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  ACTIONS                                                               */
  /* ═══════════════════════════════════════════════════════════════════════ */
  Future<void> _showPhotoBottomSheet(BuildContext context, User user) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF2563EB)),
                title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () { Navigator.pop(ctx); _pickAndUploadPhoto(context, user.uid, ImageSource.camera); },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF2563EB)),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () { Navigator.pop(ctx); _pickAndUploadPhoto(context, user.uid, ImageSource.gallery); },
              ),
              if (user.photoURL != null) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Remove Photo', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  onTap: () async {
                     Navigator.pop(ctx);
                     setState(() => _isUploadingPhoto = true);
                     try {
                        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'photoUrl': FieldValue.delete()});
                        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo removed')));
                     } finally {
                        setState(() => _isUploadingPhoto = false);
                     }
                  },
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      }
    );
  }

  Future<void> _pickAndUploadPhoto(BuildContext context, String uid, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, maxWidth: 512, imageQuality: 85);
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);

    try {
      final ref = FirebaseStorage.instance.ref('profile_photos/$uid.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'photoUrl': url});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      setState(() => _isUploadingPhoto = false);
    }
  }

  void _confirmSignOut(BuildContext context, bool isDark) {
    HapticFeedback.lightImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Material(
               color: Colors.transparent,
               child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
                    const SizedBox(height: 16),
                    Text('Sign Out', style: AppTextStyles.h1.copyWith(fontSize: 22, color: isDark ? Colors.white : AppColors.textPrimaryLight)),
                    const SizedBox(height: 12),
                    Text(
                      'Your bookings and vehicles will still be saved when you return.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body1.copyWith(color: Colors.grey, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    Row(
                       children: [
                          Expanded(
                             child: OutlinedButton(
                                onPressed: () => Navigator.pop(ctx),
                                style: OutlinedButton.styleFrom(
                                   padding: const EdgeInsets.symmetric(vertical: 16),
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                   side: const BorderSide(color: Colors.grey),
                                ),
                                child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                             ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                             child: ElevatedButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await FirebaseAuth.instance.signOut();
                                  // Navigator pop logic handles auth changes globally or via listeners
                                },
                                style: ElevatedButton.styleFrom(
                                   backgroundColor: AppColors.error,
                                   padding: const EdgeInsets.symmetric(vertical: 16),
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                   elevation: 0,
                                ),
                                child: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                             ),
                          ),
                       ],
                    )
                  ],
               ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
         return SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(anim1),
            child: child,
         );
      },
    );
  }
}

class _MeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AnimatedScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const _AnimatedScaleButton({required this.child, required this.onPressed});

  @override
  State<_AnimatedScaleButton> createState() => _AnimatedScaleButtonState();
}

class _AnimatedScaleButtonState extends State<_AnimatedScaleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        HapticFeedback.lightImpact();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}