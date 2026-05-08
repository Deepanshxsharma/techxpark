import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/booking_status_helper.dart';
import '../../services/parking_filter_service.dart';
import '../../theme/app_colors.dart';

import '../booking/my_bookings_screen.dart';
import '../booking/parking_ticket_screen.dart';
import '../booking/parking_timer_screen.dart';
import '../notifications/notifications_screen.dart';
import '../parking_details/lot_detail_navigation.dart';
import '../search/search_parking_screen.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int> onTabSelected;

  const HomeScreen({super.key, required this.onTabSelected});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<String> _filters = <String>[
    'All Lots',
    'EV Charging',
    'Covered Parking',
    '24/7',
    'Budget',
  ];

  int _selectedFilterIndex = 0;
  String _currentLocationText = 'Fetching location...';
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _currentLocationText = 'Locating...';
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!mounted) return;
        setState(() {
          _currentLocation = null;
          _currentLocationText = 'GPS Disabled';
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _currentLocation = null;
          _currentLocationText = 'Permission Denied';
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _currentLocation = null;
          _currentLocationText = 'Location Blocked';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _currentLocationText = 'Locating...';
      });

      // Reverse geocode to get a human-readable place name
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty && mounted) {
          final p = placemarks.first;
          // Build a short, recognizable name like "Connaught Place, New Delhi"
          final parts = <String>[
            if (p.subLocality != null && p.subLocality!.isNotEmpty)
              p.subLocality!,
            if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
          ];
          final locationName = parts.isNotEmpty
              ? parts.join(', ')
              : p.name ??
                    '${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}';
          setState(() => _currentLocationText = locationName);
        }
      } catch (_) {
        // Keep coordinates as fallback
        if (mounted) {
          setState(() {
            _currentLocationText =
                '${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}';
          });
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentLocation = null;
        _currentLocationText = 'Location Unavailable';
      });
    }
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchParkingScreen(userLocation: _currentLocation),
      ),
    );
  }

  void _openBookings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MyBookingsScreen()));
  }

  void _openBookingDetails(_HomeBooking booking) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ParkingTicketScreen(
          parking: booking.toParkingPayload(),
          slot: booking.slotNumber,
          floorIndex: booking.floorIndex,
          start: booking.start,
          end: booking.end,
          vehicle: booking.vehicle,
          bookingId: booking.bookingId,
          parkingId: booking.parkingId,
          status: booking.status,
        ),
      ),
    );
  }

  void _openExtendBooking(_HomeBooking booking) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ParkingTimerScreen(
          bookingId: booking.bookingId,
          parking: booking.toParkingPayload(),
          slot: booking.slotNumber,
          floorIndex: booking.floorIndex,
          start: booking.start,
          end: booking.end,
        ),
      ),
    );
  }

  void _openParkingDetails(_HomeParkingLot parking, String collectionName) {
    openLotDetail(
      context,
      parking.id,
      parking.toRouteMap(_currentLocation),
      collectionName: collectionName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in')));
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.bgLight,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 100),
                    child: _buildCinematicHeader(user.uid),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 0,
                    child: _buildFloatingSearchBar(),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(child: _buildFilters()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
            SliverToBoxAdapter(
              child: _ActiveBookingSection(
                userId: user.uid,
                onFindParking: _openSearch,
                onOpenDetails: _openBookingDetails,
                onExtendBooking: _openExtendBooking,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 36)),
            SliverToBoxAdapter(
              child: _NearbyParkingSection(
                selectedFilter: _filters[_selectedFilterIndex],
                userLocation: _currentLocation,
                onSearchTap: _openSearch,
                onParkingTap: _openParkingDetails,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Quick Actions',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF181C20), // on-background
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.electric_car_rounded,
                        iconColor: AppColors.primary,
                        bgColor: const Color(
                          0xFFF1F4F9,
                        ), // surface-container-low
                        title: 'Find EV',
                        subtitle: '12 nearby stations',
                        onTap: _openSearch,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.history_rounded,
                        iconColor: AppColors.primary, // secondary
                        bgColor: const Color(
                          0xFFF1F4F9,
                        ), // surface-container-low
                        title: 'Recents',
                        subtitle: '3 spots visited',
                        onTap: _openBookings,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildCinematicHeader(String uid) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(32, topPadding + 32, 32, 80),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(48)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary, // primary
            AppColors.primaryLight, // primary-container
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F0830C6), // rgba(8,48,198,0.06)
            blurRadius: 40,
            offset: Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Location Pill + Notification
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Location Pill
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _fetchCurrentLocation();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _currentLocationText,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              // Notification
              _NotificationButton(uid: uid, onTap: _openNotifications),
            ],
          ),
          const SizedBox(height: 40),
          // Hero Text
          Text(
            'TechXPark',
            style: GoogleFonts.poppins(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 18,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
              children: const [
                TextSpan(text: 'Find Parking,\n'),
                TextSpan(
                  text: 'Park Smarter.',
                  style: TextStyle(color: Color(0xFFBAC3FF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingSearchBar() {
    return GestureDetector(
      onTap: _openSearch,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white, // surface-container-lowest
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.search_rounded,
              color: Color(0xFF757686), // outline
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Search destinations or lots...',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF757686),
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.tune_rounded, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: List<Widget>.generate(_filters.length, (int index) {
          final selected = _selectedFilterIndex == index;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFilterIndex = index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary
                      : const Color(0xFFE6E8ED), // surface-container-high
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : [],
                ),
                child: Text(
                  _filters[index],
                  style: GoogleFonts.poppins(
                    color: selected
                        ? Colors.white
                        : const Color(0xFF444655), // on-surface-variant
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ActiveBookingSection extends StatelessWidget {
  final String userId;
  final VoidCallback onFindParking;
  final ValueChanged<_HomeBooking> onOpenDetails;
  final ValueChanged<_HomeBooking> onExtendBooking;

  const _ActiveBookingSection({
    required this.userId,
    required this.onFindParking,
    required this.onOpenDetails,
    required this.onExtendBooking,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('[HomeTicket] BUILD CALLED for userId=$userId');
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        debugPrint(
          '[HomeTicket] userId=$userId '
          'connState=${snapshot.connectionState} '
          'hasData=${snapshot.hasData} '
          'hasError=${snapshot.hasError} '
          'docCount=${snapshot.data?.docs.length ?? 0}',
        );
        if (snapshot.hasError) {
          debugPrint('[HomeTicket] ERROR: ${snapshot.error}');
        }

        final booking = _resolveActiveBooking(snapshot.data?.docs ?? const []);
        debugPrint(
          '[HomeTicket] Resolved booking: ${booking?.bookingId ?? 'NONE'}',
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SectionHeading(
                title: 'Active Parking Ticket',
                subtitle: booking == null
                    ? 'Your live session will appear here'
                    : booking.start.isAfter(DateTime.now())
                    ? 'Upcoming session starts soon'
                    : 'Currently tracked session in progress',
                actionLabel: booking == null ? 'Find Parking' : 'Details',
                onActionTap: booking == null
                    ? onFindParking
                    : () => onOpenDetails(booking),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeOut,
                child: _buildCard(snapshot, booking),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCard(
    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
    _HomeBooking? booking,
  ) {
    if (snapshot.hasError) {
      return _InfoStateCard(
        key: const ValueKey<String>('active-booking-error'),
        icon: Icons.error_outline_rounded,
        title: 'Unable to load active booking',
        subtitle: 'Please try again in a moment.',
        buttonLabel: 'Find Parking',
        onPressed: onFindParking,
      );
    }

    if (snapshot.connectionState == ConnectionState.waiting &&
        !snapshot.hasData) {
      return const _LoadingTicketCard(
        key: ValueKey<String>('active-booking-loading'),
      );
    }

    if (booking == null) {
      return _EmptyTicketCard(
        key: const ValueKey<String>('active-booking-empty'),
        onPrimaryTap: onFindParking,
      );
    }

    return _ActiveTicketCard(
      key: ValueKey<String>(booking.bookingId),
      booking: booking,
      onDetailsTap: () => onOpenDetails(booking),
      onPrimaryTap: () => onExtendBooking(booking),
    );
  }
}

class _NearbyParkingSection extends StatefulWidget {
  final String selectedFilter;
  final LatLng? userLocation;
  final VoidCallback onSearchTap;
  final void Function(_HomeParkingLot parking, String collectionName)
  onParkingTap;

  const _NearbyParkingSection({
    required this.selectedFilter,
    required this.userLocation,
    required this.onSearchTap,
    required this.onParkingTap,
  });

  @override
  State<_NearbyParkingSection> createState() => _NearbyParkingSectionState();
}

class _NearbyParkingSectionState extends State<_NearbyParkingSection> {
  late final Future<String> _collectionNameFuture;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _collectionNameFuture = _resolveParkingCollectionName();
    _pageController = PageController(viewportFraction: 0.86);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _collectionNameFuture,
      builder: (context, collectionSnapshot) {
        final collectionName = collectionSnapshot.data ?? 'parking_locations';

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SectionHeading(
                title: 'Nearby Lots',
                subtitle: widget.userLocation == null
                    ? 'Showing available lots in default order'
                    : 'Sorted by distance from your current location',
                actionLabel: 'View All',
                onActionTap: widget.onSearchTap,
              ),
              const SizedBox(height: 16),
              if (!collectionSnapshot.hasData &&
                  collectionSnapshot.connectionState == ConnectionState.waiting)
                const _NearbyParkingLoadingCard()
              else
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: ParkingFilterService.streamParking(
                    widget.selectedFilter,
                    collectionName: collectionName,
                  ),
                  builder: (context, snapshot) {
                    debugPrint(
                      'TOTAL DOCS: ${snapshot.data?.docs.length ?? 0}',
                    );
                    if (snapshot.hasError) {
                      return const _InfoStateCard(
                        icon: Icons.error_outline_rounded,
                        title: 'Unable to load nearby parking',
                        subtitle: 'Please check again shortly.',
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const _NearbyParkingLoadingCard();
                    }

                    final lots = _prepareParkingLots(
                      snapshot.data?.docs ?? const [],
                      widget.selectedFilter,
                      widget.userLocation,
                    );

                    if (lots.isEmpty) {
                      return _InfoStateCard(
                        icon: Icons.local_parking_outlined,
                        title: widget.selectedFilter == 'All Lots'
                            ? 'No parking available'
                            : 'No lots match this filter',
                        subtitle: widget.selectedFilter == 'All Lots'
                            ? 'Try again later or search a different area.'
                            : 'Try switching to another parking filter.',
                        buttonLabel: 'Find Parking',
                        onPressed: widget.onSearchTap,
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          height: 284,
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: lots.length,
                            pageSnapping: true,
                            physics: const BouncingScrollPhysics(),
                            itemBuilder: (context, index) {
                              final parking = lots[index];
                              return Padding(
                                padding: EdgeInsets.only(
                                  right: index == lots.length - 1 ? 0 : 16,
                                ),
                                child: _NearbyParkingCard(
                                  parking: parking,
                                  userLocation: widget.userLocation,
                                  isRecommended: index == 0,
                                  onTap: () => widget.onParkingTap(
                                    parking,
                                    collectionName,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        if (widget.userLocation == null) ...<Widget>[
                          const SizedBox(height: 12),
                          const Row(
                            children: <Widget>[
                              Icon(
                                Icons.location_off_rounded,
                                size: 14,
                                color: Color(0xFF94A3B8),
                              ),
                              SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Location unavailable, so cards are shown in default order.',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onActionTap;

  const _SectionHeading({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF181C20), // on-background
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF444655), // on-surface-variant
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onActionTap,
          child: Text(
            actionLabel.toUpperCase(),
            style: GoogleFonts.poppins(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActiveTicketCard extends StatefulWidget {
  final _HomeBooking booking;
  final VoidCallback onDetailsTap;
  final VoidCallback onPrimaryTap;

  const _ActiveTicketCard({
    super.key,
    required this.booking,
    required this.onDetailsTap,
    required this.onPrimaryTap,
  });

  @override
  State<_ActiveTicketCard> createState() => _ActiveTicketCardState();
}

class _ActiveTicketCardState extends State<_ActiveTicketCard> {
  static const String _fallbackImage = 'assets/images/parking_placeholder.png';
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final isUpcoming = booking.start.isAfter(_now);
    final remaining = isUpcoming
        ? booking.start.difference(_now)
        : booking.remainingAt(_now);
    final progress = isUpcoming ? 0.0 : booking.progressAt(_now);
    final elapsed = booking.totalDuration - booking.remainingAt(_now);
    final vehicleName =
        booking.vehicle['model'] as String? ??
        booking.vehicle['name'] as String? ??
        '';
    final vehicleNumber =
        booking.vehicle['number'] as String? ??
        booking.vehicle['plate'] as String? ??
        '';

    return GestureDetector(
      onTap: widget.onDetailsTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 32,
              spreadRadius: 0,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 48,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: <Widget>[
              // ─── HERO IMAGE SECTION ───
              SizedBox(
                height: 280,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    // Background image
                    _SmartParkingImage(
                      imagePath: booking.imagePath,
                      fallbackAsset: _fallbackImage,
                      parkingId: booking.parkingId,
                    ),
                    // Dark gradient overlay
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.3, 0.7, 1.0],
                          colors: <Color>[
                            Colors.black.withValues(alpha: 0.3),
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.5),
                            Colors.black.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                    // Top row: Badge + Est. Cost
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          _BookingBadge(isUpcoming: isUpcoming),
                          // Glass cost pill
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: BackdropFilter(
                              filter: ui.ImageFilter.blur(
                                sigmaX: 20,
                                sigmaY: 20,
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Text(
                                      'SLOT',
                                      style: GoogleFonts.poppins(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      booking.slotNumber,
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
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
                    ),
                    // Bottom: Timer + Progress
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            isUpcoming ? 'Starts In' : 'Time Remaining',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatHumanDuration(remaining),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              letterSpacing: -1.5,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              shadows: <Shadow>[
                                Shadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 20,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Glowing progress bar
                          Container(
                            height: 6,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(99),
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            child: Stack(
                              children: [
                                FractionallySizedBox(
                                  widthFactor: progress.clamp(0.02, 1.0),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(99),
                                      gradient: LinearGradient(
                                        colors: isUpcoming
                                            ? [
                                                const Color(0xFFF59E0B),
                                                const Color(0xFFFBBF24),
                                              ]
                                            : [
                                                AppColors.primaryLight,
                                                const Color(0xFF60A5FA),
                                              ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color:
                                              (isUpcoming
                                                      ? const Color(0xFFF59E0B)
                                                      : AppColors.primary)
                                                  .withValues(alpha: 0.5),
                                          blurRadius: 12,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                'Started ${_formatDurationCompact(elapsed)} ago',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                'Total ${_formatDurationCompact(booking.totalDuration)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ─── DETAILS SECTION ───
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  children: <Widget>[
                    // Parking name + info row
                    Row(
                      children: <Widget>[
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.activeBlueLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                booking.parkingName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF181C20),
                                ),
                              ),
                              if (booking.address.isNotEmpty)
                                Text(
                                  booking.address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.directions_car_rounded,
                                size: 13,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'L${booking.floorDisplay}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Vehicle info row (if available)
                    if (vehicleName.isNotEmpty || vehicleNumber.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.electric_car_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  if (vehicleName.isNotEmpty)
                                    Text(
                                      vehicleName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF1E293B),
                                      ),
                                    ),
                                  if (vehicleNumber.isNotEmpty)
                                    Text(
                                      vehicleNumber.toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF64748B),
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Action buttons row
                    Row(
                      children: <Widget>[
                        // Navigate button
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.near_me_rounded,
                            label: 'Navigate',
                            color: AppColors.primary,
                            textColor: Colors.white,
                            onTap: widget.onDetailsTap,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Extend button
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.add_circle_outline_rounded,
                            label: 'Extend',
                            color: const Color(0xFF4955B3),
                            textColor: Colors.white,
                            onTap: widget.onPrimaryTap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // View Entry Pass button
                    SizedBox(
                      width: double.infinity,
                      child: _ActionButton(
                        icon: Icons.confirmation_number_outlined,
                        label: 'View Entry Pass',
                        color: const Color(0xFFF1F5F9),
                        textColor: const Color(0xFF334155),
                        iconColor: AppColors.primary,
                        onTap: widget.onDetailsTap,
                        hasBorder: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatHumanDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final hStr = h.toString().padLeft(1, '0');
    final mStr = m.toString().padLeft(2, '0');
    final sStr = s.toString().padLeft(2, '0');
    return '${hStr}h ${mStr}m ${sStr}s';
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final Color? iconColor;
  final VoidCallback onTap;
  final bool hasBorder;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
    this.iconColor,
    required this.onTap,
    this.hasBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: hasBorder
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 0.5,
                  ),
                )
              : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 18, color: iconColor ?? textColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTicketCard extends StatelessWidget {
  final VoidCallback onPrimaryTap;

  const _EmptyTicketCard({super.key, required this.onPrimaryTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: const Icon(
              Icons.local_parking_rounded,
              size: 40,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Active Parking',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Book a parking spot to get started',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPrimaryTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Find Parking',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingTicketCard extends StatelessWidget {
  const _LoadingTicketCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primaryDark),
      ),
    );
  }
}

class _BookingBadge extends StatelessWidget {
  final bool isUpcoming;

  const _BookingBadge({required this.isUpcoming});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isUpcoming
            ? const Color(0xFFF59E0B) // amber for upcoming
            : const Color(0xFFBA1A1A), // red for live
        borderRadius: BorderRadius.circular(999),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 6,
            height: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isUpcoming ? 'UPCOMING BOOKING' : 'LIVE BOOKING',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownPanel extends StatefulWidget {
  final _HomeBooking booking;

  const _CountdownPanel({required this.booking});

  @override
  State<_CountdownPanel> createState() => _CountdownPanelState();
}

class _CountdownPanelState extends State<_CountdownPanel> {
  Timer? _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUpcoming = widget.booking.start.isAfter(_now);
    final remaining = isUpcoming
        ? widget.booking.start.difference(_now)
        : widget.booking.remainingAt(_now);
    final progress = isUpcoming ? 0.0 : widget.booking.progressAt(_now);
    final elapsed =
        widget.booking.totalDuration - widget.booking.remainingAt(_now);

    return Column(
      children: <Widget>[
        Text(
          isUpcoming ? 'STARTS IN' : 'TIME REMAINING',
          style: GoogleFonts.poppins(
            color: const Color(0xFF444655), // on-surface-variant
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _formatDurationClock(remaining),
          style: GoogleFonts.poppins(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF181C20), // on-background
            letterSpacing: -1.5,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 24),
        Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: const Color(
                  0xFFF1F4F9,
                ), // surface-container-low
                color: isUpcoming ? const Color(0xFFF59E0B) : AppColors.primary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'ELAPSED: ${_formatDurationCompact(elapsed)}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF444655),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  'TOTAL: ${_formatDurationCompact(widget.booking.totalDuration)}',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: const Color(0xFF444655),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: const Color(0xFF181C20), // on-background
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF444655), // on-surface-variant
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  final String uid;
  final VoidCallback onTap;

  const _NotificationButton({required this.uid, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .snapshots(),
      builder: (context, snapshot) {
        final hasUnread = (snapshot.data?.docs.length ?? 0) > 0;

        return GestureDetector(
          onTap: onTap,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: <Widget>[
                const Icon(
                  Icons.notifications_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                if (hasUnread)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF772300), // tertiary
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NearbyParkingCard extends StatelessWidget {
  final _HomeParkingLot parking;
  final LatLng? userLocation;
  final bool isRecommended;
  final VoidCallback onTap;

  const _NearbyParkingCard({
    required this.parking,
    required this.userLocation,
    required this.isRecommended,
    required this.onTap,
  });

  static const String _fallbackImage = 'assets/images/parking_placeholder.png';

  @override
  Widget build(BuildContext context) {
    final distanceMeters = parking.distanceFrom(userLocation);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 320),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white, // surface-container-lowest
          borderRadius: BorderRadius.circular(24), // rounded-2xl
          border: Border.all(
            color: const Color(0xFFF1F4F9),
          ), // surface-container-low
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Image Box
            Container(
              height: 128, // h-32
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16), // rounded-xl
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _SmartParkingImage(
                      imagePath: parking.imagePath,
                      fallbackAsset: _fallbackImage,
                      parkingId: parking.id,
                    ),
                    // Distance Badge
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(
                            alpha: 0.9,
                          ), // glass-blur
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.near_me_rounded,
                              color: AppColors.primary,
                              size: 10,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              distanceMeters == null
                                  ? '--'
                                  : _formatDistance(distanceMeters),
                              style: GoogleFonts.poppins(
                                color: const Color(0xFF181C20), // on-background
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Recommended Badge
                    if (isRecommended)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary, // secondary
                            borderRadius: BorderRadius.circular(
                              4,
                            ), // rounded-sm
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            'RECOMMENDED',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    // Rating / Availability
                    Positioned(
                      bottom: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_parking_rounded,
                              color: Colors.amber,
                              size: 10,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${parking.availableSlots} SLOTS',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parking.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF181C20),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        parking.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF444655), // on-surface-variant
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 4, right: 2),
                          child: Text(
                            'from',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF444655),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '₹${parking.pricePerHour.toStringAsFixed(parking.pricePerHour % 1 == 0 ? 0 : 1)}',
                          style: GoogleFonts.poppins(
                            color: AppColors.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '/hr',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF444655),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Tags
            Row(
              children: [
                if (parking.hasEvCharging) _buildTag('EV Charging'),
                if (parking.isCovered) _buildTag('Covered'),
                if (parking.hasValet) _buildTag('Valet'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F9), // surface-container-low
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFECEEF3)), // surface-container
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          color: const Color(0xFF181C20), // on-surface
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NearbyParkingLoadingCard extends StatelessWidget {
  const _NearbyParkingLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 320),
      height: 252,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F4F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

class _InfoStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  const _InfoStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: AppColors.primaryLight),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              height: 1.4,
            ),
          ),
          if (buttonLabel != null && onPressed != null) ...<Widget>[
            const SizedBox(height: 22),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                buttonLabel!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmartParkingImage extends StatelessWidget {
  final String? imagePath;
  final String fallbackAsset;
  final String? parkingId;

  const _SmartParkingImage({
    required this.imagePath,
    required this.fallbackAsset,
    this.parkingId,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPath = _resolveAssetPath(imagePath);

    if (resolvedPath != null && resolvedPath.startsWith('http')) {
      return _buildNetworkImage(resolvedPath);
    }

    if (resolvedPath != null && resolvedPath.startsWith('assets/')) {
      return Image.asset(
        resolvedPath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildFallback(),
      );
    }

    if (parkingId != null && parkingId!.isNotEmpty) {
      return _ParkingImageResolver(
        parkingId: parkingId!,
        fallbackBuilder: _buildFallback,
        networkImageBuilder: _buildNetworkImage,
      );
    }

    return _buildFallback();
  }

  Widget _buildNetworkImage(String url) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Image.asset(fallbackAsset, fit: BoxFit.cover);
  }
}

/// Tries multiple Firestore collection names to find the parking image.
class _ParkingImageResolver extends StatefulWidget {
  final String parkingId;
  final Widget Function() fallbackBuilder;
  final Widget Function(String url) networkImageBuilder;

  const _ParkingImageResolver({
    required this.parkingId,
    required this.fallbackBuilder,
    required this.networkImageBuilder,
  });

  @override
  State<_ParkingImageResolver> createState() => _ParkingImageResolverState();
}

class _ParkingImageResolverState extends State<_ParkingImageResolver> {
  static const _collections = ['parking_locations', 'parking', 'parkings'];
  String? _resolvedUrl;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _tryResolve();
  }

  Future<void> _tryResolve() async {
    for (final collection in _collections) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(collection)
            .doc(widget.parkingId)
            .get();
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            final url = _extractImagePath(data);
            if (url != null && url.startsWith('http')) {
              if (mounted) {
                setState(() {
                  _resolvedUrl = url;
                  _resolved = true;
                });
              }
              return;
            }
          }
        }
      } catch (_) {
        // Try next collection
      }
    }
    if (mounted) {
      setState(() => _resolved = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_resolved) {
      // Show a subtle loading shimmer while resolving
      return Container(
        color: const Color(0xFFF1F4F9),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }
    if (_resolvedUrl != null) {
      return widget.networkImageBuilder(_resolvedUrl!);
    }
    return widget.fallbackBuilder();
  }
}

class _HomeBooking {
  final String bookingId;
  final String parkingId;
  final String parkingName;
  final String address;
  final String slotNumber;
  final int floorIndex;
  final DateTime start;
  final DateTime end;
  final String status;
  final Map<String, dynamic> vehicle;
  final String? imagePath;
  final double? latitude;
  final double? longitude;

  const _HomeBooking({
    required this.bookingId,
    required this.parkingId,
    required this.parkingName,
    required this.address,
    required this.slotNumber,
    required this.floorIndex,
    required this.start,
    required this.end,
    required this.status,
    required this.vehicle,
    required this.imagePath,
    required this.latitude,
    required this.longitude,
  });

  factory _HomeBooking.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    final start =
        _asDateTime(data['startTime'] ?? data['start_ts']) ?? DateTime.now();
    final end =
        _asDateTime(data['endTime'] ?? data['end_ts']) ??
        start.add(const Duration(hours: 1));

    return _HomeBooking(
      bookingId: doc.id,
      parkingId: _asString(data['parkingId'] ?? data['parking_id']),
      parkingName: _asString(
        data['parkingName'] ?? data['parking_name'],
        fallback: 'Parking',
      ),
      address: _asString(
        data['parkingAddress'] ?? data['address'] ?? data['parking_address'],
      ),
      slotNumber: _asString(
        data['slotNumber'] ?? data['slotId'] ?? data['slot_id'],
        fallback: '--',
      ),
      floorIndex: _asInt(data['floor'], fallback: 0),
      start: start,
      end: end,
      status: BookingStatusHelper.normalize(data['status']),
      vehicle: Map<String, dynamic>.from(
        (data['vehicle'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      imagePath: _extractImagePath(data),
      latitude: _asDoubleNullable(data['latitude'] ?? data['lat']),
      longitude: _asDoubleNullable(data['longitude'] ?? data['lng']),
    );
  }

  bool get isCancelled => status == 'cancelled';

  bool get isCompleted => status == 'completed';

  int get floorDisplay => floorIndex + 1;

  Duration get totalDuration => end.difference(start);

  bool isActiveAt(DateTime now) {
    if (isCancelled || isCompleted) return false;
    if (end.isBefore(now) || end.isAtSameMomentAs(now)) return false;

    return !now.isBefore(start) && now.isBefore(end);
  }

  Duration remainingAt(DateTime now) {
    final remaining = end.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  double progressAt(DateTime now) {
    final totalSeconds = totalDuration.inSeconds;
    if (totalSeconds <= 0) return 1;

    final elapsedSeconds = now.difference(start).inSeconds;
    return (elapsedSeconds / totalSeconds).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toParkingPayload() {
    return <String, dynamic>{
      'id': parkingId,
      'name': parkingName,
      'address': address,
      'image': imagePath,
      'imageUrl': imagePath,
      'latitude': latitude,
      'longitude': longitude,
      'lat': latitude,
      'lng': longitude,
    };
  }
}

class _HomeParkingLot {
  final String id;
  final String name;
  final String address;
  final String? imagePath;
  final double pricePerHour;
  final int availableSlots;
  final double latitude;
  final double longitude;
  final int totalFloors;
  final bool hasEvCharging;
  final bool isCovered;
  final bool hasValet;
  final Map<String, dynamic> raw;

  const _HomeParkingLot({
    required this.id,
    required this.name,
    required this.address,
    required this.imagePath,
    required this.pricePerHour,
    required this.availableSlots,
    required this.latitude,
    required this.longitude,
    required this.totalFloors,
    required this.hasEvCharging,
    required this.isCovered,
    required this.hasValet,
    required this.raw,
  });

  factory _HomeParkingLot.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final features = _featureTokens(data);

    return _HomeParkingLot(
      id: doc.id,
      name: _asString(data['name'], fallback: 'Parking'),
      address: _asString(
        data['address'] ?? data['location'] ?? data['parkingAddress'],
      ),
      imagePath: _extractImagePath(data),
      pricePerHour: _asDouble(
        data['pricePerHour'] ??
            data['price_per_hour'] ??
            data['price'] ??
            data['hourlyRate'],
        fallback: 0,
      ),
      availableSlots: _asInt(
        data['availableSlots'] ?? data['available_slots'],
        fallback: 0,
      ),
      latitude: _asDouble(data['latitude'] ?? data['lat'], fallback: 0),
      longitude: _asDouble(data['longitude'] ?? data['lng'], fallback: 0),
      totalFloors: _asInt(
        data['total_floors'] ?? data['totalFloors'] ?? data['floors'],
        fallback: 1,
      ),
      hasEvCharging:
          _asBool(
            data['hasEvCharging'] ??
                data['evCharging'] ??
                data['ev_charging'] ??
                data['supportsEv'] ??
                data['has_ev'],
          ) ||
          _asInt(
                data['ev_slots'] ??
                    data['evSlots'] ??
                    data['ev_charging_slots'],
              ) >
              0 ||
          features.contains('ev') ||
          features.contains('charging') ||
          features.contains('evcharging'),
      isCovered:
          _asBool(
            data['coveredParking'] ??
                data['isCovered'] ??
                data['covered'] ??
                data['covered_parking'],
          ) ||
          features.contains('covered'),
      hasValet:
          _asBool(
            data['hasValet'] ??
                data['valetAvailable'] ??
                data['valet'] ??
                data['valet_available'],
          ) ||
          features.contains('valet'),
      raw: Map<String, dynamic>.from(data),
    );
  }

  double? distanceFrom(LatLng? userLocation) {
    if (userLocation == null) return null;
    if (latitude == 0 && longitude == 0) return null;

    return Geolocator.distanceBetween(
      userLocation.latitude,
      userLocation.longitude,
      latitude,
      longitude,
    );
  }

  bool matchesFilter(String filter) {
    switch (filter) {
      case 'EV Charging':
        return hasEvCharging;
      case 'Covered Parking':
        return !hasEvCharging && isCovered;
      case 'Valet':
        return !hasEvCharging && hasValet;
      case 'All Lots':
      default:
        return !hasEvCharging;
    }
  }

  Map<String, dynamic> toRouteMap(LatLng? userLocation) {
    final distance = distanceFrom(userLocation) ?? 0;

    return <String, dynamic>{
      ...raw,
      'id': id,
      'name': name,
      'address': address,
      'price': pricePerHour,
      'price_per_hour': pricePerHour,
      'pricePerHour': pricePerHour,
      'available_slots': availableSlots,
      'availableSlots': availableSlots,
      'distance': distance,
      'image': imagePath,
      'imageUrl': imagePath,
      'latitude': latitude,
      'longitude': longitude,
      'lat': latitude,
      'lng': longitude,
      'total_floors': totalFloors,
      'totalFloors': totalFloors,
      'hasEvCharging': hasEvCharging,
      'isCovered': isCovered,
      'hasValet': hasValet,
    };
  }
}

_HomeBooking? _resolveActiveBooking(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final now = DateTime.now();
  final allBookings = <_HomeBooking>[];
  debugPrint('[ActiveBooking] Raw doc count from Firestore: ${docs.length}');

  for (final doc in docs) {
    try {
      allBookings.add(_HomeBooking.fromFirestore(doc));
    } catch (e) {
      debugPrint('[ActiveBooking] ERROR parsing doc ${doc.id}: $e');
    }
  }
  debugPrint('[ActiveBooking] Parsed bookings: ${allBookings.length}');
  for (final b in allBookings) {
    debugPrint(
      '[ActiveBooking] id=${b.bookingId} status=${b.status} '
      'start=${b.start} end=${b.end} '
      'isCancelled=${b.isCancelled} isCompleted=${b.isCompleted} '
      'isActiveNow=${b.isActiveAt(now)}',
    );
  }

  // First, try to find a currently active booking (now >= start && now < end)
  final activeBookings =
      allBookings.where((booking) => booking.isActiveAt(now)).toList()
        ..sort((a, b) => a.end.compareTo(b.end));

  if (activeBookings.isNotEmpty) {
    debugPrint(
      '[ActiveBooking] Found active: ${activeBookings.first.bookingId}',
    );
    return activeBookings.first;
  }

  // If no active booking, find the nearest upcoming booking
  // (not cancelled/completed, end is in the future, start is in the future)
  final upcomingBookings =
      allBookings
          .where(
            (b) =>
                !b.isCancelled &&
                !b.isCompleted &&
                b.end.isAfter(now) &&
                b.start.isAfter(now),
          )
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));

  if (upcomingBookings.isNotEmpty) {
    debugPrint(
      '[ActiveBooking] Found upcoming: ${upcomingBookings.first.bookingId}',
    );
    return upcomingBookings.first;
  }

  // Grace window — show bookings that ended within last 5 minutes
  // so the ticket doesn't vanish abruptly
  final recentlyEndedBookings =
      allBookings
          .where(
            (b) =>
                !b.isCancelled &&
                !b.isCompleted &&
                b.end.isBefore(now) &&
                now.difference(b.end).inMinutes < 5,
          )
          .toList()
        ..sort((a, b) => b.end.compareTo(a.end));

  if (recentlyEndedBookings.isNotEmpty) {
    debugPrint(
      '[ActiveBooking] Found recently-ended: ${recentlyEndedBookings.first.bookingId}',
    );
    return recentlyEndedBookings.first;
  }
  debugPrint('[ActiveBooking] No active/upcoming booking found');
  return null;
}

List<_HomeParkingLot> _prepareParkingLots(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  String selectedFilter,
  LatLng? userLocation,
) {
  final lots = docs
      .map(_HomeParkingLot.fromFirestore)
      .where((lot) => lot.matchesFilter(selectedFilter))
      .toList();

  if (userLocation != null) {
    lots.sort((a, b) {
      final distanceA = a.distanceFrom(userLocation);
      final distanceB = b.distanceFrom(userLocation);

      if (distanceA == null && distanceB == null) return 0;
      if (distanceA == null) return 1;
      if (distanceB == null) return -1;
      return distanceA.compareTo(distanceB);
    });
  }

  return lots;
}

Future<String> _resolveParkingCollectionName() async {
  const candidates = <String>['parking_locations', 'parking', 'parkings'];

  for (final name in candidates) {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(name)
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) {
        return name;
      }
    } catch (_) {
      // Try the next collection name.
    }
  }

  return 'parking_locations';
}

DateTime? _asDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _asString(dynamic value, {String fallback = ''}) {
  final resolved = value?.toString().trim() ?? '';
  return resolved.isEmpty ? fallback : resolved;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

double? _asDoubleNullable(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' ||
        normalized == 'yes' ||
        normalized == '1' ||
        normalized == 'enabled';
  }
  return fallback;
}

Set<String> _featureTokens(Map<String, dynamic> data) {
  final tokens = <String>{};

  void addToken(Object? raw) {
    final text = raw?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty) return;
    final normalized = text.replaceAll(RegExp(r'[^a-z0-9]+'), '');
    if (normalized.isNotEmpty) tokens.add(normalized);
    for (final part in text.split(RegExp(r'[^a-z0-9]+'))) {
      if (part.isNotEmpty) tokens.add(part);
    }
  }

  final featureSources = <dynamic>[
    data['features'],
    data['amenities'],
    data['facilityTags'],
    data['services'],
    data['tags'],
  ];

  for (final source in featureSources) {
    if (source is Iterable) {
      for (final item in source) {
        addToken(item);
      }
    } else {
      addToken(source);
    }
  }

  return tokens;
}

String? _extractImagePath(Map<String, dynamic> data) {
  final candidates = <dynamic>[
    data['parkingImage'],
    data['imageUrl'],
    data['image'],
    data['thumbnail'],
    data['coverImage'],
    data['cover_image'],
    data['image_url'],
    data['parking_image'],
  ];

  for (final galleryKey in <String>['imageGallery', 'gallery', 'images']) {
    final gallery = data[galleryKey];
    if (gallery is Iterable && gallery.isNotEmpty) {
      candidates.add(gallery.first);
    }
  }

  for (final candidate in candidates) {
    final text = candidate?.toString().trim() ?? '';
    if (text.isEmpty) continue;
    return text;
  }

  return null;
}

String? _resolveAssetPath(String? imagePath) {
  final cleaned = imagePath?.trim().replaceAll('"', '') ?? '';
  if (cleaned.isEmpty) return null;
  if (cleaned.startsWith('http')) return cleaned;
  if (cleaned.startsWith('assets/')) return cleaned;

  final lower = cleaned.toLowerCase();
  if (lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp')) {
    return 'assets/images/$cleaned';
  }

  // Return null for unrecognizable strings so the parkingId
  // Firestore lookup can kick in instead of falling to fallback
  return null;
}

String _formatDurationClock(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

String _formatDurationCompact(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);

  if (hours == 0) {
    return '${minutes}m';
  }

  if (minutes == 0) {
    return '${hours}h';
  }

  return '${hours}h ${minutes}m';
}

String _formatDistance(double meters) {
  if (meters < 1000) {
    return '${meters.toStringAsFixed(0)} m';
  }
  return '${(meters / 1000).toStringAsFixed(1)} km';
}
