import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../theme/app_colors.dart';
import '../../services/map_service.dart';
import '../../services/parking_filter_service.dart';
import '../booking/my_bookings_screen.dart';
import '../booking/parking_timer_screen.dart';
import '../notifications/notifications_screen.dart';
import '../parking_details/lot_detail_navigation.dart';
import '../search/search_parking_screen.dart';
import '../../widgets/welcome_poster_modal.dart';

const Color _surfaceLow = AppColors.activeBlueLight;
const Color _onSurface = AppColors.textPrimary;
const Color _onSurfaceVariant = AppColors.textSecondary;
const Color _outline = AppColors.textSecondary;

class DashboardMapScreen extends StatefulWidget {
  final ValueChanged<int>? onTabSwitch;

  const DashboardMapScreen({super.key, this.onTabSwitch});

  @override
  State<DashboardMapScreen> createState() => _DashboardMapScreenState();
}

class _DashboardMapScreenState extends State<DashboardMapScreen>
    with AutomaticKeepAliveClientMixin {
  static const Color _primary = AppColors.primary;
  static const Color _primaryContainer = AppColors.primaryLight;
  static const Color _background = AppColors.background;
  static const Color _surfaceLow = AppColors.activeBlueLight;
  static const Color _onSurface = AppColors.textPrimary;
  static const Color _onSurfaceVariant = AppColors.textSecondary;
  static const Color _outline = AppColors.textSecondary;
  static const Color _secondary = AppColors.primary;
  static const Color _accentText = AppColors.primaryLight;

  static const List<String> _filters = <String>[
    'All Lots',
    'EV Charging',
    'Covered Parking',
    '24/7',
    'Budget',
  ];

  String get _activeFilter => _filters[_selectedFilter];
  bool get _isEvFilterActive => _activeFilter == 'EV Charging';

  int _selectedFilter = 0;
  String? _locationName;
  LatLng? _userPosition;
  bool _isLocating = true;
  bool _hasLoadedPosition = false;
  bool _showWelcomePoster = false;
  GoogleMapController? _homeMapController;

  static bool _hasShownPoster = false;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _notificationsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _activeBookingsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _recentBookingsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _evLotsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _nearbyLotsStream;

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid;

    _notificationsStream = userId == null
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance
              .collection('notifications')
              .where('userId', isEqualTo: userId)
              .where('read', isEqualTo: false)
              .snapshots();

    _activeBookingsStream = userId == null
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance
              .collection('bookings')
              .where('userId', isEqualTo: userId)
              .snapshots();

    _recentBookingsStream = userId == null
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance
              .collection('bookings')
              .where('userId', isEqualTo: userId)
              .limit(20)
              .snapshots();

    _evLotsStream = FirebaseFirestore.instance
        .collection('parking_locations')
        .where('has_ev', isEqualTo: true)
        .limit(50)
        .snapshots();

    _nearbyLotsStream = ParkingFilterService.streamParking(
      ParkingFilterService.allFilterLabel,
    );

    MapService.loadMarkerIcons().then((_) {
      if (mounted) setState(() {});
    });
    _loadUserPosition();

    if (!_hasShownPoster) {
      _hasShownPoster = true;
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        setState(() => _showWelcomePoster = true);
      });
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _homeMapController?.dispose();
    super.dispose();
  }

  Future<void> _loadUserPosition({bool forceRefresh = false}) async {
    if (_hasLoadedPosition && !forceRefresh) return;
    _hasLoadedPosition = true;
    if (!mounted) return;
    setState(() {
      _isLocating = true;
      _locationName = 'Fetching...';
    });

    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _setLocationState(null, 'GPS Disabled');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        _setLocationState(null, 'Permission Denied');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        _setLocationState(null, 'Location Blocked');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final userPosition = LatLng(position.latitude, position.longitude);
      _setLocationState(
        userPosition,
        '${position.latitude.toStringAsFixed(3)}, '
        '${position.longitude.toStringAsFixed(3)}',
      );

      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (!mounted || placemarks.isEmpty) return;
        final p = placemarks.first;
        final parts = <String>[
          if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
          if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
        ];
        if (parts.isNotEmpty) {
          setState(() => _locationName = parts.join(', '));
        }
      } catch (_) {
        // Coordinates are already shown as a real fallback.
      }
    } catch (_) {
      _setLocationState(null, 'Location Unavailable');
    }
  }

  void _setLocationState(LatLng? position, String text) {
    if (!mounted) return;
    setState(() {
      _userPosition = position;
      _locationName = text;
      _isLocating = false;
    });
  }

  void _openSearch() {
    HapticFeedback.selectionClick();
    if (widget.onTabSwitch != null) {
      widget.onTabSwitch!(1);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SearchParkingScreen()),
    );
  }

  void _openBookings() {
    HapticFeedback.selectionClick();
    if (widget.onTabSwitch != null) {
      widget.onTabSwitch!(2);
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MyBookingsScreen()));
  }

  void _openNotifications() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
    );
  }

  void _openSlotSelection(_DashboardParkingLot lot) {
    if (lot.isFull) return;
    HapticFeedback.lightImpact();
    openLotDetail(
      context,
      lot.id,
      lot.toRouteMap(_userPosition),
      collectionName: 'parking_locations',
    );
  }

  void _openExtendBooking(_DashboardBooking booking) {
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

  Future<void> _openTechxpert() async {
    final uri = Uri.parse(
      'https://play.google.com/store/apps/'
      'details?id=io.ionic.techXpert&pcampaignid=web_share',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _background,
        body: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeroHeader()),
                SliverToBoxAdapter(child: _buildFilterPills()),
                SliverToBoxAdapter(child: _buildHomeMapPreview()),
                SliverToBoxAdapter(child: _buildActiveTicket()),
                SliverToBoxAdapter(child: _buildQuickActions()),
                SliverToBoxAdapter(child: _buildNearbySection()),
                SliverToBoxAdapter(child: _buildTechxpertBanner()),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
            if (_showWelcomePoster)
              Positioned.fill(
                child: WelcomePosterModal(
                  initialUserPosition: _userPosition,
                  onClose: () {
                    if (!mounted) return;
                    setState(() => _showWelcomePoster = false);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, _primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(48),
          bottomRight: Radius.circular(48),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => _loadUserPosition(forceRefresh: true),
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.65,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _locationName ?? 'Fetching...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          _isLocating
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.6,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 14,
                                ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _openNotifications,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(
                          Icons.notifications,
                          color: Colors.white,
                          size: 28,
                        ),
                        if (userId != null)
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: _notificationsStream,
                            builder: (context, snapshot) {
                              final count = snapshot.data?.docs.length ?? 0;
                              if (count == 0) {
                                return const SizedBox.shrink();
                              }
                              return Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.warning,
                                    shape: BoxShape.circle,
                                    border: Border.fromBorderSide(
                                      BorderSide(color: _primary, width: 1.5),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'TechXPark',
                style: GoogleFonts.poppins(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Find Parking,\n',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    TextSpan(
                      text: 'Park Smarter.',
                      style: GoogleFonts.poppins(
                        color: _accentText,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Search bar inside header
              GestureDetector(
                onTap: _openSearch,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: _outline,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Search destinations or lots...',
                            style: GoogleFonts.poppins(
                              color: _outline,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.activeBlueLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: AppColors.primary,
                            size: 16,
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
      ),
    );
  }

  Widget _buildFilterPills() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 48,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: _filters.length,
          itemBuilder: (context, index) {
            final isSelected = _selectedFilter == index;
            final isEvPill = _filters[index] == 'EV Charging';
            final Color pillColor;
            if (isSelected && isEvPill) {
              pillColor = AppColors.evGreen;
            } else if (isSelected) {
              pillColor = _primary;
            } else {
              pillColor = AppColors.border;
            }
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedFilter = index);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: pillColor.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isEvPill) ...[
                      Icon(
                        Icons.bolt_rounded,
                        size: 14,
                        color: isSelected ? Colors.white : AppColors.evGreen,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      _filters[index],
                      style: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : _onSurfaceVariant,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHomeMapPreview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _nearbyLotsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return Container(
              height: 220,
              decoration: BoxDecoration(
                color: _surfaceLow,
                borderRadius: BorderRadius.circular(24),
              ),
              alignment: Alignment.center,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            );
          }

          if (snapshot.hasError) {
            return const _InfoBlock(
              icon: Icons.map_outlined,
              text: 'Unable to load map data',
            );
          }

          final lots =
              (snapshot.data?.docs ?? const [])
                  .map(_DashboardParkingLot.fromFirestore)
                  .where((lot) => lot.latitude != 0 || lot.longitude != 0)
                  .toList()
                ..sort((a, b) => a.compareDistance(b, _userPosition));

          final center =
              _userPosition ??
              (lots.isNotEmpty
                  ? LatLng(lots.first.latitude, lots.first.longitude)
                  : const LatLng(28.6139, 77.2090));
          final markers = lots
              .take(30)
              .map((lot) {
                return MapService.createSmartMarker(
                  id: 'home_${lot.id}',
                  data: lot.toRouteMap(_userPosition),
                  onTap: () => _openSlotSelection(lot),
                );
              })
              .whereType<Marker>()
              .toSet();

          return Container(
            height: 220,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: center,
                    zoom: _userPosition == null ? 12 : 14,
                  ),
                  markers: markers,
                  myLocationEnabled: _userPosition != null,
                  myLocationButtonEnabled: false,
                  mapToolbarEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
                  onMapCreated: (controller) {
                    _homeMapController = controller;
                    controller.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        center,
                        _userPosition == null ? 12 : 14,
                      ),
                    );
                  },
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: GestureDetector(
                    onTap: _openSearch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.map_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              lots.isEmpty
                                  ? 'Open live parking map'
                                  : '${lots.length} parking locations on map',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: _onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveTicket() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _activeBookingsStream,
      builder: (context, snapshot) {
        debugPrint(
          '[DashTicket] connState=${snapshot.connectionState} '
          'hasData=${snapshot.hasData} hasError=${snapshot.hasError} '
          'docCount=${snapshot.data?.docs.length ?? 0}',
        );

        if (snapshot.hasError) {
          debugPrint('[DashTicket] ERROR: ${snapshot.error}');
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: _buildTicketSkeleton(),
          );
        }

        final booking = _bestBooking(snapshot.data?.docs ?? const []);
        debugPrint(
          '[DashTicket] resolved booking: ${booking?.parkingName ?? 'NONE'}',
        );

        if (booking == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active Parking Ticket',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _onSurface,
                          ),
                        ),
                        Text(
                          'Currently tracked session in progress',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: _onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _openBookings,
                    child: Text(
                      'DETAILS',
                      style: GoogleFonts.poppins(
                        color: _primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DashboardTicketCard(
                booking: booking,
                onDetailsTap: _openBookings,
                onExtendTap: () => _openExtendBooking(booking),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTicketSkeleton() {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: _surfaceLow,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _onSurface,
            ),
          ),
          const SizedBox(height: 16),
          // Row 1
          Row(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _evLotsStream,
                  builder: (context, snapshot) {
                    final evCount = (snapshot.data?.docs ?? const [])
                        .map(_DashboardParkingLot.fromFirestore)
                        .where((lot) => lot.hasEvCharging)
                        .length;
                    return _QuickActionCard(
                      icon: Icons.electric_car_rounded,
                      iconColor: _primary,
                      title: 'Find EV',
                      subtitle: evCount == 1
                          ? '1 nearby station'
                          : '$evCount nearby stations',
                      onTap: () {
                        setState(() => _selectedFilter = 1);
                        _openSearch();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _recentBookingsStream,
                  builder: (context, snapshot) {
                    final count = snapshot.data?.docs.length ?? 0;
                    return _QuickActionCard(
                      icon: Icons.history_rounded,
                      iconColor: _secondary,
                      title: 'Recents',
                      subtitle: count == 1
                          ? '1 spot visited'
                          : '$count spots visited',
                      onTap: _openBookings,
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Row 2
          Row(
            children: [
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.roofing_rounded,
                  iconColor: AppColors.success,
                  title: 'Covered',
                  subtitle: 'Rain-proof parking',
                  onTap: () {
                    setState(() => _selectedFilter = 2);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _QuickActionCard(
                  icon: Icons.home_repair_service_rounded,
                  iconColor: AppColors.warning,
                  title: 'TechXpert',
                  subtitle: 'Home services app',
                  onTap: _openTechxpert,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNearbySection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nearby Parking',
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _onSurface,
                      ),
                    ),
                    Text(
                      _userPosition == null
                          ? 'Showing available lots'
                          : 'Sorted by distance from you',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 12, color: _outline),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _openSearch,
                child: Text(
                  'View All',
                  style: GoogleFonts.poppins(
                    color: _primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _nearbyLotsStream,
            builder: (context, snapshot) {
              // ── 🔍 DEBUG: trace the full data pipeline ──
              debugPrint(
                '🅿️ [NearbyParking] STATE: ${snapshot.connectionState}',
              );
              debugPrint('🅿️ [NearbyParking] HAS DATA: ${snapshot.hasData}');
              debugPrint('🅿️ [NearbyParking] HAS ERROR: ${snapshot.hasError}');
              if (snapshot.hasError) {
                debugPrint('🅿️ [NearbyParking] ERROR: ${snapshot.error}');
              }
              debugPrint(
                '🅿️ [NearbyParking] DOC COUNT: ${snapshot.data?.docs.length ?? 0}',
              );
              debugPrint('TOTAL DOCS: ${snapshot.data?.docs.length ?? 0}');

              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return _buildLotsSkeletons();
              }

              if (snapshot.hasError) {
                return _InfoBlock(
                  icon: Icons.error_outline_rounded,
                  text: 'Unable to load parking lots',
                );
              }

              final allDocs = snapshot.data?.docs ?? const [];
              debugPrint('🅿️ [NearbyParking] RAW DOCS: ${allDocs.length}');

              // Log first doc's raw data for field verification
              if (allDocs.isNotEmpty) {
                final firstData = allDocs.first.data();
                debugPrint(
                  '🅿️ [NearbyParking] FIRST DOC ID: ${allDocs.first.id}',
                );
                debugPrint(
                  '🅿️ [NearbyParking] FIRST DOC KEYS: ${firstData.keys.toList()}',
                );
                debugPrint(
                  '🅿️ [NearbyParking] FIRST DOC name: ${firstData['name']}',
                );
              }

              final allMapped = allDocs
                  .map(_DashboardParkingLot.fromFirestore)
                  .toList();
              debugPrint('🅿️ [NearbyParking] MAPPED: ${allMapped.length}');

              final lots =
                  allMapped
                      .where(
                        (lot) => lot.matchesFilter(_filters[_selectedFilter]),
                      )
                      .toList()
                    ..sort((a, b) => a.compareDistance(b, _userPosition));
              debugPrint(
                '🅿️ [NearbyParking] AFTER FILTER "${_filters[_selectedFilter]}": ${lots.length}',
              );

              if (lots.isEmpty) {
                return _InfoBlock(
                  icon: _isEvFilterActive
                      ? Icons.ev_station_rounded
                      : Icons.local_parking_rounded,
                  text: _isEvFilterActive
                      ? 'No EV charging stations nearby'
                      : 'No parking lots available',
                );
              }

              return Column(
                children: lots
                    .map(
                      (lot) => _NearbyLotCard(
                        lot: lot,
                        userPosition: _userPosition,
                        onTap: () => _openSlotSelection(lot),
                        isEvFilterActive: _isEvFilterActive,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLotsSkeletons() {
    return Column(
      children: List.generate(
        3,
        (_) => Container(
          height: 110,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: _surfaceLow,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildTechxpertBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
      child: GestureDetector(
        onTap: _openTechxpert,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryDark, _primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _primary.withValues(alpha: 0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  color: _accentText,
                                  size: 11,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ALSO FROM TECHXPARK',
                                  style: GoogleFonts.poppins(
                                    color: _accentText,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Home Services\nAt Your Door',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'AC · Plumbing · Electrical\nCarpentry & more',
                            style: GoogleFonts.poppins(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.download_rounded,
                                  color: _primary,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Download Techxpert',
                                  style: GoogleFonts.poppins(
                                    color: _primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 100,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _serviceIcon(Icons.ac_unit_rounded, 'AC'),
                              const SizedBox(width: 6),
                              _serviceIcon(Icons.plumbing_rounded, 'Pipe'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _serviceIcon(
                                Icons.electrical_services_rounded,
                                'Elec',
                              ),
                              const SizedBox(width: 6),
                              _serviceIcon(Icons.carpenter_rounded, 'Repair'),
                            ],
                          ),
                        ],
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

  Widget _serviceIcon(IconData icon, String label) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white54,
              fontSize: 7,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardTicketCard extends StatelessWidget {
  final _DashboardBooking booking;
  final VoidCallback onDetailsTap;
  final VoidCallback onExtendTap;

  const _DashboardTicketCard({
    required this.booking,
    required this.onDetailsTap,
    required this.onExtendTap,
  });

  @override
  Widget build(BuildContext context) {
    final isUpcoming = booking.isUpcomingAt(DateTime.now());
    final accent = isUpcoming ? AppColors.warning : AppColors.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          children: [
            SizedBox(
              height: 184,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ParkingImage(
                    imagePath: booking.imagePath,
                    parkingId: booking.parkingId,
                    parkingName: booking.parkingName,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.78),
                          Colors.black.withValues(alpha: 0.16),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: _TicketStatusBadge(isUpcoming: isUpcoming),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.parkingName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _TicketImageChip(
                                icon: Icons.layers_rounded,
                                label:
                                    'Floor ${booking.floorDisplay} · Slot ${booking.slotNumber}',
                              ),
                            ),
                            if (booking.parkingAddress.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _TicketImageChip(
                                  icon: Icons.place_rounded,
                                  label: booking.parkingAddress,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: Column(
                children: [
                  _TicketCountdown(booking: booking),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: onDetailsTap,
                          icon: const Icon(
                            Icons.receipt_long_rounded,
                            size: 18,
                          ),
                          label: const Text('Details'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            textStyle: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: onExtendTap,
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 18,
                          ),
                          label: const Text('Extend Duration'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            textStyle: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

class _TicketStatusBadge extends StatelessWidget {
  final bool isUpcoming;

  const _TicketStatusBadge({required this.isUpcoming});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isUpcoming ? AppColors.warning : AppColors.primary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: SizedBox(width: 6, height: 6),
          ),
          const SizedBox(width: 7),
          Text(
            isUpcoming ? 'UPCOMING' : 'LIVE NOW',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketImageChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TicketImageChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketCountdown extends StatefulWidget {
  final _DashboardBooking booking;

  const _TicketCountdown({required this.booking});

  @override
  State<_TicketCountdown> createState() => _TicketCountdownState();
}

class _TicketCountdownState extends State<_TicketCountdown> {
  late DateTime _now;
  Timer? _timer;

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
    final isUpcoming = widget.booking.isUpcomingAt(_now);
    final remaining = widget.booking.remainingAt(_now);
    final elapsed = widget.booking.elapsedAt(_now);
    final total = widget.booking.totalDuration;
    final displayDuration = isUpcoming
        ? _positiveDuration(widget.booking.start.difference(_now))
        : remaining;
    final accent = isUpcoming ? AppColors.warning : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUpcoming ? 'STARTS IN' : 'TIME REMAINING',
                      style: GoogleFonts.poppins(
                        color: _onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatDurationClock(displayDuration),
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        color: _onSurface,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isUpcoming ? 'Scheduled' : 'In progress',
                  style: GoogleFonts.poppins(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: widget.booking.progressAt(_now),
              minHeight: 8,
              backgroundColor: Colors.white,
              color: accent,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TicketTimeLabel(
                label: 'ELAPSED',
                value: _formatDurationCompact(elapsed),
              ),
              _TicketTimeLabel(
                label: isUpcoming ? 'STARTS IN' : 'REMAINING',
                value: _formatDurationCompact(displayDuration),
              ),
              _TicketTimeLabel(
                label: 'TOTAL',
                value: _formatDurationCompact(total),
                alignEnd: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TicketTimeLabel extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _TicketTimeLabel({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: _onSurfaceVariant,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: _onSurface,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _surfaceLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _onSurface,
              ),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: _onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearbyLotCard extends StatelessWidget {
  final _DashboardParkingLot lot;
  final LatLng? userPosition;
  final VoidCallback onTap;
  final bool isEvFilterActive;

  const _NearbyLotCard({
    required this.lot,
    required this.userPosition,
    required this.onTap,
    this.isEvFilterActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool showEvStyle = lot.hasEvCharging && isEvFilterActive;
    final Color accentColor = showEvStyle
        ? AppColors.evGreen
        : AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: showEvStyle
              ? Border.all(
                  color: AppColors.evGreen.withValues(alpha: 0.3),
                  width: 1.5,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: showEvStyle
                  ? AppColors.evGreen.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: IntrinsicHeight(
          child: Row(
            children: [
              // ── Green accent strip for EV lots ──
              if (showEvStyle)
                Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.evGreen, Color(0xFF00E676)],
                    ),
                  ),
                ),
              SizedBox(
                width: showEvStyle ? 96 : 100,
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _ParkingImage(
                      imagePath: lot.imagePath,
                      parkingId: lot.id,
                      parkingName: lot.name,
                    ),
                    // ── EV badge overlay on image ──
                    if (showEvStyle)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.evGreen,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.bolt_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'EV',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Status badges row ──
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: lot.isFull
                                  ? AppColors.error.withValues(alpha: 0.1)
                                  : AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              lot.isFull
                                  ? 'Full'
                                  : '${lot.availableSlots} Slots Free',
                              style: GoogleFonts.poppins(
                                color: lot.isFull
                                    ? AppColors.error
                                    : AppColors.success,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (showEvStyle && lot.evSlots > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.evGreenLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.ev_station_rounded,
                                    size: 10,
                                    color: AppColors.evGreen,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${lot.evSlots} EV',
                                    style: GoogleFonts.poppins(
                                      color: AppColors.evGreen,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (lot.hasEvCharging &&
                              !isEvFilterActive) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.bolt_rounded,
                              size: 13,
                              color: AppColors.evGreen.withValues(alpha: 0.7),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        lot.name,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            showEvStyle
                                ? Icons.ev_station_rounded
                                : Icons.location_on_rounded,
                            size: 12,
                            color: showEvStyle ? AppColors.evGreen : _outline,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              lot.distanceLabel(userPosition),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: _outline,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.star_rounded,
                            size: 12,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            lot.rating.toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: _outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '₹${_formatPrice(lot.pricePerHour)}',
                                  style: GoogleFonts.poppins(
                                    color: accentColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(
                                  text: '/hr',
                                  style: GoogleFonts.poppins(
                                    color: _outline,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: lot.isFull
                                  ? AppColors.border
                                  : accentColor,
                              borderRadius: BorderRadius.circular(99),
                              boxShadow: lot.isFull
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: accentColor.withValues(
                                          alpha: 0.25,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (showEvStyle && !lot.isFull) ...[
                                  const Icon(
                                    Icons.bolt_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  lot.isFull ? 'Full' : 'Book Now',
                                  style: GoogleFonts.poppins(
                                    color: lot.isFull ? _outline : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
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

class _ParkingImage extends StatelessWidget {
  final String? imagePath;
  final String? parkingId;
  final String? parkingName;

  const _ParkingImage({
    required this.imagePath,
    this.parkingId,
    this.parkingName,
  });

  @override
  Widget build(BuildContext context) {
    final path = _resolveImagePath(imagePath);
    if (path != null && path.startsWith('http')) {
      return Image.network(
        path,
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
            const _LotImagePlaceholder(),
      );
    }

    if (path != null && path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const _LotImagePlaceholder(),
      );
    }

    final id = parkingId?.trim() ?? '';
    if (id.isNotEmpty) {
      return _ParkingImageResolver(parkingId: id, parkingName: parkingName);
    }

    return const _LotImagePlaceholder();
  }
}

class _ParkingImageResolver extends StatelessWidget {
  final String parkingId;
  final String? parkingName;

  const _ParkingImageResolver({required this.parkingId, this.parkingName});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _resolveParkingLotImage(parkingId, parkingName),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _LotImageLoading();
        }

        final path = _resolveImagePath(snapshot.data);
        if (path != null && path.startsWith('http')) {
          return Image.network(
            path,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                const _LotImagePlaceholder(),
          );
        }

        if (path != null && path.startsWith('assets/')) {
          return Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const _LotImagePlaceholder(),
          );
        }

        return const _LotImagePlaceholder();
      },
    );
  }
}

class _LotImageLoading extends StatelessWidget {
  const _LotImageLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _surfaceLow,
      child: const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _LotImagePlaceholder extends StatelessWidget {
  const _LotImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/parking_placeholder.png',
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        color: _surfaceLow,
        child: const Center(
          child: Icon(
            Icons.local_parking_rounded,
            color: AppColors.primary,
            size: 32,
          ),
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBlock({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 48, color: AppColors.border),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: _outline, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBooking {
  final String bookingId;
  final String parkingId;
  final String parkingName;
  final String parkingAddress;
  final String slotNumber;
  final int floorIndex;
  final DateTime start;
  final DateTime end;
  final String status;
  final String? imagePath;
  final double? latitude;
  final double? longitude;

  const _DashboardBooking({
    required this.bookingId,
    required this.parkingId,
    required this.parkingName,
    required this.parkingAddress,
    required this.slotNumber,
    required this.floorIndex,
    required this.start,
    required this.end,
    required this.status,
    required this.imagePath,
    required this.latitude,
    required this.longitude,
  });

  factory _DashboardBooking.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final start =
        _asDateTime(data['startTime'] ?? data['start_ts']) ?? DateTime.now();
    final end =
        _asDateTime(data['endTime'] ?? data['end_ts']) ??
        start.add(const Duration(hours: 1));

    return _DashboardBooking(
      bookingId: doc.id,
      parkingId: _asString(data['parkingId'] ?? data['parking_id']),
      parkingName: _asString(
        data['parkingName'] ?? data['parking_name'] ?? data['lotName'],
        fallback: 'Parking Lot',
      ),
      parkingAddress: _asString(
        data['parkingAddress'] ?? data['address'] ?? data['parking_address'],
      ),
      slotNumber: _asString(
        data['slotNumber'] ?? data['slotId'] ?? data['slot_id'],
        fallback: 'N/A',
      ),
      floorIndex: _asFloorIndex(data['floor']),
      start: start,
      end: end,
      status: _asString(data['status'], fallback: 'active').toLowerCase(),
      imagePath: _extractImagePath(data),
      latitude: _asDoubleNullable(
        data['lotLat'] ?? data['latitude'] ?? data['lat'],
      ),
      longitude: _asDoubleNullable(
        data['lotLng'] ?? data['longitude'] ?? data['lng'],
      ),
    );
  }

  int get floorDisplay => floorIndex + 1;

  Duration get totalDuration {
    final duration = end.difference(start);
    return duration.isNegative ? Duration.zero : duration;
  }

  bool get isBookableStatus => status == 'active' || status == 'upcoming';

  bool isCurrent(DateTime now) {
    if (!isBookableStatus) return false;
    return end.isAfter(now);
  }

  bool isUpcomingAt(DateTime now) => start.isAfter(now);

  Duration remainingAt(DateTime now) {
    final remaining = end.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Duration elapsedAt(DateTime now) {
    if (now.isBefore(start)) return Duration.zero;
    final elapsed = now.difference(start);
    if (elapsed > totalDuration) return totalDuration;
    return elapsed;
  }

  double progressAt(DateTime now) {
    if (isUpcomingAt(now)) return 0;
    final totalSeconds = totalDuration.inSeconds;
    if (totalSeconds <= 0) return 1;
    return (elapsedAt(now).inSeconds / totalSeconds).clamp(0, 1);
  }

  Map<String, dynamic> toParkingPayload() {
    return <String, dynamic>{
      'id': parkingId,
      'name': parkingName,
      'address': parkingAddress,
      'image': imagePath,
      'imageUrl': imagePath,
      'latitude': latitude,
      'longitude': longitude,
      'lat': latitude,
      'lng': longitude,
    };
  }
}

class _DashboardParkingLot {
  final String id;
  final String name;
  final String address;
  final String? imagePath;
  final double pricePerHour;
  final int availableSlots;
  final double rating;
  final double latitude;
  final double longitude;
  final int totalFloors;
  final bool hasEvCharging;
  final int evSlots;
  final bool isCovered;
  final bool isTwentyFourSeven;
  final Map<String, dynamic> raw;

  const _DashboardParkingLot({
    required this.id,
    required this.name,
    required this.address,
    required this.imagePath,
    required this.pricePerHour,
    required this.availableSlots,
    required this.rating,
    required this.latitude,
    required this.longitude,
    required this.totalFloors,
    required this.hasEvCharging,
    required this.evSlots,
    required this.isCovered,
    required this.isTwentyFourSeven,
    required this.raw,
  });

  factory _DashboardParkingLot.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final features = _featureTokens(data);

    return _DashboardParkingLot(
      id: doc.id,
      name: _asString(data['name'], fallback: 'Parking Lot'),
      address: _asString(
        data['address'] ?? data['location'] ?? data['parkingAddress'],
      ),
      imagePath: _extractImagePath(data),
      pricePerHour: _asDouble(
        data['price_per_hour'] ??
            data['pricePerHour'] ??
            data['price'] ??
            data['hourlyRate'],
      ),
      availableSlots: _asInt(data['available_slots'] ?? data['availableSlots']),
      rating: _asDouble(
        data['ratingAverage'] ??
            data['rating_average'] ??
            data['rating'] ??
            data['averageRating'],
        fallback: 0,
      ),
      latitude: _asDouble(data['latitude'] ?? data['lat']),
      longitude: _asDouble(data['longitude'] ?? data['lng']),
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
      evSlots: _asInt(
        data['ev_slots'] ?? data['evSlots'] ?? data['ev_charging_slots'],
        fallback: 0,
      ),
      isCovered:
          _asBool(
            data['coveredParking'] ??
                data['isCovered'] ??
                data['covered'] ??
                data['covered_parking'],
          ) ||
          features.contains('covered'),
      isTwentyFourSeven:
          _asBool(
            data['open247'] ??
                data['is24x7'] ??
                data['twentyFourSeven'] ??
                data['available24x7'],
          ) ||
          features.contains('247') ||
          features.contains('24x7'),
      raw: Map<String, dynamic>.from(data),
    );
  }

  bool get isFull => availableSlots <= 0;

  double? distanceFrom(LatLng? userPosition) {
    if (userPosition == null) return null;
    if (latitude == 0 && longitude == 0) return null;
    return Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
      latitude,
      longitude,
    );
  }

  String distanceLabel(LatLng? userPosition) {
    final distance = distanceFrom(userPosition);
    return distance == null ? 'Nearby' : _formatDistance(distance);
  }

  int compareDistance(_DashboardParkingLot other, LatLng? userPosition) {
    final a = distanceFrom(userPosition);
    final b = other.distanceFrom(userPosition);
    if (a == null && b == null) return name.compareTo(other.name);
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  bool matchesFilter(String filter) {
    switch (filter) {
      case 'EV Charging':
        return hasEvCharging;
      case 'Covered Parking':
        return !hasEvCharging && isCovered;
      case '24/7':
        return !hasEvCharging && isTwentyFourSeven;
      case 'Budget':
        return !hasEvCharging && pricePerHour > 0 && pricePerHour <= 50;
      case 'All Lots':
      default:
        return !hasEvCharging;
    }
  }

  Map<String, dynamic> toRouteMap(LatLng? userPosition) {
    final distance = distanceFrom(userPosition) ?? 0;
    return <String, dynamic>{
      ...raw,
      'id': id,
      'name': name,
      'address': address,
      'image': imagePath,
      'imageUrl': imagePath,
      'price': pricePerHour,
      'price_per_hour': pricePerHour,
      'pricePerHour': pricePerHour,
      'available_slots': availableSlots,
      'availableSlots': availableSlots,
      'rating': rating,
      'distance': distance,
      'latitude': latitude,
      'longitude': longitude,
      'lat': latitude,
      'lng': longitude,
      'total_floors': totalFloors,
      'totalFloors': totalFloors,
      'hasEvCharging': hasEvCharging,
      'isCovered': isCovered,
    };
  }
}

_DashboardBooking? _bestBooking(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final now = DateTime.now();
  debugPrint('[DashTicket] _bestBooking: ${docs.length} raw docs, now=$now');

  final parsed = <_DashboardBooking>[];
  for (final doc in docs) {
    try {
      final b = _DashboardBooking.fromFirestore(doc);
      debugPrint(
        '[DashTicket]   doc=${doc.id} status=${b.status} '
        'start=${b.start} end=${b.end} '
        'isBookable=${b.isBookableStatus} isCurrent=${b.isCurrent(now)}',
      );
      parsed.add(b);
    } catch (e) {
      debugPrint('[DashTicket]   ERROR parsing doc ${doc.id}: $e');
    }
  }

  final bookings = parsed.where((b) => b.isCurrent(now)).toList();
  debugPrint('[DashTicket] _bestBooking: ${bookings.length} current bookings');

  if (bookings.isEmpty) return null;

  bookings.sort((a, b) {
    if (a.status == 'active' && b.status != 'active') return -1;
    if (a.status != 'active' && b.status == 'active') return 1;
    return a.end.compareTo(b.end);
  });
  return bookings.first;
}

DateTime? _asDateTime(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

String _asString(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
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

int _asFloorIndex(dynamic value) {
  final floor = _asInt(value);
  return floor > 0 ? floor - 1 : floor;
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

  void addToken(Object? value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    if (text.isEmpty) return;
    final normalized = text.replaceAll(RegExp(r'[^a-z0-9]+'), '');
    if (normalized.isNotEmpty) tokens.add(normalized);
    for (final part in text.split(RegExp(r'[^a-z0-9]+'))) {
      if (part.isNotEmpty) tokens.add(part);
    }
  }

  for (final key in <String>[
    'features',
    'amenities',
    'facilityTags',
    'services',
    'tags',
  ]) {
    final source = data[key];
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

  for (final key in <String>['imageGallery', 'gallery', 'images']) {
    final gallery = data[key];
    if (gallery is Iterable && gallery.isNotEmpty) {
      candidates.add(gallery.first);
    }
  }

  for (final candidate in candidates) {
    final text = candidate?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }

  return null;
}

Future<String?> _resolveParkingLotImage(
  String parkingId,
  String? parkingName,
) async {
  final name = parkingName?.trim() ?? '';

  for (final collection in const <String>[
    'parking_locations',
    'parking',
    'parkings',
  ]) {
    try {
      final ref = FirebaseFirestore.instance.collection(collection);
      final doc = await ref.doc(parkingId).get();
      final data = doc.data();
      if (data != null) {
        final imagePath = _extractImagePath(data);
        if (imagePath != null && imagePath.trim().isNotEmpty) {
          return _toDisplayableImagePath(imagePath);
        }
      }

      if (name.isNotEmpty) {
        final query = await ref.where('name', isEqualTo: name).limit(1).get();
        if (query.docs.isNotEmpty) {
          final imagePath = _extractImagePath(query.docs.first.data());
          if (imagePath != null && imagePath.trim().isNotEmpty) {
            return _toDisplayableImagePath(imagePath);
          }
        }
      }
    } catch (error) {
      debugPrint('Parking image lookup failed in $collection: $error');
    }
  }

  return null;
}

Future<String> _toDisplayableImagePath(String imagePath) async {
  final cleaned = imagePath.trim().replaceAll('"', '');
  if (!cleaned.startsWith('gs://')) return cleaned;
  return FirebaseStorage.instance.refFromURL(cleaned).getDownloadURL();
}

String? _resolveImagePath(String? imagePath) {
  final cleaned = imagePath?.trim().replaceAll('"', '') ?? '';
  if (cleaned.isEmpty) return null;
  if (cleaned.startsWith('http') || cleaned.startsWith('assets/')) {
    return cleaned;
  }
  if (cleaned.startsWith('gs://')) return null;

  final lower = cleaned.toLowerCase();
  final looksLikeLocalFile = !cleaned.contains('/') && !cleaned.contains(':');
  if (lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp')) {
    return looksLikeLocalFile ? 'assets/images/$cleaned' : null;
  }

  return looksLikeLocalFile ? 'assets/images/$cleaned.png' : null;
}

String _formatDurationClock(Duration duration) {
  final safe = duration.isNegative ? Duration.zero : duration;
  final hours = safe.inHours.toString().padLeft(2, '0');
  final minutes = safe.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = safe.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

Duration _positiveDuration(Duration duration) {
  return duration.isNegative ? Duration.zero : duration;
}

String _formatDurationCompact(Duration duration) {
  final safe = duration.isNegative ? Duration.zero : duration;
  final hours = safe.inHours;
  final minutes = safe.inMinutes.remainder(60);
  if (hours == 0) return '${minutes}m';
  if (minutes == 0) return '${hours}h';
  return '${hours}h ${minutes}m';
}

String _formatDistance(double meters) {
  if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

String _formatPrice(double price) {
  return price.toStringAsFixed(price % 1 == 0 ? 0 : 1);
}
