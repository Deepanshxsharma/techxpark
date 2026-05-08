import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../../services/google_auth_service.dart';
import '../../utils/navigation_utils.dart';
import '../booking/my_bookings_screen.dart';
import '../settings/settings_screen.dart';
import 'help_center_screen.dart';
import 'loyalty_screen.dart';
import 'my_vehicles_screen.dart';
import 'payments_screen.dart';
import 'personal_info_screen.dart';
import 'saved_locations_screen.dart';

class ProfileScreen extends StatefulWidget {
  final ValueChanged<int>? onTabSwitch;

  const ProfileScreen({super.key, this.onTabSwitch});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isUploadingPhoto = false;
  bool _notificationsEnabled = true;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _isDarkMode = ThemeController.themeMode.value == ThemeMode.dark;
    _ensureUserDocument();
  }

  Future<void> _ensureUserDocument() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': user.displayName ?? 'TechXPark User',
      'email': user.email ?? '',
      'phone': user.phoneNumber ?? '',
      'photoUrl': user.photoURL ?? '',
      'role': 'customer',
      'totalBookings': 0,
      'totalHours': 0,
      'totalSpent': 0,
      'notificationsEnabled': true,
      'smsEnabled': true,
      'isOnline': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'fcmToken': null,
      'banned': false,
      'referralCode': _referralCodeFor(user.uid),
    }, SetOptions(merge: true));
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.bgLight,
        body: Center(
          child: Text(
            'Please log in to view your profile.',
            style: GoogleFonts.poppins(color: const Color(0xFF757686)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFF7F8FC).withValues(alpha: 0.92),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            titleSpacing: 20,
            title: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.maybePop(context),
                  child: const Icon(
                    Icons.arrow_back,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Profile',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF181C20),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings, color: AppColors.primary),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              _profileHeaderCard(user),
              _referralCard(),
              _menuCard(
                title: 'Account',
                items: [
                  _menuItem(
                    icon: Icons.person_rounded,
                    iconBg: const Color(0xFFEEF2FF),
                    iconColor: const Color(0xFF0029B9),
                    title: 'Personal Info',
                    subtitle: 'Name, email, phone number',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PersonalInfoScreen(),
                      ),
                    ),
                  ),
                  _menuItem(
                    icon: Icons.directions_car_rounded,
                    iconBg: const Color(0xFFE8EAF6),
                    iconColor: const Color(0xFF283593),
                    title: 'My Vehicles',
                    subtitle: 'Manage your saved vehicles',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MyVehiclesScreen(),
                      ),
                    ),
                  ),
                  _menuItem(
                    icon: Icons.calendar_today_rounded,
                    iconBg: const Color(0xFFE8F5E9),
                    iconColor: const Color(0xFF2E7D32),
                    title: 'My Bookings',
                    subtitle: 'Active, upcoming and past',
                    onTap: _openBookings,
                  ),
                  _menuItem(
                    icon: Icons.bookmark_rounded,
                    iconBg: const Color(0xFFFFF8E1),
                    iconColor: const Color(0xFFF57F17),
                    title: 'Saved Locations',
                    subtitle: 'Your favourite parking lots',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SavedLocationsScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              _menuCard(
                title: 'Payments',
                items: [
                  _menuItem(
                    icon: Icons.account_balance_wallet_rounded,
                    iconBg: const Color(0xFFE8EAF6),
                    iconColor: const Color(0xFF4527A0),
                    title: 'Payments & Wallet',
                    subtitle: 'Transaction history',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PaymentsScreen()),
                    ),
                  ),
                  _menuItem(
                    icon: Icons.receipt_long_rounded,
                    iconBg: const Color(0xFFF3E5F5),
                    iconColor: const Color(0xFF7B1FA2),
                    title: 'Receipts & Invoices',
                    subtitle: 'Download PDF receipts',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReceiptsScreen()),
                    ),
                  ),
                  _menuItem(
                    icon: Icons.workspace_premium_rounded,
                    iconBg: const Color(0xFFFFF3E0),
                    iconColor: const Color(0xFFE65100),
                    title: 'Loyalty Points',
                    subtitle: 'Rewards and parking credits',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '0 pts',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFFE65100),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoyaltyScreen()),
                    ),
                  ),
                ],
              ),
              _preferencesCard(user.uid),
              _menuCard(
                title: 'Help & Support',
                items: [
                  _menuItem(
                    icon: Icons.headset_mic_rounded,
                    iconBg: const Color(0xFFE0F7FA),
                    iconColor: const Color(0xFF00838F),
                    title: 'Help Center',
                    subtitle: 'FAQs and guides',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HelpCenterScreen(),
                      ),
                    ),
                  ),
                  _menuItem(
                    icon: Icons.chat_bubble_rounded,
                    iconBg: const Color(0xFFE8F5E9),
                    iconColor: const Color(0xFF2E7D32),
                    title: 'Contact Support',
                    subtitle: 'Chat with our team',
                    onTap: _openMessages,
                  ),
                  _menuItem(
                    icon: Icons.star_rounded,
                    iconBg: const Color(0xFFFFF8E1),
                    iconColor: const Color(0xFFF9A825),
                    title: 'Rate TechXPark',
                    subtitle: 'Share your experience',
                    onTap: () => _openWebLink(
                      'https://play.google.com/store/apps/details?id=com.techxpark.parking',
                    ),
                  ),
                  _menuItem(
                    icon: Icons.share_rounded,
                    iconBg: const Color(0xFFEEF2FF),
                    iconColor: const Color(0xFF0029B9),
                    title: 'Share TechXPark',
                    subtitle: 'Tell friends about us',
                    onTap: () => SharePlus.instance.share(
                      ShareParams(
                        text:
                            'Park smarter with TechXPark! Book parking in seconds. Download now: https://techxpark.in',
                      ),
                    ),
                  ),
                ],
              ),
              _menuCard(
                title: 'Legal',
                items: [
                  _menuItem(
                    icon: Icons.description_rounded,
                    iconBg: const Color(0xFFF1F4F9),
                    iconColor: const Color(0xFF444655),
                    title: 'Terms of Service',
                    subtitle: '',
                    onTap: () => _openWebLink('https://techxpark.in/terms'),
                  ),
                  _menuItem(
                    icon: Icons.privacy_tip_rounded,
                    iconBg: const Color(0xFFF1F4F9),
                    iconColor: const Color(0xFF444655),
                    title: 'Privacy Policy',
                    subtitle: '',
                    onTap: () => _openWebLink('https://techxpark.in/privacy'),
                  ),
                  _menuItem(
                    icon: Icons.info_rounded,
                    iconBg: const Color(0xFFF1F4F9),
                    iconColor: const Color(0xFF444655),
                    title: 'About TechXPark',
                    subtitle: 'Version 1.0.0',
                    onTap: () => _showAboutDialog(context),
                  ),
                ],
              ),
              _signOutButton(),
              _versionFooter(),
              const SizedBox(height: 110),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _profileHeaderCard(User user) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final name =
            data['name']?.toString() ?? user.displayName ?? 'TechXPark User';
        final email = data['email']?.toString() ?? user.email ?? '';
        final phone = data['phone']?.toString() ?? '';
        final photoUrl = data['photoUrl']?.toString() ?? user.photoURL ?? '';
        final totalBookings = (data['totalBookings'] as num?)?.toInt() ?? 0;
        final totalHours = (data['totalHours'] as num?)?.toInt() ?? 0;
        final totalSpent = (data['totalSpent'] as num?)?.toInt() ?? 0;
        final notifications =
            data['notificationsEnabled'] as bool? ?? _notificationsEnabled;

        if (notifications != _notificationsEnabled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _notificationsEnabled = notifications);
          });
        }

        return Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFF0029B9), Color(0xFF2845D6)],
                          ),
                        ),
                        child: _isUploadingPhoto
                            ? const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : photoUrl.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _avatarInitial(name),
                                ),
                              )
                            : _avatarInitial(name),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _editPhoto(context),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              color: Color(0xFF0029B9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF181C20),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          email.isNotEmpty ? email : phone,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: const Color(0xFF757686),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF0029B9),
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'TechXPark Member',
                                style: GoogleFonts.poppins(
                                  color: const Color(0xFF0029B9),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PersonalInfoScreen(initialData: data),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Text(
                        'Edit',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF0029B9),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFF1F4F9)),
              const SizedBox(height: 16),
              Row(
                children: [
                  _statItem(totalBookings.toString(), 'Bookings'),
                  _dividerLine(),
                  _statItem('${totalHours}h', 'Hours'),
                  _dividerLine(),
                  _statItem('₹$totalSpent', 'Spent'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _avatarInitial(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0029B9),
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFF757686),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dividerLine() =>
      Container(width: 1, height: 36, color: const Color(0xFFF1F4F9));

  Widget _referralCard() {
    return GestureDetector(
      onTap: () => _shareReferral(context),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0029B9), Color(0xFF1E3A8A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Refer & Earn',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Invite friends and get ₹100 off\nyour next parking session.',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.share_rounded,
                          color: Color(0xFF0029B9),
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Invite Friends',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF0029B9),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.card_giftcard_rounded,
              color: Colors.white30,
              size: 64,
            ),
          ],
        ),
      ),
    );
  }

  Widget _preferencesCard(String uid) {
    return _menuCard(
      title: 'Preferences',
      items: [
        _menuItemWithToggle(
          icon: Icons.notifications_rounded,
          iconBg: const Color(0xFFE3F2FD),
          iconColor: const Color(0xFF1565C0),
          title: 'Notifications',
          subtitle: 'Push, email & SMS alerts',
          value: _notificationsEnabled,
          onToggle: (val) async {
            setState(() => _notificationsEnabled = val);
            await FirebaseFirestore.instance.collection('users').doc(uid).set({
              'notificationsEnabled': val,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          },
        ),
        _menuItemWithToggle(
          icon: Icons.dark_mode_rounded,
          iconBg: const Color(0xFFECECF4),
          iconColor: const Color(0xFF181C20),
          title: 'Dark Mode',
          subtitle: 'Switch app appearance',
          value: _isDarkMode,
          onToggle: (val) async {
            setState(() => _isDarkMode = val);
            await ThemeController.toggle(val);
          },
        ),
        _menuItem(
          icon: Icons.language_rounded,
          iconBg: const Color(0xFFE8F5E9),
          iconColor: const Color(0xFF2E7D32),
          title: 'Language',
          subtitle: 'English (US)',
          onTap: () => _showLanguagePicker(context),
        ),
      ],
    );
  }

  Widget _menuCard({required String title, required List<Widget> items}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              title.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF757686),
                letterSpacing: 1,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: items.asMap().entries.map((e) {
                final isLast = e.key == items.length - 1;
                return Column(
                  children: [
                    e.value,
                    if (!isLast)
                      const Divider(
                        height: 1,
                        indent: 64,
                        color: Color(0xFFF1F4F9),
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF181C20),
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF757686),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFFC5C5D7),
                ),
          ],
        ),
      ),
    );
  }

  Widget _menuItemWithToggle({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onToggle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF181C20),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF757686),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onToggle,
            activeThumbColor: const Color(0xFF0029B9),
          ),
        ],
      ),
    );
  }

  Widget _signOutButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: GestureDetector(
        onTap: () => _confirmSignOut(context),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFCDD2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.logout_rounded,
                color: Color(0xFFBA1A1A),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Sign Out',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFBA1A1A),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _versionFooter() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'TechXPark',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0029B9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version 1.0.0 · Build 1',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFFC5C5D7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Made with love in India',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: const Color(0xFFC5C5D7),
            ),
          ),
        ],
      ),
    );
  }

  void _openBookings() {
    if (widget.onTabSwitch != null) {
      widget.onTabSwitch!(2);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
    );
  }

  void _openMessages() {
    if (widget.onTabSwitch != null) {
      widget.onTabSwitch!(3);
      return;
    }
    Navigator.pushNamed(context, '/messages');
  }

  Future<void> _editPhoto(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
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
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: Color(0xFF0029B9),
              ),
              title: Text('Take Photo', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadPhoto(user.uid, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: Color(0xFF0029B9),
              ),
              title: Text('Choose from Gallery', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadPhoto(user.uid, ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_rounded,
                color: Color(0xFFBA1A1A),
              ),
              title: Text(
                'Remove Photo',
                style: GoogleFonts.poppins(color: const Color(0xFFBA1A1A)),
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await _removePhoto(user.uid);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(String uid, ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final ref = FirebaseStorage.instance.ref('profile_photos/$uid.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'photoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await user?.updatePhotoURL(url);
      if (mounted) _showSnack('Profile photo updated');
    } catch (e) {
      if (mounted) _showSnack('Upload failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _removePhoto(String uid) async {
    setState(() => _isUploadingPhoto = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'photoUrl': '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await FirebaseAuth.instance.currentUser?.updatePhotoURL('');
      if (mounted) _showSnack('Profile photo removed');
    } catch (e) {
      if (mounted) _showSnack('Could not remove photo: $e', error: true);
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _shareReferral(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final referralCode = _referralCodeFor(uid);
    final message =
        'Join TechXPark and park smarter! Use my code $referralCode for ₹100 off your first booking. Download: https://techxpark.in';
    SharePlus.instance.share(ShareParams(text: message));
  }

  String _referralCodeFor(String uid) {
    if (uid.isEmpty) return 'TXPARK';
    return uid.substring(0, uid.length < 6 ? uid.length : 6).toUpperCase();
  }

  Future<void> _openWebLink(String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showSnack('Could not open link. Please try again.', error: true);
    }
  }

  void _showLanguagePicker(BuildContext context) {
    const languages = ['English (US)', 'Hindi', 'Punjabi', 'Tamil', 'Telugu'];
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ...languages.map(
              (language) => ListTile(
                title: Text(language, style: GoogleFonts.poppins()),
                trailing: language == 'English (US)'
                    ? const Icon(Icons.check, color: Color(0xFF0029B9))
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _showSnack('$language selected');
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'TechXPark',
      applicationVersion: '1.0.0 (Build 1)',
      applicationLegalese: '© 2026 TechXPark. All rights reserved.',
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Sign Out?',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'You will need to sign in again to access your bookings.',
          style: GoogleFonts.poppins(color: const Color(0xFF757686)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: const Color(0xFF757686),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await GoogleAuthService().signOut();
              if (context.mounted) safeShowAuthState(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            child: Text(
              'Sign Out',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFBA1A1A) : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
