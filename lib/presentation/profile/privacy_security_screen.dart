import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../theme/app_colors.dart';

/// Privacy & Security Screen — Stitch design.
/// Grouped security settings, danger zone with delete account,
/// Stitch-consistent typography and spacing.
class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  String _appVersion = 'Loading...';
  bool _biometricEnabled = true;
  bool _twoFactorEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion =
            'TechXPark v${info.version} (Build ${info.buildNumber})';
      });
    } catch (e) {
      setState(() => _appVersion = 'TechXPark v2.4.1');
    }
  }

  Future<void> _resetPassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      try {
        await FirebaseAuth.instance
            .sendPasswordResetEmail(email: user.email!);
        if (mounted) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reset email sent to ${user.email}'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final controller = TextEditingController();
    bool confirmed = await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Delete Account',
                style: TextStyle(fontWeight: FontWeight.w800)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action is permanent and irreversible.\nAll your bookings, vehicles, and data will be deleted.\n\nType "DELETE" to confirm.',
                  style: TextStyle(
                      color: Color(0xFF64748B), height: 1.5),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: 'DELETE',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: AppColors.error, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (controller.text.trim() == 'DELETE') {
                    Navigator.pop(ctx, true);
                  }
                },
                child: const Text('Delete permanently',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      try {
        final bookings = await FirebaseFirestore.instance
            .collection('bookings')
            .where('userId', isEqualTo: user.uid)
            .get();
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in bookings.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();
        await user.delete();
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF9F9FB),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor:
                  (isDark ? AppColors.bgDark : const Color(0xFFF9F9FB))
                      .withValues(alpha: 0.85),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back,
                    color: isDark ? Colors.white : const Color(0xFF0029B9)),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Privacy & Security',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1C1D),
                  letterSpacing: -0.3,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 16),

                  // ═══════════════════════════════════════
                  // SECURITY
                  // ═══════════════════════════════════════
                  _sectionLabel('SECURITY'),
                  const SizedBox(height: 10),
                  _buildGroup(isDark, [
                    _tile(
                      icon: Icons.lock_outline,
                      iconBg: AppColors.primary,
                      title: 'Change Password',
                      subtitle: 'Send reset link to email',
                      isDark: isDark,
                      onTap: _resetPassword,
                    ),
                    _switchTile(
                      icon: Icons.fingerprint,
                      iconBg: Colors.deepPurple,
                      title: 'Biometric Login',
                      subtitle: 'Face ID / Fingerprint',
                      value: _biometricEnabled,
                      isDark: isDark,
                      onChanged: (v) =>
                          setState(() => _biometricEnabled = v),
                    ),
                    _switchTile(
                      icon: Icons.verified_user_outlined,
                      iconBg: Colors.teal,
                      title: 'Two-Factor Auth',
                      subtitle: 'Extra login verification',
                      value: _twoFactorEnabled,
                      isDark: isDark,
                      onChanged: (v) =>
                          setState(() => _twoFactorEnabled = v),
                    ),
                  ]),

                  const SizedBox(height: 28),

                  // ═══════════════════════════════════════
                  // PRIVACY
                  // ═══════════════════════════════════════
                  _sectionLabel('PRIVACY'),
                  const SizedBox(height: 10),
                  _buildGroup(isDark, [
                    _tile(
                      icon: Icons.visibility_off_outlined,
                      iconBg: Colors.indigo,
                      title: 'Data Privacy',
                      subtitle: 'Manage your data preferences',
                      isDark: isDark,
                      onTap: () {},
                    ),
                    _tile(
                      icon: Icons.cookie_outlined,
                      iconBg: Colors.orange,
                      title: 'Cookie Settings',
                      subtitle: 'Manage tracking preferences',
                      isDark: isDark,
                      onTap: () {},
                    ),
                  ]),

                  const SizedBox(height: 28),

                  // ═══════════════════════════════════════
                  // DANGER ZONE
                  // ═══════════════════════════════════════
                  _sectionLabel('DANGER ZONE'),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.15),
                        width: 1.5,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _deleteAccount,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.error
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                    Icons.delete_forever,
                                    color: AppColors.error,
                                    size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Delete Account',
                                      style: TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.error,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Permanently remove all your data',
                                      style: TextStyle(
                                        fontFamily: 'Manrope',
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.white54
                                            : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  color: AppColors.error
                                      .withValues(alpha: 0.5),
                                  size: 22),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  Center(
                    child: Text(
                      _appVersion,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white38
                            : const Color(0xFF94A3B8),
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

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            letterSpacing: 1.5,
          ),
        ),
      );

  Widget _buildGroup(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((entry) {
          final idx = entry.key;
          return Column(
            children: [
              entry.value,
              if (idx < children.length - 1)
                Divider(
                  height: 0.5,
                  indent: 64,
                  color: isDark
                      ? Colors.white10
                      : const Color(0xFFF1F5F9),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required Color iconBg,
    required String title,
    String? subtitle,
    required bool isDark,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconBg, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1C1D),
                        )),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF64748B),
                          )),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  color: isDark
                      ? Colors.white24
                      : const Color(0xFFC5C5D8),
                  size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color iconBg,
    required String title,
    String? subtitle,
    required bool value,
    required bool isDark,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconBg, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1A1C1D),
                    )),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF64748B),
                      )),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeColor: AppColors.primary,
            onChanged: (v) {
              HapticFeedback.lightImpact();
              onChanged(v);
            },
          ),
        ],
      ),
    );
  }
}
