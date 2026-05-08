import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../config/legal_links.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_controller.dart';
import '../../services/google_auth_service.dart';
import '../../utils/navigation_utils.dart';
import '../notifications/notifications_screen.dart';
import 'privacy_security_screen.dart';
import 'payment_methods_screen.dart';

/// Settings screen — Stitch "Settings" design.
/// Premium glassmorphic header with profile card, categorized groups.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  String _language = 'English';
  String _unitSystem = 'Metric (km)';

  @override
  void initState() {
    super.initState();
    _darkMode = ThemeController.themeMode.value == ThemeMode.dark;
  }

  Future<void> _openExternalLink(Future<bool> Function() opener) async {
    final opened = await opener();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open this link. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : AppColors.bgLight,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ═══════════════════════════════════════
            // STICKY APP BAR
            // ═══════════════════════════════════════
            SliverAppBar(
              pinned: true,
              floating: false,
              backgroundColor: (isDark ? AppColors.bgDark : Colors.white)
                  .withValues(alpha: 0.7),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back,
                  color: isDark ? Colors.white : AppColors.primary,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Settings',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    Icons.search,
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                  ),
                  onPressed: () {},
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),

                  // ═══════════════════════════════════════
                  // PROFILE QUICK CARD
                  // ═══════════════════════════════════════
                  _buildProfileCard(user, isDark),

                  const SizedBox(height: 32),

                  // ═══════════════════════════════════════
                  // ACCOUNT SETTINGS
                  // ═══════════════════════════════════════
                  _buildSectionLabel('ACCOUNT SETTINGS'),
                  const SizedBox(height: 10),
                  _buildSettingsGroup(isDark, [
                    _SettingsTile(
                      icon: Icons.person,
                      iconBg: AppColors.primary,
                      title: 'Personal Info',
                      subtitle: 'Name, email, and phone',
                      onTap: () {},
                    ),
                    _SettingsTile(
                      icon: Icons.security,
                      iconBg: AppColors.primary,
                      title: 'Security',
                      subtitle: 'Password, biometrics',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrivacySecurityScreen(),
                        ),
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.notifications,
                      iconBg: Colors.amber.shade700,
                      title: 'Notifications',
                      subtitle: 'Push, email, and SMS',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 28),

                  // ═══════════════════════════════════════
                  // APP PREFERENCES
                  // ═══════════════════════════════════════
                  _buildSectionLabel('APP PREFERENCES'),
                  const SizedBox(height: 10),
                  _buildSettingsGroup(isDark, [
                    _SettingsTile(
                      icon: Icons.dark_mode,
                      iconBg: Colors.deepPurple,
                      title: 'Theme',
                      subtitle: _darkMode ? 'Dark mode' : 'Light mode',
                      trailing: Switch.adaptive(
                        value: _darkMode,
                        activeTrackColor: AppColors.primary,
                        activeThumbColor: Colors.white,
                        onChanged: (val) {
                          HapticFeedback.lightImpact();
                          ThemeController.toggle(val);
                          setState(() => _darkMode = val);
                        },
                      ),
                    ),
                    _SettingsTile(
                      icon: Icons.language,
                      iconBg: Colors.teal,
                      title: 'Language',
                      subtitle: _language,
                      onTap: () => _showLanguagePicker(),
                    ),
                    _SettingsTile(
                      icon: Icons.straighten,
                      iconBg: Colors.orange,
                      title: 'Unit System',
                      subtitle: _unitSystem,
                      onTap: () => _showUnitPicker(),
                    ),
                  ]),

                  const SizedBox(height: 28),

                  // ═══════════════════════════════════════
                  // PAYMENTS & WALLET
                  // ═══════════════════════════════════════
                  _buildSectionLabel('PAYMENTS'),
                  const SizedBox(height: 10),
                  _buildSettingsGroup(isDark, [
                    _SettingsTile(
                      icon: Icons.account_balance_wallet,
                      iconBg: Colors.green.shade700,
                      title: 'Payments & Wallet',
                      subtitle: 'Cards, UPI, wallet',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PaymentMethodsScreen(),
                        ),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 28),

                  // ═══════════════════════════════════════
                  // SUPPORT & LEGAL
                  // ═══════════════════════════════════════
                  _buildSectionLabel('SUPPORT & LEGAL'),
                  const SizedBox(height: 10),
                  _buildSettingsGroup(isDark, [
                    _SettingsTile(
                      icon: Icons.help_outline,
                      iconBg: Colors.blueGrey,
                      title: 'Help Center',
                      onTap: () => _openExternalLink(LegalLinks.openHelpCenter),
                    ),
                    _SettingsTile(
                      icon: Icons.description_outlined,
                      iconBg: Colors.blueGrey,
                      title: 'Terms of Service',
                      onTap: () =>
                          _openExternalLink(LegalLinks.openTermsOfService),
                    ),
                    _SettingsTile(
                      icon: Icons.privacy_tip_outlined,
                      iconBg: Colors.blueGrey,
                      title: 'Privacy Policy',
                      onTap: () =>
                          _openExternalLink(LegalLinks.openPrivacyPolicy),
                    ),
                    _SettingsTile(
                      icon: Icons.info_outline,
                      iconBg: Colors.blueGrey,
                      title: 'About App',
                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'TechXPark',
                          applicationVersion: '2.4.1 (Build 108)',
                          applicationLegalese:
                              '© 2026 TechXPark. All rights reserved.',
                        );
                      },
                    ),
                  ]),

                  const SizedBox(height: 32),

                  // ═══════════════════════════════════════
                  // LOGOUT BUTTON
                  // ═══════════════════════════════════════
                  _buildLogoutButton(context, isDark),

                  const SizedBox(height: 24),

                  // Version
                  Center(
                    child: Text(
                      'Version 2.4.1 (Build 108)',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PROFILE QUICK CARD — Blue gradient with user info
  // ═══════════════════════════════════════════════════════════════
  Widget _buildProfileCard(User? user, bool isDark) {
    return StreamBuilder<DocumentSnapshot>(
      stream: user != null
          ? FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots()
          : null,
      builder: (context, snapshot) {
        String name = 'User';
        String subtitle = 'Premium Member • TechXPark Platinum';
        String? photoUrl;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['name'] ?? 'User';
          photoUrl = data['photoUrl'] as String?;
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative circle
              Positioned(
                right: -30,
                top: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Row(
                children: [
                  // Avatar
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white.withValues(alpha: 0.15),
                      backgroundImage: photoUrl != null
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'U',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
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
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SECTION LABEL
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textTertiaryLight,
          letterSpacing: 1,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SETTINGS GROUP — Card container with items
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSettingsGroup(bool isDark, List<_SettingsTile> tiles) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: tiles.asMap().entries.map((entry) {
          final index = entry.key;
          final tile = entry.value;
          return Column(
            children: [
              _buildTileWidget(tile, isDark),
              if (index < tiles.length - 1)
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  indent: 64,
                  color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTileWidget(_SettingsTile tile, bool isDark) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tile.onTap != null
            ? () {
                HapticFeedback.selectionClick();
                tile.onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tile.iconBg.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(tile.icon, color: tile.iconBg, size: 20),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tile.title,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    if (tile.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        tile.subtitle!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Trailing
              tile.trailing ??
                  Icon(
                    Icons.chevron_right,
                    color: isDark ? Colors.white24 : const Color(0xFFC5C5D8),
                    size: 22,
                  ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // LOGOUT BUTTON
  // ═══════════════════════════════════════════════════════════════
  Widget _buildLogoutButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.mediumImpact();
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(color: Color(0xFFBA1A1A)),
                ),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await GoogleAuthService().signOut();
          if (context.mounted) safeShowAuthState(context);
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.error),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Text(
              'Sign Out',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PICKERS
  // ═══════════════════════════════════════════════════════════════
  void _showLanguagePicker() {
    final languages = ['English', 'Hindi', 'Punjabi', 'Tamil', 'Telugu'];
    showModalBottomSheet(
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
            const SizedBox(height: 16),
            ...languages.map(
              (lang) => ListTile(
                title: Text(
                  lang,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: _language == lang
                    ? const Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 22,
                      )
                    : null,
                onTap: () {
                  setState(() => _language = lang);
                  Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showUnitPicker() {
    final units = ['Metric (km)', 'Imperial (mi)'];
    showModalBottomSheet(
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
            const SizedBox(height: 16),
            ...units.map(
              (unit) => ListTile(
                title: Text(
                  unit,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: _unitSystem == unit
                    ? const Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 22,
                      )
                    : null,
                onTap: () {
                  setState(() => _unitSystem = unit);
                  Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SETTINGS TILE MODEL
// ═══════════════════════════════════════════════════════════════
class _SettingsTile {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
}
