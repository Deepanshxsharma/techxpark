import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../services/booking_status_helper.dart';
import '../../theme/app_text_styles.dart';
import '../booking/my_bookings_screen.dart';
import '../booking/parking_ticket_screen.dart';
import '../booking/parking_timer_screen.dart';
import '../notifications/notifications_screen.dart';
import '../parking_details/parking_details_screen.dart';
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
    'Valet',
  ];

  static const LinearGradient _heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF3B82F6)],
    stops: <double>[0.0, 0.6, 1.0],
  );

  int _selectedFilterIndex = 0;
  String _currentLocationText = 'Fetching location...';
  bool _isLocating = true;
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    if (!mounted) return;
    setState(() {
      _isLocating = true;
      _currentLocationText = 'Locating...';
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!mounted) return;
        setState(() {
          _currentLocation = null;
          _currentLocationText = 'GPS Disabled';
          _isLocating = false;
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
          _isLocating = false;
        });
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _currentLocation = null;
          _currentLocationText = 'Location Blocked';
          _isLocating = false;
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
        _isLocating = false;
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
            if (p.subLocality != null && p.subLocality!.isNotEmpty) p.subLocality!,
            if (p.locality != null && p.locality!.isNotEmpty) p.locality!,
          ];
          final locationName = parts.isNotEmpty
              ? parts.join(', ')
              : p.name ?? '${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)}';
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
        _isLocating = false;
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
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ParkingDetailsScreen(
          data: parking.toRouteMap(_currentLocation),
          collectionName: collectionName,
        ),
      ),
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
        backgroundColor: const Color(0xFFF8FAFC),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  _buildCinematicHeader(user.uid),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: -28,
                    child: _buildFloatingSearchBar(),
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
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
            const SliverToBoxAdapter(child: SizedBox(height: 36)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Quick Actions',
                  style: AppTextStyles.h2.copyWith(
                    fontSize: 22,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.electric_bolt_rounded,
                        iconColor: const Color(0xFF10B981),
                        bgColor: const Color(0xFFECFDF5),
                        title: 'EV Charge',
                        subtitle: 'Find stations',
                        onTap: _openSearch,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.receipt_long_rounded,
                        iconColor: const Color(0xFF8B5CF6),
                        bgColor: const Color(0xFFF5F3FF),
                        title: 'Bookings',
                        subtitle: 'Open history',
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
      padding: EdgeInsets.fromLTRB(24, topPadding + 16, 24, 64),
      decoration: BoxDecoration(
        gradient: _heroGradient,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.28),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _fetchCurrentLocation();
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                _isLocating
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.my_location_rounded,
                                        size: 16,
                                        color: Color(0xFF34D399),
                                      ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _currentLocationText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _NotificationButton(uid: uid, onTap: _openNotifications),
                ],
              ),
              const SizedBox(height: 36),
              const Text(
                'Find Parking,',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: <Color>[
                    Color(0xFF60A5FA), // Blue 400
                    Color(0xFF818CF8), // Indigo 400
                    Color(0xFFA78BFA), // Violet 400
                  ],
                ).createShader(bounds),
                child: const Text(
                  'Park Smarter.',
                  style: TextStyle(
                    color: Colors.white, // Required for ShaderMask
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingSearchBar() {
    return GestureDetector(
      onTap: _openSearch,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF1E3A8A).withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            const Icon(
              Icons.search_rounded,
              color: Color(0xFF3B82F6),
              size: 24,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Search destinations or lots...',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: Color(0xFF3B82F6),
                size: 20,
              ),
            ),
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
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF1E3A8A) : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : const Color(0xFFE2E8F0),
                  ),
                  boxShadow: selected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: const Color(
                              0xFF1E3A8A,
                            ).withValues(alpha: 0.26),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : const <BoxShadow>[],
                ),
                child: Text(
                  _filters[index],
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .snapshots(),
      builder: (context, snapshot) {
        final booking = _resolveActiveBooking(snapshot.data?.docs ?? const []);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SectionHeading(
                title: 'Active Parking Ticket',
                subtitle: booking == null
                    ? 'Your live session will appear here'
                    : 'Synced with your current booking',
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
                title: 'Nearby Parking',
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
                  stream: FirebaseFirestore.instance
                      .collection(collectionName)
                      .snapshots(),
                  builder: (context, snapshot) {
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
                style: AppTextStyles.h2.copyWith(
                  fontSize: 22,
                  color: const Color(0xFF0F172A),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: onActionTap,
          child: Text(
            actionLabel.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF3B82F6),
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActiveTicketCard extends StatelessWidget {
  final _HomeBooking booking;
  final VoidCallback onDetailsTap;
  final VoidCallback onPrimaryTap;

  const _ActiveTicketCard({
    super.key,
    required this.booking,
    required this.onDetailsTap,
    required this.onPrimaryTap,
  });

  static const String _fallbackImage = 'assets/images/parking_placeholder.jpg';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 190,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _SmartParkingImage(
                    imagePath: booking.imagePath,
                    fallbackAsset: _fallbackImage,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.black.withValues(alpha: 0.12),
                          Colors.black.withValues(alpha: 0.78),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: const Color(
                              0xFFEF4444,
                            ).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: <Widget>[
                          SizedBox(
                            width: 6,
                            height: 6,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'LIVE SESSION',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          booking.parkingName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.space_dashboard_rounded,
                              size: 14,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Floor ${booking.floorDisplay} • Slot ${booking.slotNumber}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
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
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _TicketInfoChip(
                          icon: Icons.login_rounded,
                          label: 'Start Time',
                          value: DateFormat('hh:mm a').format(booking.start),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _TicketInfoChip(
                          icon: Icons.timelapse_rounded,
                          label: 'Duration',
                          value: _formatDurationCompact(booking.totalDuration),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _CountdownPanel(booking: booking),
                  const SizedBox(height: 24),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onDetailsTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            foregroundColor: const Color(0xFF0F172A),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Details',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: onPrimaryTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Extend Duration',
                            style: TextStyle(fontWeight: FontWeight.w700),
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
              color: Color(0xFF3B82F6),
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
                backgroundColor: const Color(0xFF1E3A8A),
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
        child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
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
    final remaining = widget.booking.remainingAt(_now);
    final progress = widget.booking.progressAt(_now);

    return Column(
      children: <Widget>[
        const Text(
          'TIME REMAINING',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _formatDurationClock(remaining),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Started ${DateFormat('hh:mm a').format(widget.booking.start)}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Ends ${DateFormat('hh:mm a').format(widget.booking.end)}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFFF1F5F9),
            color: const Color(0xFF10B981),
          ),
        ),
      ],
    );
  }
}

class _TicketInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TicketInfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF2563EB)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 24,
                ),
                if (hasUnread)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF1E3A8A),
                          width: 2,
                        ),
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

  static const String _fallbackImage = 'assets/images/parking_placeholder.jpg';

  @override
  Widget build(BuildContext context) {
    final distanceMeters = parking.distanceFrom(userLocation);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isRecommended
                ? const Color(0xFF3B82F6)
                : const Color(0xFFE2E8F0),
            width: isRecommended ? 1.7 : 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            children: <Widget>[
              SizedBox(
                height: 150,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _SmartParkingImage(
                      imagePath: parking.imagePath,
                      fallbackAsset: _fallbackImage,
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.black.withValues(alpha: 0.08),
                            Colors.black.withValues(alpha: 0.32),
                          ],
                        ),
                      ),
                    ),
                    if (isRecommended)
                      Positioned(
                        top: 14,
                        left: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Recommended',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        parking.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.near_me_rounded,
                            size: 14,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            distanceMeters == null
                                ? 'Distance unavailable'
                                : _formatDistance(distanceMeters),
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _ParkingMetricPill(
                              icon: Icons.payments_outlined,
                              value:
                                  '₹${parking.pricePerHour.toStringAsFixed(parking.pricePerHour % 1 == 0 ? 0 : 1)}/hr',
                              accent: const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ParkingMetricPill(
                              icon: Icons.local_parking_rounded,
                              value: '${parking.availableSlots} slots',
                              accent: parking.availableSlots > 0
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParkingMetricPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color accent;

  const _ParkingMetricPill({
    required this.icon,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyParkingLoadingCard extends StatelessWidget {
  const _NearbyParkingLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
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
            child: Icon(icon, size: 34, color: const Color(0xFF3B82F6)),
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
                backgroundColor: const Color(0xFF1E3A8A),
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

  const _SmartParkingImage({
    required this.imagePath,
    required this.fallbackAsset,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedPath = _resolveAssetPath(imagePath);

    if (resolvedPath == null) {
      return Image.asset(fallbackAsset, fit: BoxFit.cover);
    }

    if (resolvedPath.startsWith('http')) {
      return Image.network(
        resolvedPath,
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
        errorBuilder: (context, error, stackTrace) =>
            Image.asset(fallbackAsset, fit: BoxFit.cover),
      );
    }

    return Image.asset(
      resolvedPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          Image.asset(fallbackAsset, fit: BoxFit.cover),
    );
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
        return isCovered;
      case 'Valet':
        return hasValet;
      case 'All Lots':
      default:
        return true;
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
  final activeBookings =
      docs
          .map(_HomeBooking.fromFirestore)
          .where((booking) => booking.isActiveAt(now))
          .toList()
        ..sort((a, b) => a.end.compareTo(b.end));

  return activeBookings.isEmpty ? null : activeBookings.first;
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
    data['imageUrl'],
    data['image'],
    data['thumbnail'],
    data['coverImage'],
    data['cover_image'],
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

  return cleaned;
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
