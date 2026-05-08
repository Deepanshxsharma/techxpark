import 'dart:async';
import 'dart:ui';

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

  // Tab screens are created lazily. This avoids initializing the native
  // GoogleMap view while the Map tab is still hidden in the IndexedStack.
  late final List<Widget?> _screens;

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
      null,
      null,
      null,
      null,
    ];
    _screenFor(_currentIndex);
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
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(
          _screens.length,
          (index) => index == _currentIndex || _screens[index] != null
              ? _screenFor(index)
              : const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(context),
    );
  }

  Widget _screenFor(int index) {
    final existing = _screens[index];
    if (existing != null) return existing;

    final screen = switch (index) {
      1 => SearchParkingScreen(onBack: () => _selectTab(0)),
      2 => const MyBookingsScreen(),
      3 => const MessagesScreen(),
      4 => ProfileScreen(onTabSwitch: _selectTab),
      _ => DashboardMapScreen(onTabSwitch: _selectTab),
    };
    _screens[index] = screen;
    return screen;
  }

  void _selectTab(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  Widget _buildBottomNavBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    const destinations = <_ShellDestination>[
      _ShellDestination(
        label: 'Home',
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
      ),
      _ShellDestination(
        label: 'Map',
        icon: Icons.explore_outlined,
        selectedIcon: Icons.explore_rounded,
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

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F1729).withValues(alpha: 0.92)
                : Colors.white.withValues(alpha: 0.88),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.4)
                    : AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 40,
                spreadRadius: -4,
                offset: const Offset(0, -8),
              ),
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(destinations.length, (index) {
                  final destination = destinations[index];
                  return _NavBarItem(
                    label: destination.label,
                    icon: destination.icon,
                    selectedIcon: destination.selectedIcon,
                    isSelected: _currentIndex == index,
                    isDark: isDark,
                    unreadCount: index == 3 ? _unreadCount : 0,
                    onTap: () => _selectTab(index),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*  PREMIUM NAV BAR ITEM WITH ANIMATIONS                                       */
/* -------------------------------------------------------------------------- */
class _NavBarItem extends StatefulWidget {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool isSelected;
  final bool isDark;
  final int unreadCount;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.isSelected,
    required this.isDark,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.6,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onTap();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isDark
        ? AppColors.primaryLight
        : AppColors.primary;
    final inactiveColor = widget.isDark
        ? const Color(0xFF64748B)
        : const Color(0xFF94A3B8);

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(opacity: _fadeAnimation.value, child: child),
        ),
        child: TweenAnimationBuilder<double>(
          tween: Tween(
            begin: widget.isSelected ? 0.0 : 1.0,
            end: widget.isSelected ? 1.0 : 0.0,
          ),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          builder: (context, progress, child) {
            final iconColor = Color.lerp(inactiveColor, activeColor, progress)!;
            final labelColor = Color.lerp(
              inactiveColor,
              widget.isDark ? Colors.white : const Color(0xFF1E293B),
              progress,
            )!;

            return SizedBox(
              width: 64,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Pill background + Icon ──
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.isSelected ? 16 : 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: widget.isSelected
                          ? activeColor.withValues(
                              alpha: widget.isDark ? 0.15 : 0.1,
                            )
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Glow behind active icon
                        if (widget.isSelected)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: activeColor.withValues(
                                      alpha: 0.25 * progress,
                                    ),
                                    blurRadius: 16,
                                    spreadRadius: -2,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Icon with smooth switch
                        Icon(
                          widget.isSelected ? widget.selectedIcon : widget.icon,
                          color: iconColor,
                          size: 22 + (progress * 2), // subtle size bump
                        ),
                        // Unread badge
                        if (widget.unreadCount > 0)
                          Positioned(
                            top: -6,
                            right: -10,
                            child: _UnreadBadge(
                              count: widget.unreadCount,
                              isDark: widget.isDark,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  // ── Label ──
                  Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: labelColor,
                      fontSize: 10,
                      fontWeight: widget.isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                      letterSpacing: 0.2,
                      height: 1.2,
                    ),
                  ),
                  // ── Active dot indicator ──
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.only(top: 4),
                    width: widget.isSelected ? 5 : 0,
                    height: widget.isSelected ? 5 : 0,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          activeColor,
                          activeColor.withValues(alpha: 0.6),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: widget.isSelected
                          ? [
                              BoxShadow(
                                color: activeColor.withValues(alpha: 0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/*  PREMIUM UNREAD BADGE WITH PULSE GLOW                                       */
/* -------------------------------------------------------------------------- */
class _UnreadBadge extends StatefulWidget {
  final int count;
  final bool isDark;

  const _UnreadBadge({required this.count, required this.isDark});

  @override
  State<_UnreadBadge> createState() => _UnreadBadgeState();
}

class _UnreadBadgeState extends State<_UnreadBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseValue = _pulseController.value;
        return Container(
          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFFEF4444,
                ).withValues(alpha: 0.3 + (pulseValue * 0.2)),
                blurRadius: 6 + (pulseValue * 4),
                spreadRadius: pulseValue * 1.5,
              ),
            ],
          ),
          child: Text(
            widget.count > 99 ? '99+' : '${widget.count}',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        );
      },
    );
  }
}

/* -------------------------------------------------------------------------- */
/*  SHELL DESTINATION MODEL                                                    */
/* -------------------------------------------------------------------------- */
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
