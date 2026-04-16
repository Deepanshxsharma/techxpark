import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';

import '../presentation/home/home_screen.dart';
import '../presentation/search/search_parking_screen.dart';
import '../presentation/booking/my_bookings_screen.dart';
import '../presentation/messages/messages_screen.dart';
import '../presentation/profile/profile_screen.dart';

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
      const SearchParkingScreen(),
      const MyBookingsScreen(),
      const MessagesScreen(),
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
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
      _ShellDestination(
        label: 'Search',
        icon: Icons.search_rounded,
        selectedIcon: Icons.search_rounded,
      ),
      _ShellDestination(
        label: 'Bookings',
        icon: Icons.confirmation_number_outlined,
        selectedIcon: Icons.confirmation_number_rounded,
      ),
      _ShellDestination(
        label: 'Messages',
        icon: Icons.chat_bubble_outline_rounded,
        selectedIcon: Icons.chat_bubble_rounded,
      ),
      _ShellDestination(
        label: 'Profile',
        icon: Icons.person_outline_rounded,
        selectedIcon: Icons.person_rounded,
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottomInset),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 24,
                  offset: const Offset(0, -10),
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
    final color = isSelected
        ? const Color(0xFF0029B9)
        : const Color(0xFF444655);

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
                Icon(icon, color: color, size: 24),
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
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: isSelected ? 1 : 0,
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: Color(0xFF0029B9),
                  shape: BoxShape.circle,
                ),
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
