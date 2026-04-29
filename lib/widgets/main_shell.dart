import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../presentation/map/dashboard_map_screen.dart';
import '../presentation/search/search_parking_screen.dart';
import '../presentation/booking/my_bookings_screen.dart';
import '../presentation/messages/messages_screen.dart';
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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _conversationSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notificationSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _inboxSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _supportChatSub;
  int _conversationUnread = 0;
  int _notificationUnread = 0;
  int _inboxUnread = 0;
  int _supportChatUnread = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens = [
      DashboardMapScreen(onTabSwitch: _selectTab),
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

    _conversationSub = FirebaseFirestore.instance
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
          _conversationUnread = count;
          _updateUnreadCount();
        });

    _notificationSub = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          _notificationUnread = snapshot.docs.length;
          _updateUnreadCount();
        });

    _inboxSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          _inboxUnread = snapshot.docs.length;
          _updateUnreadCount();
        });

    _supportChatSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('support_chats')
        .snapshots()
        .listen((snapshot) {
          var count = 0;
          for (final doc in snapshot.docs) {
            count += (doc.data()['unreadCount'] as num?)?.toInt() ?? 0;
          }
          _supportChatUnread = count;
          _updateUnreadCount();
        });
  }

  void _updateUnreadCount() {
    if (!mounted) return;
    setState(() {
      _unreadCount =
          _conversationUnread +
          _notificationUnread +
          _inboxUnread +
          _supportChatUnread;
    });
  }

  @override
  void dispose() {
    _conversationSub?.cancel();
    _notificationSub?.cancel();
    _inboxSub?.cancel();
    _supportChatSub?.cancel();
    super.dispose();
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
    const destinations = <_ShellDestination>[
      _ShellDestination(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
      _ShellDestination(
        label: 'Map',
        icon: Icons.map_outlined,
        selectedIcon: Icons.map_rounded,
      ),
      _ShellDestination(
        label: 'Bookings',
        icon: Icons.confirmation_number_outlined,
        selectedIcon: Icons.confirmation_number,
      ),
      _ShellDestination(
        label: 'Messages',
        icon: Icons.chat_bubble_outline_rounded,
        selectedIcon: Icons.chat_bubble_rounded,
      ),
      _ShellDestination(
        label: 'Profile',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(destinations.length, (index) {
              final destination = destinations[index];
              return _NavBarItem(
                label: destination.label,
                icon: _currentIndex == index
                    ? destination.selectedIcon
                    : destination.icon,
                isSelected: _currentIndex == index,
                unreadCount: index == 3 ? _unreadCount : 0,
                onTap: () => _selectTab(index),
              );
            }),
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
    final color = isSelected ? AppColors.primary : const Color(0xFF444655);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 24),
                if (unreadCount > 0)
                  Positioned(
                    top: -7,
                    right: -12,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFBA1A1A),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ] else
              const SizedBox(height: 8),
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
