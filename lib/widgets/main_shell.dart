import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../presentation/map/dashboard_map_screen.dart';
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
    _screens = const [
      DashboardMapScreen(),
      SearchParkingScreen(),
      MyBookingsScreen(),
      MessagesScreen(),
      ProfileScreen(),
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
        final unreadMap = data['unreadCount'] as Map<String, dynamic>? ?? {};
        final unread = (unreadMap[uid] as num?)?.toInt() ?? 0;
        count += unread;
      }
      if (mounted) setState(() => _unreadCount = count);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE8ECF4), width: 1),
        ),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2845D6),
              );
            }
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF94A3B8),
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                color: Color(0xFF2845D6),
                size: 24,
              );
            }
            return const IconThemeData(
              color: Color(0xFF94A3B8),
              size: 24,
            );
          }),
        ),
        child: NavigationBar(
          height: 65,
          backgroundColor: Colors.white,
          elevation: 0,
          indicatorColor: const Color(0xFF2845D6).withValues(alpha: 0.1),
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            if (_currentIndex != index) {
              HapticFeedback.selectionClick();
              setState(() {
                _currentIndex = index;
              });
            }
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: "Home",
            ),
            const NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search),
              label: "Search",
            ),
            const NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today),
              label: "Bookings",
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _unreadCount > 0,
                label: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                backgroundColor: const Color(0xFFE5393B),
                child: const Icon(Icons.chat_bubble_outline),
              ),
              selectedIcon: Badge(
                isLabelVisible: _unreadCount > 0,
                label: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                backgroundColor: const Color(0xFFE5393B),
                child: const Icon(Icons.chat_bubble),
              ),
              label: "Messages",
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}

