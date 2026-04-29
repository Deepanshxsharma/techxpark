import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../search/search_parking_screen.dart';
import 'indoor_navigation_screen.dart';
import 'parking_ticket_screen.dart';
import 'parking_timer_screen.dart';
import 'rating_bottom_sheet.dart';

// =============================================================================
//  MY BOOKINGS SCREEN — Premium Tabbed Booking Dashboard
// =============================================================================

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  int _activeTabIndex = 0;

  static const List<String> _tabLabels = ['Active', 'Upcoming', 'Past'];

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please login again')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // bg-slate-50
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Sticky Header ──────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: const Color(0xFFF8FAFC), // bg-slate-50
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1.0),
              child: Container(
                color: const Color(0xFFDBEAFE), // border-blue-100
                height: 1.0,
              ),
            ),
            automaticallyImplyLeading: false,
            title: const Text(
              'My Bookings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A), // text-slate-900
              ),
            ),
            centerTitle: false,
            actions: [
              IconButton(
                icon: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.filter_list_rounded,
                    size: 24,
                    color: AppColors.primary,
                  ), // text-blue-600
                ),
                onPressed: () => HapticFeedback.selectionClick(),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ── Segmented Tab Bar ──────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _buildSegmentedControl(),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 24)),

          // ── Content ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _BookingsContent(
              userId: user.uid,
              activeTabIndex: _activeTabIndex,
              onFindParking: _openSearch,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SEGMENTED CONTROL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSegmentedControl() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(
          0xFFE2E8F0,
        ).withValues(alpha: 0.5), // bg-slate-200/50
        borderRadius: BorderRadius.circular(16), // rounded-2xl
      ),
      child: Row(
        children: List.generate(_tabLabels.length, (index) {
          final isSelected = _activeTabIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _activeTabIndex = index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10), // py-2.5
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12), // rounded-xl
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ), // shadow-sm
                        ]
                      : const [],
                ),
                child: Center(
                  child: Text(
                    _tabLabels[index],
                    style: TextStyle(
                      fontSize: 14, // text-sm
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500, // font-semibold / font-medium
                      color: isSelected
                          ? AppColors
                                .primary // text-blue-600
                          : const Color(0xFF64748B), // text-slate-500
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SearchParkingScreen()),
    );
  }
}

// =============================================================================
//  BOOKINGS CONTENT — StreamBuilder with tab filtering
// =============================================================================

class _BookingsContent extends StatelessWidget {
  final String userId;
  final int activeTabIndex;
  final VoidCallback onFindParking;

  const _BookingsContent({
    required this.userId,
    required this.activeTabIndex,
    required this.onFindParking,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState();
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildLoadingState();
        }

        final docs = snapshot.data?.docs ?? [];
        final allBookings = docs.map((doc) {
          final data = doc.data();
          data['_docId'] = doc.id;
          return data;
        }).toList();

        // Categorize bookings
        final now = DateTime.now();
        final active = <Map<String, dynamic>>[];
        final upcoming = <Map<String, dynamic>>[];
        final past = <Map<String, dynamic>>[];

        for (final b in allBookings) {
          final status = (b['status'] ?? '').toString().toLowerCase();
          final start = _toDateTime(b['startTime'] ?? b['start_ts']);
          final end = _toDateTime(b['endTime'] ?? b['end_ts']);

          if (status == 'cancelled') {
            past.add(b);
          } else if (end != null && now.isAfter(end)) {
            past.add(b);
          } else if (start != null && now.isBefore(start)) {
            upcoming.add(b);
          } else {
            active.add(b);
          }
        }

        // Sort each list (latest first)
        void sortByStart(List<Map<String, dynamic>> list) {
          list.sort((a, b) {
            final t1 = _toDateTime(a['startTime'] ?? a['start_ts']);
            final t2 = _toDateTime(b['startTime'] ?? b['start_ts']);
            if (t1 == null || t2 == null) return 0;
            return t2.compareTo(t1);
          });
        }

        sortByStart(active);
        sortByStart(upcoming);
        sortByStart(past);

        final List<Map<String, dynamic>> currentList;
        switch (activeTabIndex) {
          case 0:
            currentList = active;
            break;
          case 1:
            currentList = upcoming;
            break;
          case 2:
            currentList = past;
            break;
          default:
            currentList = active;
        }

        if (currentList.isEmpty) {
          return _buildEmptyState(context);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show featured active card for Active tab
              if (activeTabIndex == 0 && currentList.isNotEmpty) ...[
                _ActiveBookingCard(booking: currentList.first),
                if (currentList.length > 1) ...[
                  const SizedBox(height: 28),
                  const Text(
                    'OTHER ACTIVE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...currentList
                      .skip(1)
                      .map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CompactBookingCard(booking: b),
                        ),
                      ),
                ],
              ],

              // Upcoming tab
              if (activeTabIndex == 1)
                ...currentList.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CompactBookingCard(booking: b, isUpcoming: true),
                  ),
                ),

              // Past tab
              if (activeTabIndex == 2) ...[
                const Text(
                  'RECENT ACTIVITY',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                ...currentList.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PastBookingCard(booking: b),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final String title;
    final String subtitle;
    final IconData icon;

    switch (activeTabIndex) {
      case 0:
        title = 'No Active Booking';
        subtitle = 'Find a parking spot and start your session.';
        icon = Icons.local_parking_rounded;
        break;
      case 1:
        title = 'No Upcoming Bookings';
        subtitle = 'Plan ahead by booking a parking slot.';
        icon = Icons.event_available_rounded;
        break;
      case 2:
        title = 'No Booking History';
        subtitle = 'Your past bookings will appear here.';
        icon = Icons.history_rounded;
        break;
      default:
        title = 'No Bookings';
        subtitle = 'Start by finding a parking spot.';
        icon = Icons.local_parking_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(icon, size: 36, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          if (activeTabIndex == 0) ...[
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: onFindParking,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Find Parking',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2.5,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            SizedBox(height: 16),
            Text(
              'Unable to load bookings',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimaryLight,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Please check your connection and try again.',
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

// =============================================================================
//  ACTIVE BOOKING CARD — Featured card with live timer
// =============================================================================

class _ActiveBookingCard extends StatefulWidget {
  final Map<String, dynamic> booking;
  const _ActiveBookingCard({required this.booking});

  @override
  State<_ActiveBookingCard> createState() => _ActiveBookingCardState();
}

class _ActiveBookingCardState extends State<_ActiveBookingCard> {
  late Timer _timer;
  Duration _remaining = Duration.zero;

  Map<String, dynamic> get b => widget.booking;

  DateTime get _start =>
      _BookingsContent._toDateTime(b['startTime'] ?? b['start_ts']) ??
      DateTime.now();
  DateTime get _end =>
      _BookingsContent._toDateTime(b['endTime'] ?? b['end_ts']) ??
      DateTime.now();
  String get _bookingId => b['_docId'] ?? '';
  String get _parkingName =>
      b['parkingName'] ?? b['parking_name'] ?? 'Parking Location';
  String get _location => b['location'] ?? b['address'] ?? '';
  String get _slot => b['slotId'] ?? b['slot_id'] ?? '--';
  int get _floorIndex => (b['floor'] as num?)?.toInt() ?? 0;
  String get _parkingImage => b['parkingImage'] ?? b['image'] ?? '';
  String get _parkingId => b['parkingId'] ?? b['parking_id'] ?? '';
  Map<String, dynamic> get _vehicle =>
      (b['vehicle'] is Map) ? b['vehicle'] as Map<String, dynamic> : {};

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateRemaining();
    });
  }

  void _updateRemaining() {
    final diff = _end.difference(DateTime.now());
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hh = _remaining.inHours.toString().padLeft(2, '0');
    final mm = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFEFF6FF), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.05),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Image Section ──────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                SizedBox(
                  height: 220,
                  width: double.infinity,
                  child: _SmartImage(
                    url: _parkingImage,
                    fallbackName: _parkingName,
                    parkingId: _parkingId,
                  ),
                ),
                // Status Badge
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary, // blue-600
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'ACTIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Info Section ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Title Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _parkingName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Color(0xFF64748B),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _location.isNotEmpty
                                      ? _location
                                      : 'Parking Location',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'SLOT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _slot,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Timer section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFF1F5F9),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDBEAFE),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.schedule,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'TIME REMAINING',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              Text(
                                '$hh:$mm:$ss',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: -0.5,
                                  fontFamily: 'monospace',
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.hourglass_empty,
                        color: Color(0xFFBFDBFE),
                        size: 32,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _navigateTo(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.directions,
                                color: AppColors.primary,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Navigate',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _extendTime(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFBFDBFE,
                                ).withValues(alpha: 0.5),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.more_time,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Extend Time',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IndoorNavigationScreen(
          parkingId: _parkingId,
          parkingName: _parkingName,
          bookedSlotId: _slot,
          bookedFloor: _floorIndex,
        ),
      ),
    );
  }

  void _extendTime(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParkingTimerScreen(
          bookingId: _bookingId,
          parking: {'name': _parkingName},
          slot: _slot,
          floorIndex: _floorIndex,
          start: _start,
          end: _end,
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m}m';
  }
}

// =============================================================================
//  COMPACT BOOKING CARD — Used for secondary active / upcoming bookings
// =============================================================================

class _CompactBookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;
  final bool isUpcoming;

  const _CompactBookingCard({required this.booking, this.isUpcoming = false});

  @override
  Widget build(BuildContext context) {
    final parkingName =
        booking['parkingName'] ?? booking['parking_name'] ?? 'Parking Location';
    final slot = booking['slotId'] ?? booking['slot_id'] ?? '--';
    final floorIndex = (booking['floor'] as num?)?.toInt() ?? 0;
    final start =
        _BookingsContent._toDateTime(
          booking['startTime'] ?? booking['start_ts'],
        ) ??
        DateTime.now();
    final end =
        _BookingsContent._toDateTime(booking['endTime'] ?? booking['end_ts']) ??
        DateTime.now();
    final image = booking['parkingImage'] ?? booking['image'] ?? '';
    final bookingId = booking['_docId'] ?? '';
    final parkingId = booking['parkingId'] ?? booking['parking_id'] ?? '';
    final vehicle = (booking['vehicle'] is Map)
        ? booking['vehicle'] as Map<String, dynamic>
        : <String, dynamic>{};

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ParkingTicketScreen(
              parking: {
                'name': parkingName,
                'address': booking['address'] ?? booking['location'] ?? '',
                'latitude': booking['latitude'],
                'longitude': booking['longitude'],
              },
              slot: slot,
              floorIndex: floorIndex,
              start: start,
              end: end,
              vehicle: vehicle,
              bookingId: bookingId,
              parkingId: parkingId,
              status: isUpcoming ? 'upcoming' : 'active',
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 64,
                height: 64,
                child: _SmartImage(url: image, fallbackName: parkingName),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          parkingName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isUpcoming
                              ? const Color(0xFFFFF7ED)
                              : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isUpcoming ? 'Upcoming' : 'Active',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isUpcoming
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Floor ${floorIndex + 1} • Slot $slot',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('d MMM').format(start)} • ${DateFormat('HH:mm').format(start)} – ${DateFormat('HH:mm').format(end)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  PAST BOOKING CARD — Compact row with "Book Again" action
// =============================================================================

class _PastBookingCard extends StatelessWidget {
  final Map<String, dynamic> booking;

  const _PastBookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    final parkingName =
        booking['parkingName'] ?? booking['parking_name'] ?? 'Parking';
    final start =
        _BookingsContent._toDateTime(
          booking['startTime'] ?? booking['start_ts'],
        ) ??
        DateTime.now();
    final price = booking['price'] ?? booking['totalAmount'] ?? 0;
    final image = booking['parkingImage'] ?? booking['image'] ?? '';
    final status = (booking['status'] ?? '').toString().toLowerCase();
    final isCancelled = status == 'cancelled';
    final parkingId = booking['parkingId'] ?? booking['parking_id'] ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: _SmartImage(url: image, fallbackName: parkingName),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        parkingName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isCancelled
                            ? const Color(0xFFFEE2E2)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isCancelled ? 'Cancelled' : 'Completed',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isCancelled
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('d MMM').format(start)} • ${price is num && price > 0 ? '₹${price.toStringAsFixed(2)}' : 'FREE'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),
                if (!isCancelled && parkingId.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const SearchParkingScreen(),
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.subdirectory_arrow_right_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Book Again',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// _ActionButton removed as it's directly implemented

// =============================================================================
//  SMART IMAGE — Firebase URL with fallback
// =============================================================================

class _SmartImage extends StatelessWidget {
  final String url;
  final String fallbackName;
  final String? parkingId;

  const _SmartImage({
    required this.url,
    required this.fallbackName,
    this.parkingId,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'))) {
      return _buildImage(url);
    }

    // Fetch from Firebase if we have a parking ID but no direct URL
    if (parkingId != null && parkingId!.isNotEmpty) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('parking_locations')
            .doc(parkingId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final realUrl = data['imageUrl'] ?? data['image'] as String?;
            if (realUrl != null &&
                realUrl.isNotEmpty &&
                (realUrl.startsWith('http://') ||
                    realUrl.startsWith('https://'))) {
              return _buildImage(realUrl);
            }
          }
          return _fallbackWidget();
        },
      );
    }

    return _fallbackWidget();
  }

  Widget _buildImage(String validUrl) {
    return Image.network(
      validUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => _fallbackWidget(),
    );
  }

  Widget _fallbackWidget() {
    // Generate a consistent color from the name
    final hue = (fallbackName.hashCode % 360).abs().toDouble();
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSLColor.fromAHSL(1.0, hue, 0.4, 0.55).toColor(),
            HSLColor.fromAHSL(1.0, (hue + 40) % 360, 0.5, 0.45).toColor(),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.local_parking_rounded,
          color: Colors.white.withValues(alpha: 0.5),
          size: 32,
        ),
      ),
    );
  }
}
