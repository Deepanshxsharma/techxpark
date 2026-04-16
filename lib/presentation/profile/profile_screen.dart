import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../notifications/notifications_screen.dart';
import '../vehicle/my_vehicle_screen.dart';
import '../booking/my_bookings_screen.dart';
import 'edit_profile_screen.dart';
import 'privacy_security_screen.dart';
import 'saved_parkings_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingPhoto = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.bgLight,
        body: Center(
          child: Text(
            'Please log in to view your profile.',
            style: AppTextStyles.body1.copyWith(color: AppColors.textSecondaryLight),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFBF8FF),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['name'] ?? 'User';
          final email = data['email'] ?? user.email ?? '';
          final photoUrl = data['photoUrl'] as String?;

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ═══════════════════════════════════════
              // TOP APP BAR
              // ═══════════════════════════════════════
              SliverAppBar(
                pinned: true,
                floating: false,
                backgroundColor: const Color(0xFFFBF8FF).withValues(alpha: 0.85),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                titleSpacing: 20,
                flexibleSpace: ClipRect(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFBF8FF).withValues(alpha: 0.85),
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Color(0xFF0029B9),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Profile',
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1B23),
                      ),
                    ),
                  ],
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      ),
                      child: const Icon(
                        Icons.settings,
                        color: Color(0xFF0029B9),
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),

              // ═══════════════════════════════════════
              // BODY
              // ═══════════════════════════════════════
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),

                    // ── Profile Header ────────────────────
                    _buildProfileHeader(name, email, photoUrl, user),

                    const SizedBox(height: 32),

                    // ── Stats Section ─────────────────────
                    _buildStatsSection(user.uid),

                    const SizedBox(height: 32),

                    // ── Group 1: Quick Access ─────────────
                    _buildMenuGroup([
                      _ProfileMenuItem(
                        icon: Icons.directions_car,
                        label: 'My Vehicles',
                        iconColor: const Color(0xFF0029B9),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MyVehicleScreen()),
                        ),
                      ),
                      _ProfileMenuItem(
                        icon: Icons.calendar_today,
                        label: 'My Bookings',
                        iconColor: const Color(0xFF0029B9),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
                        ),
                      ),
                      _ProfileMenuItem(
                        icon: Icons.bookmark,
                        label: 'Saved Locations',
                        iconColor: const Color(0xFF0029B9),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SavedParkingsScreen()),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // ── Refer & Earn Banner ───────────────
                    _buildReferralBanner(),

                    const SizedBox(height: 20),

                    // ── Group 2: Account ──────────────────
                    _buildMenuGroup([
                      _ProfileMenuItem(
                        icon: Icons.account_balance_wallet,
                        label: 'Payments & Wallet',
                        iconColor: const Color(0xFF505A96),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Payments coming soon'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      _ProfileMenuItem(
                        icon: Icons.notifications,
                        label: 'Notifications',
                        iconColor: const Color(0xFF505A96),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                        ),
                      ),
                      _ProfileMenuItem(
                        icon: Icons.security,
                        label: 'Privacy & Security',
                        iconColor: const Color(0xFF505A96),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrivacySecurityScreen()),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 20),

                    // ── Group 3: Support ──────────────────
                    _buildMenuGroup([
                      _ProfileMenuItem(
                        icon: Icons.support_agent,
                        label: 'Help & Support',
                        iconColor: const Color(0xFF757686),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Help center coming soon'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                      _ProfileMenuItem(
                        icon: Icons.info,
                        label: 'About App',
                        iconColor: const Color(0xFF757686),
                        onTap: () {
                          showAboutDialog(
                            context: context,
                            applicationName: 'TechXPark',
                            applicationVersion: '2.4.1 (Build 108)',
                            applicationLegalese: '© 2026 TechXPark. All rights reserved.',
                          );
                        },
                      ),
                    ]),

                    const SizedBox(height: 40),

                    // ── Sign Out Button ───────────────────
                    _buildSignOutButton(context),

                    const SizedBox(height: 20),

                    // ── Version ───────────────────────────
                    Center(
                      child: Opacity(
                        opacity: 0.6,
                        child: Text(
                          'Version 2.4.1 (Build 108)',
                          style: AppTextStyles.caption.copyWith(
                            color: const Color(0xFF757686),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),

                    // Bottom padding for nav bar
                    const SizedBox(height: 120),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PROFILE HEADER — Avatar, Name, Email, Edit
  // ═══════════════════════════════════════════════════════════════
  Widget _buildProfileHeader(String name, String email, String? photoUrl, User user) {
    return Row(
      children: [
        // Avatar with verified badge
        GestureDetector(
          onTap: () => _showPhotoBottomSheet(context, user),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.bgLight,
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: _isUploadingPhoto
                      ? const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5)
                      : (photoUrl == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                fontSize: 28,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            )
                          : null),
                ),
              ),
              // Verified badge
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0029B9),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.verified, color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        // Name & Email
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1B23),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                email,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF444655),
                ),
              ),
            ],
          ),
        ),

        // Edit Profile button
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
          ),
          child: Text(
            'Edit Profile',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0029B9),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STATS SECTION — Bookings, Hours, Balance
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStatsSection(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        int bookingCount = 0;
        int totalHours = 0;
        double balance = 0;

        if (snapshot.hasData) {
          bookingCount = snapshot.data!.docs.length;
          for (var doc in snapshot.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            totalHours += ((d['durationHours'] as num?) ?? 1).toInt();
          }
        }

        // Fetch wallet balance from user doc
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, userSnap) {
            if (userSnap.hasData && userSnap.data!.exists) {
              final userData = userSnap.data!.data() as Map<String, dynamic>;
              balance = ((userData['walletBalance'] as num?) ?? 0).toDouble();
            }

            return SizedBox(
              height: 96,
              child: Row(
                children: [
                  // Bookings card
                  Expanded(
                    child: _StatCard(
                      label: 'BOOKINGS',
                      value: '$bookingCount',
                      isPrimary: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Hours card
                  Expanded(
                    child: _StatCard(
                      label: 'HOURS',
                      value: '$totalHours',
                      isPrimary: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Balance card — highlighted
                  Expanded(
                    child: _StatCard(
                      label: 'BALANCE',
                      value: '₹${balance.toInt()}',
                      isPrimary: true,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MENU GROUP — Grouped menu items in a card
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMenuGroup(List<_ProfileMenuItem> items) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F2FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Column(
              children: [
                _buildMenuTile(item),
                if (index < items.length - 1)
                  Divider(
                    height: 0.5,
                    thickness: 0.5,
                    color: const Color(0xFFC5C5D7).withValues(alpha: 0.3),
                    indent: 64,
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMenuTile(_ProfileMenuItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          item.onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon with tinted background
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: item.iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.label,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1B23),
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: const Color(0xFFC5C5D7),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // REFER & EARN BANNER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildReferralBanner() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0029B9), Color(0xFF2845D6)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2845D6).withValues(alpha: 0.2),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background gift icon
          Positioned(
            right: -12,
            top: -12,
            child: Opacity(
              opacity: 0.2,
              child: Icon(
                Icons.redeem,
                size: 90,
                color: Colors.white,
              ),
            ),
          ),

          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Refer & Earn',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 200,
                child: Text(
                  'Invite friends and get ₹500 off your next parking session.',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Referral feature coming soon!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Invite Friends',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0029B9),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SIGN OUT BUTTON
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSignOutButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _confirmSignOut(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFBA1A1A).withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFBA1A1A).withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, color: const Color(0xFFBA1A1A), size: 20),
            const SizedBox(width: 10),
            Text(
              'Sign Out',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFBA1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Photo bottom sheet ────────────────────────────────────
  Future<void> _showPhotoBottomSheet(BuildContext context, User user) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3E1ED),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF0029B9)),
                title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(context, user.uid, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF0029B9)),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(context, user.uid, ImageSource.gallery);
                },
              ),
              if (user.photoURL != null) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete, color: Color(0xFFBA1A1A)),
                  title: const Text('Remove Photo', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFBA1A1A))),
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() => _isUploadingPhoto = true);
                    try {
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'photoUrl': FieldValue.delete()});
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo removed')));
                      }
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
      },
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
          const SnackBar(content: Text('Profile photo updated'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: const Color(0xFFBA1A1A)),
        );
      }
    } finally {
      setState(() => _isUploadingPhoto = false);
    }
  }

  // ─── Sign out dialog ───────────────────────────────────────
  void _confirmSignOut(BuildContext context) {
    HapticFeedback.lightImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Sign Out',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1A1B23)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your bookings and vehicles will still be saved when you return.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF444655), fontSize: 14, height: 1.5),
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
                            side: const BorderSide(color: Color(0xFFC5C5D7)),
                          ),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF1A1B23), fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await FirebaseAuth.instance.signOut();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFBA1A1A),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
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

// ═══════════════════════════════════════════════════════════════
// STAT CARD — Bookings / Hours / Balance
// ═══════════════════════════════════════════════════════════════
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isPrimary;

  const _StatCard({
    required this.label,
    required this.value,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPrimary ? const Color(0xFF0029B9) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? const Color(0xFF2845D6).withValues(alpha: 0.2)
                : const Color(0xFF1A1B23).withValues(alpha: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
        border: isPrimary
            ? null
            : Border.all(
                color: const Color(0xFFC5C5D7).withValues(alpha: 0.1),
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: isPrimary
                  ? Colors.white.withValues(alpha: 0.7)
                  : const Color(0xFF444655),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isPrimary ? Colors.white : const Color(0xFF0029B9),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DATA CLASS — Profile Menu Item
// ═══════════════════════════════════════════════════════════════
class _ProfileMenuItem {
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;

  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
  });
}