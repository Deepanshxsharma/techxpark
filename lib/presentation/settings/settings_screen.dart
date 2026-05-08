import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../../services/google_auth_service.dart';
import '../../utils/navigation_utils.dart';
import '../profile/help_center_screen.dart';
import '../profile/personal_info_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDark = false;
  bool _pushEnabled = true;
  bool _smsEnabled = true;
  bool _locationEnabled = false;
  bool _biometricEnabled = false;
  String _language = 'English (US)';
  String _unit = 'Kilometers (km)';
  String _version = 'v1.0.0 (Build 1)';

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _isDark = ThemeController.themeMode.value == ThemeMode.dark;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = FirebaseAuth.instance.currentUser;
    final locationAvailable = await _isLocationAvailable();
    final info = await PackageInfo.fromPlatform();
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? {};

    if (!mounted) return;
    setState(() {
      _pushEnabled = data['notificationsEnabled'] as bool? ?? true;
      _smsEnabled = data['smsEnabled'] as bool? ?? true;
      _locationEnabled = data['locationEnabled'] as bool? ?? locationAvailable;
      _biometricEnabled = data['biometricEnabled'] as bool? ?? false;
      _language = data['language']?.toString() ?? 'English (US)';
      _unit = data['distanceUnit']?.toString() ?? 'Kilometers (km)';
      _version = 'v${info.version} (Build ${info.buildNumber})';
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF181C20),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF444655)),
            onPressed: () => _showSettingsSearch(context),
          ),
        ],
      ),
      body: user == null
          ? Center(
              child: Text(
                'Please sign in again.',
                style: GoogleFonts.poppins(),
              ),
            )
          : ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _profileCard(user),
                _settingsSection(
                  title: 'Account Settings',
                  children: [
                    _settingsItem(
                      icon: Icons.person_rounded,
                      title: 'Personal Information',
                      subtitle: 'Update your profile details',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PersonalInfoScreen(),
                        ),
                      ),
                    ),
                    _settingsItem(
                      icon: Icons.lock_rounded,
                      title: 'Password & Security',
                      subtitle: 'Change password, 2FA',
                      onTap: () => _showSecurityOptions(context),
                    ),
                    _settingsItem(
                      icon: Icons.phone_rounded,
                      title: 'Phone Number',
                      subtitle: user.phoneNumber ?? 'Not set',
                      onTap: () => _updatePhone(context),
                    ),
                    _settingsItem(
                      icon: Icons.email_rounded,
                      title: 'Email Address',
                      subtitle: user.email ?? 'Not set',
                      onTap: () => _updateEmail(context),
                    ),
                  ],
                ),
                _settingsSection(
                  title: 'App Preferences',
                  children: [
                    _settingsToggle(
                      icon: Icons.dark_mode_rounded,
                      title: 'Dark Mode',
                      subtitle: _isDark
                          ? 'Currently: Dark'
                          : 'Currently: Light',
                      value: _isDark,
                      onToggle: (v) async {
                        setState(() => _isDark = v);
                        await ThemeController.toggle(v);
                      },
                    ),
                    _settingsToggle(
                      icon: Icons.notifications_rounded,
                      title: 'Push Notifications',
                      subtitle: 'Booking updates and reminders',
                      value: _pushEnabled,
                      onToggle: (v) async {
                        setState(() => _pushEnabled = v);
                        await _updateUserSetting('notificationsEnabled', v);
                        if (v) {
                          await FirebaseMessaging.instance.requestPermission();
                        }
                      },
                    ),
                    _settingsToggle(
                      icon: Icons.sms_rounded,
                      title: 'SMS Notifications',
                      subtitle: 'Get SMS for booking events',
                      value: _smsEnabled,
                      onToggle: (v) async {
                        setState(() => _smsEnabled = v);
                        await _updateUserSetting('smsEnabled', v);
                      },
                    ),
                    _settingsToggle(
                      icon: Icons.location_on_rounded,
                      title: 'Location Services',
                      subtitle: 'For nearby parking detection',
                      value: _locationEnabled,
                      onToggle: (v) async {
                        if (v) {
                          final permission =
                              await Geolocator.requestPermission();
                          final allowed =
                              permission == LocationPermission.always ||
                              permission == LocationPermission.whileInUse;
                          setState(() => _locationEnabled = allowed);
                          await _updateUserSetting('locationEnabled', allowed);
                        } else {
                          setState(() => _locationEnabled = false);
                          await _updateUserSetting('locationEnabled', false);
                          await Geolocator.openAppSettings();
                        }
                      },
                    ),
                    _settingsItem(
                      icon: Icons.language_rounded,
                      title: 'Language',
                      subtitle: _language,
                      onTap: () => _showLanguagePicker(context),
                    ),
                    _settingsItem(
                      icon: Icons.straighten_rounded,
                      title: 'Distance Units',
                      subtitle: _unit,
                      onTap: () => _showUnitPicker(context),
                    ),
                  ],
                ),
                _settingsSection(
                  title: 'Privacy & Security',
                  children: [
                    _settingsItem(
                      icon: Icons.fingerprint_rounded,
                      title: 'Biometric Login',
                      subtitle: _biometricEnabled
                          ? 'Enabled on this device'
                          : 'Use Face ID or fingerprint',
                      onTap: () => _toggleBiometric(context),
                    ),
                    _settingsItem(
                      icon: Icons.delete_forever_rounded,
                      title: 'Delete Account',
                      subtitle: 'Permanently remove your data',
                      isDestructive: true,
                      onTap: () => _confirmDeleteAccount(context),
                    ),
                    _settingsItem(
                      icon: Icons.download_rounded,
                      title: 'Download My Data',
                      subtitle: 'Export all your parking data',
                      onTap: () => _downloadUserData(context),
                    ),
                  ],
                ),
                _settingsSection(
                  title: 'Support & Legal',
                  children: [
                    _settingsItem(
                      icon: Icons.help_rounded,
                      title: 'Help Center',
                      subtitle: 'FAQs and support guides',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HelpCenterScreen(),
                        ),
                      ),
                    ),
                    _settingsItem(
                      icon: Icons.article_rounded,
                      title: 'Terms of Service',
                      subtitle: '',
                      onTap: () => _launch('https://techxpark.in/terms'),
                    ),
                    _settingsItem(
                      icon: Icons.privacy_tip_rounded,
                      title: 'Privacy Policy',
                      subtitle: '',
                      onTap: () => _launch('https://techxpark.in/privacy'),
                    ),
                    _settingsItem(
                      icon: Icons.info_rounded,
                      title: 'App Version',
                      subtitle: _version,
                      onTap: () => _showAboutDialog(context),
                    ),
                  ],
                ),
                _logoutButton(),
              ],
            ),
    );
  }

  Widget _profileCard(User user) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() ?? {};
        final name =
            data['name']?.toString() ?? user.displayName ?? 'TechXPark User';
        final email = data['email']?.toString() ?? user.email ?? '';
        final photoUrl = data['photoUrl']?.toString() ?? user.photoURL ?? '';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFEEF2FF),
                backgroundImage: photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF181C20),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF757686),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        'Customer',
                        style: GoogleFonts.poppins(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PersonalInfoScreen(initialData: data),
                  ),
                ),
                child: Text(
                  'Edit Profile',
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _settingsSection({
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              title.toUpperCase(),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF757686),
                letterSpacing: 1,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: children.asMap().entries.map((entry) {
                final last = entry.key == children.length - 1;
                return Column(
                  children: [
                    entry.value,
                    if (!last)
                      const Divider(
                        height: 1,
                        indent: 66,
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

  Widget _settingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? const Color(0xFFBA1A1A) : AppColors.primary;
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
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: isDestructive
                          ? const Color(0xFFBA1A1A)
                          : const Color(0xFF181C20),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF757686),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
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

  Widget _settingsToggle({
    required IconData icon,
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
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF181C20),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF757686),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppColors.primary,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }

  Widget _logoutButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
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

  Future<void> _updateUserSetting(String key, Object value) async {
    final id = uid;
    if (id == null) return;
    await FirebaseFirestore.instance.collection('users').doc(id).set({
      key: value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> _isLocationAvailable() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  void _showSecurityOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.password_rounded),
              title: const Text('Send password reset email'),
              onTap: () async {
                Navigator.pop(ctx);
                final email = FirebaseAuth.instance.currentUser?.email;
                if (email == null || email.isEmpty) {
                  _showSnack(
                    'No email address is linked to this account.',
                    error: true,
                  );
                  return;
                }
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: email,
                );
                _showSnack('Password reset email sent.');
              },
            ),
            ListTile(
              leading: const Icon(Icons.fingerprint_rounded),
              title: const Text('Biometric login'),
              onTap: () {
                Navigator.pop(ctx);
                _toggleBiometric(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updatePhone(BuildContext context) async {
    final controller = TextEditingController(
      text: FirebaseAuth.instance.currentUser?.phoneNumber ?? '',
    );
    final value = await _showTextDialog(
      context,
      title: 'Phone Number',
      controller: controller,
      keyboardType: TextInputType.phone,
    );
    if (value == null) return;
    await _updateUserSetting('phone', value.trim());
    _showSnack('Phone number updated.');
  }

  Future<void> _updateEmail(BuildContext context) async {
    final controller = TextEditingController(
      text: FirebaseAuth.instance.currentUser?.email ?? '',
    );
    final value = await _showTextDialog(
      context,
      title: 'Email Address',
      controller: controller,
      keyboardType: TextInputType.emailAddress,
    );
    if (value == null) return;
    final email = value.trim();
    await _updateUserSetting('email', email);
    try {
      await FirebaseAuth.instance.currentUser?.verifyBeforeUpdateEmail(email);
      _showSnack('Verification email sent to $email.');
    } on FirebaseAuthException catch (e) {
      _showSnack(
        e.message ?? 'Email saved to profile.',
        error: e.code != 'requires-recent-login',
      );
    }
  }

  Future<String?> _showTextDialog(
    BuildContext context, {
    required String title,
    required TextEditingController controller,
    required TextInputType keyboardType,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(labelText: title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    const languages = ['English (US)', 'Hindi', 'Punjabi', 'Tamil', 'Telugu'];
    _showPicker(
      context,
      title: 'Language',
      options: languages,
      selected: _language,
      onSelected: (value) async {
        setState(() => _language = value);
        await _updateUserSetting('language', value);
      },
    );
  }

  void _showUnitPicker(BuildContext context) {
    const units = ['Kilometers (km)', 'Miles (mi)'];
    _showPicker(
      context,
      title: 'Distance Units',
      options: units,
      selected: _unit,
      onSelected: (value) async {
        setState(() => _unit = value);
        await _updateUserSetting('distanceUnit', value);
      },
    );
  }

  void _showPicker(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
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
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...options.map(
              (option) => ListTile(
                title: Text(option),
                trailing: option == selected
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
                onTap: () {
                  Navigator.pop(ctx);
                  onSelected(option);
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleBiometric(BuildContext context) async {
    final auth = LocalAuthentication();
    final supported = await auth.isDeviceSupported();
    final canCheck = await auth.canCheckBiometrics;
    if (!supported || !canCheck) {
      _showSnack(
        'Biometric authentication is not available on this device.',
        error: true,
      );
      return;
    }

    final authenticated = await auth.authenticate(
      localizedReason: 'Confirm it is you to update biometric login.',
      options: const AuthenticationOptions(biometricOnly: false),
    );
    if (!authenticated) return;

    final next = !_biometricEnabled;
    setState(() => _biometricEnabled = next);
    await _updateUserSetting('biometricEnabled', next);
    _showSnack(next ? 'Biometric login enabled.' : 'Biometric login disabled.');
  }

  Future<void> _downloadUserData(BuildContext context) async {
    final id = uid;
    if (id == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(id)
        .get();
    final bookings = await FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: id)
        .get();
    final vehicles = await FirebaseFirestore.instance
        .collection('users')
        .doc(id)
        .collection('vehicles')
        .get();

    final export = {
      'profile': userDoc.data(),
      'bookings': bookings.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
      'vehicles': vehicles.docs.map((d) => {'id': d.id, ...d.data()}).toList(),
      'exportedAt': DateTime.now().toIso8601String(),
    };
    final text = const JsonEncoder.withIndent('  ').convert(export);
    await Clipboard.setData(ClipboardData(text: text));
    _showSnack('Your data export was copied to the clipboard.');
  }

  void _confirmDeleteAccount(BuildContext context) {
    final id = uid;
    if (id == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Account?',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            color: const Color(0xFFBA1A1A),
          ),
        ),
        content: Text(
          'This will permanently delete your account and all your booking history. This action cannot be undone.',
          style: GoogleFonts.poppins(color: const Color(0xFF757686)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(id)
                    .delete();
                await FirebaseAuth.instance.currentUser?.delete();
              } on FirebaseAuthException catch (e) {
                _showSnack(
                  e.code == 'requires-recent-login'
                      ? 'Please sign in again before deleting your account.'
                      : e.message ?? 'Could not delete account.',
                  error: true,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
            ),
            child: Text(
              'Delete Account',
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await GoogleAuthService().signOut();
              if (context.mounted) safeShowAuthState(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBA1A1A),
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettingsSearch(BuildContext context) {
    final items = <String, VoidCallback>{
      'Personal Information': () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PersonalInfoScreen()),
      ),
      'Password & Security': () => _showSecurityOptions(context),
      'Push Notifications': () {},
      'Location Services': () {},
      'Help Center': () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
      ),
      'Delete Account': () => _confirmDeleteAccount(context),
    };
    showSearch<void>(
      context: context,
      delegate: _SettingsSearchDelegate(items),
    );
  }

  Future<void> _launch(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened) _showSnack('Could not open link.', error: true);
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'TechXPark',
      applicationVersion: _version,
      applicationLegalese: '© 2026 TechXPark. All rights reserved.',
    );
  }

  void _showSnack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFFBA1A1A) : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SettingsSearchDelegate extends SearchDelegate<void> {
  final Map<String, VoidCallback> items;

  _SettingsSearchDelegate(this.items);

  @override
  List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final matches = items.keys
        .where((item) => item.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return ListView(
      children: matches
          .map(
            (item) => ListTile(
              title: Text(item),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              onTap: () {
                close(context, null);
                items[item]?.call();
              },
            ),
          )
          .toList(),
    );
  }
}
