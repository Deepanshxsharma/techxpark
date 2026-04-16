import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import 'package:google_fonts/google_fonts.dart';

import '../presentation/home/home_screen.dart';
import '../presentation/profile/saved_parkings_screen.dart';
import '../presentation/booking/my_bookings_screen.dart';
import '../presentation/profile/wallet_screen.dart';
import '../presentation/profile/profile_screen.dart';
import '../theme/app_colors.dart';

/// Main app shell with persistent bottom navigation bar.
/// Uses IndexedStack so tab screens stay alive and never rebuild
/// when switching tabs — zero animation, zero splash replay.
class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  // All tab screens — created ONCE, never rebuilt on tab switch
  late final List<Widget> _screens;

  // Unread messages count
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens = [
      HomeScreen(onTabSelected: _selectTab),
      const SavedParkingsScreen(),
      const MyBookingsScreen(),
      const WalletScreen(),
      const ProfileScreen(),
    ];
    _listenUnreadMessages();
  }

  void _listenUnreadMessages() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .snapshots()
        .listen((snapshot) {
          int count = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            final unreadMap =
                data['unreadCount'] as Map<String, dynamic>? ?? {};
            final unread = (unreadMap[uid] as num?)?.toInt() ?? 0;
            count += unread;
          }
          if (mounted) setState(() => _unreadCount = count);
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  void _selectTab(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    const destinations = <_ShellDestination>[
      _ShellDestination(
        label: 'Explore',
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore_rounded,
      ),
      _ShellDestination(
        label: 'Saved',
        icon: Icons.bookmark_border_rounded,
        selectedIcon: Icons.bookmark_rounded,
      ),
      _ShellDestination(
        label: 'Activity',
        icon: Icons.local_activity_outlined,
        selectedIcon: Icons.local_activity_rounded,
      ),
      _ShellDestination(
        label: 'Wallet',
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet_rounded,
      ),
      _ShellDestination(
        label: 'Profile',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
      ),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 72 + bottomInset,
            padding: EdgeInsets.fromLTRB(14, 8, 14, 8 + bottomInset),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: Row(
              children: List.generate(destinations.length, (index) {
                final destination = destinations[index];
                return Expanded(
                  child: _NavBarItem(
                    label: destination.label,
                    icon: _currentIndex == index
                        ? destination.selectedIcon
                        : destination.icon,
                    isSelected: _currentIndex == index,
                    unreadCount: destination.label == 'Messages'
                        ? _unreadCount
                        : 0,
                    onTap: () => _selectTab(index),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final int unreadCount;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : AppColors.textTertiaryLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 24),
                    const SizedBox(height: 6),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: isSelected ? 1 : 0,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -6,
                    right: -11,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5393B),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellDestination {
  final String label;
  final IconData icon;
  final IconData selectedIcon;

  const _ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
}
