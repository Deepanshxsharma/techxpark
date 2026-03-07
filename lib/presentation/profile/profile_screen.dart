import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../notifications/notifications_screen.dart';
import 'edit_profile_screen.dart';
import 'privacy_security_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploadingPhoto = false;
  bool _darkMode = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            'Please log in to view your profile.',
            style: AppTextStyles.body1.copyWith(color: AppColors.textSecondaryLight),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            // Blue rounded square P icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'P',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Profile',
              style: AppTextStyles.h2.copyWith(
                color: AppColors.textPrimaryLight,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderLight, width: 1.5),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.more_horiz, color: AppColors.textSecondaryLight, size: 20),
              onPressed: () {
                // More options
              },
            ),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['name'] ?? 'User';
          final photoUrl = data['photoUrl'] as String?;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 24),

                // ═══════════════════════════════════════
                // AVATAR + NAME + EMAIL
                // ═══════════════════════════════════════
                Center(
                  child: Stack(
                    children: [
                      // Avatar
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 45,
                          backgroundColor: AppColors.bgLight,
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                          child: photoUrl == null
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      // Upload overlay
                      if (_isUploadingPhoto)
                        const Positioned.fill(
                          child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3)),
                        ),
                      // Edit badge — blue rounded square
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _showPhotoBottomSheet(context, user),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2845D6),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2845D6).withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.edit, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Name
                Text(
                  name,
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),

                // Email
                Text(
                  user.email ?? '',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 24),

                // Divider
                Divider(height: 1, thickness: 1, color: AppColors.borderLight.withOpacity(0.5), indent: 24, endIndent: 24),
                const SizedBox(height: 8),

                // ═══════════════════════════════════════
                // MENU ITEMS
                // ═══════════════════════════════════════
                _menuItem(
                  icon: Icons.person_outline,
                  label: 'Edit Profile',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen())),
                ),
                _divider(),
                _menuItem(
                  icon: Icons.credit_card_outlined,
                  label: 'Payment',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment coming soon'), behavior: SnackBarBehavior.floating),
                    );
                  },
                ),
                _divider(),
                _menuItem(
                  icon: Icons.notifications_none_outlined,
                  label: 'Notifications',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
                ),
                _divider(),
                _menuItem(
                  icon: Icons.shield_outlined,
                  label: 'Security',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySecurityScreen())),
                ),
                _divider(),
                _menuItem(
                  icon: Icons.help_outline,
                  label: 'Help',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Help center coming soon'), behavior: SnackBarBehavior.floating),
                    );
                  },
                ),
                _divider(),

                // Dark Theme toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        const Icon(Icons.dark_mode_outlined, color: AppColors.textSecondaryLight, size: 24),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Dark Theme',
                            style: AppTextStyles.body1.copyWith(
                              color: AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        Switch(
                          value: _darkMode,
                          onChanged: (v) => setState(() => _darkMode = v),
                          activeColor: AppColors.primary,
                          activeTrackColor: AppColors.primary.withOpacity(0.3),
                          inactiveThumbColor: AppColors.textTertiaryLight,
                          inactiveTrackColor: AppColors.borderLight,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ═══════════════════════════════════════
                // LOGOUT
                // ═══════════════════════════════════════
                InkWell(
                  onTap: () => _confirmSignOut(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: AppColors.error, size: 24),
                          SizedBox(width: 16),
                          Text(
                            'Logout',
                            style: AppTextStyles.body1.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Menu item ─────────────────────────────────────────────
  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              Icon(icon, color: AppColors.textSecondaryLight, size: 24),
              const SizedBox(width: 16),
              Text(
                label,
                style: AppTextStyles.body1.copyWith(
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: AppColors.inputBgLight,
      indent: 64,
      endIndent: 24,
    );
  }

  // ─── Photo bottom sheet ────────────────────────────────────
  Future<void> _showPhotoBottomSheet(BuildContext context, User user) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: const Color(0xFFE8ECF4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF2845D6)),
                title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(context, user.uid, ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF2845D6)),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadPhoto(context, user.uid, ImageSource.gallery);
                },
              ),
              if (user.photoURL != null) ...[
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete, color: Color(0xFFE5393B)),
                  title: const Text('Remove Photo', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFE5393B))),
                  onTap: () async {
                    Navigator.pop(ctx);
                    setState(() => _isUploadingPhoto = true);
                    try {
                      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'photoUrl': FieldValue.delete()});
                      if (mounted) {
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
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: const Color(0xFFE5393B)),
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
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0D1117)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your bookings and vehicles will still be saved when you return.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF5C6B8A), fontSize: 14, height: 1.5),
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
                            side: const BorderSide(color: Color(0xFFE8ECF4)),
                          ),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF0D1117), fontWeight: FontWeight.w600)),
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
                            backgroundColor: const Color(0xFFE5393B),
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