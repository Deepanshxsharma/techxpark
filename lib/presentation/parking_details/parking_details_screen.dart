import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/bookmark_service.dart';
import '../../services/map_service.dart';
import '../../services/navigation_service.dart';
import '../../theme/app_colors.dart';
import '../booking/booking_time_screen.dart';

class ParkingDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String collectionName;

  const ParkingDetailsScreen({
    super.key,
    required this.data,
    this.collectionName = 'parking_locations',
  });

  @override
  State<ParkingDetailsScreen> createState() => _ParkingDetailsScreenState();
}

class _ParkingDetailsScreenState extends State<ParkingDetailsScreen> {
  late final String _parkingId;
  bool _isSaved = false;
  bool _isSaveLoading = true;
  bool _showLiveAvailability = false;
  double? _distanceMeters;

  @override
  void initState() {
    super.initState();
    _parkingId = widget.data['id']?.toString() ?? '';
    _distanceMeters = _readDouble(widget.data['distance']);
    debugPrint('Lot loaded: ${widget.data['name']}');
    _loadSavedState();
    _loadDistance();
  }

  Future<void> _loadSavedState() async {
    if (_parkingId.isEmpty) {
      if (!mounted) return;
      setState(() => _isSaveLoading = false);
      return;
    }

    final saved = await BookmarkService.isSaved(_parkingId);
    if (!mounted) return;
    setState(() {
      _isSaved = saved;
      _isSaveLoading = false;
    });
  }

  Future<void> _toggleSave() async {
    if (_parkingId.isEmpty || _isSaveLoading) return;
    HapticFeedback.mediumImpact();
    await BookmarkService.toggleSave(_parkingId);
    if (!mounted) return;
    setState(() => _isSaved = !_isSaved);
  }

  Future<void> _loadDistance() async {
    final lat = _readDouble(widget.data['latitude'] ?? widget.data['lat']);
    final lng = _readDouble(widget.data['longitude'] ?? widget.data['lng']);
    if (lat == null || lng == null) return;

    final distance = await NavigationService.instance.distanceTo(lat, lng);
    if (!mounted || distance == null) return;
    setState(() => _distanceMeters = distance);
  }

  Future<void> _shareLot(Map<String, dynamic> data) async {
    final lat = _readDouble(data['latitude'] ?? data['lat']);
    final lng = _readDouble(data['longitude'] ?? data['lng']);
    final name = _readString(data['name'], fallback: 'Parking Lot');
    final address = _readString(data['address']);
    final mapsLink = lat != null && lng != null
        ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
        : '';

    HapticFeedback.selectionClick();
    await SharePlus.instance.share(
      ShareParams(
        text: [
          name,
          if (address.isNotEmpty) address,
          if (mapsLink.isNotEmpty) mapsLink,
        ].join('\n'),
        subject: 'TechXPark Lot Details',
      ),
    );
  }

  Future<void> _openInMaps(Map<String, dynamic> data) async {
    final lat = _readDouble(data['latitude'] ?? data['lat']);
    final lng = _readDouble(data['longitude'] ?? data['lng']);
    if (lat == null || lng == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _navigateToLot(Map<String, dynamic> data) async {
    final lat = _readDouble(data['latitude'] ?? data['lat']);
    final lng = _readDouble(data['longitude'] ?? data['lng']);
    if (lat == null || lng == null) return;

    await NavigationService.instance.launchOutdoorNavigation(
      destLat: lat,
      destLng: lng,
      label: _readString(data['name'], fallback: 'Parking'),
    );
  }

  void _toggleLiveAvailability() {
    HapticFeedback.selectionClick();
    setState(() => _showLiveAvailability = !_showLiveAvailability);
  }

  void _openBooking(Map<String, dynamic> data, {required bool isAvailable}) {
    if (!isAvailable || _parkingId.isEmpty) return;

    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingTimeScreen(
          parkingId: _parkingId,
          parking: Map<String, dynamic>.from(data),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = _parkingId.isEmpty
        ? null
        : FirebaseFirestore.instance
              .collection(widget.collectionName)
              .doc(_parkingId)
              .snapshots();

    if (stream == null) {
      return _buildScaffold(widget.data);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final liveData = snapshot.data?.data();
        final merged = <String, dynamic>{
          ...widget.data,
          if (liveData != null) ...liveData,
          'id': _parkingId,
        };
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection(widget.collectionName)
              .doc(_parkingId)
              .collection('slots')
              .snapshots(),
          builder: (context, slotSnapshot) {
            final slotAvailability = _LiveSlotAvailability.fromDocs(
              slotSnapshot.data?.docs ?? const [],
            );
            return _buildScaffold(
              merged,
              liveAvailability: slotAvailability.hasSlots
                  ? slotAvailability
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildScaffold(
    Map<String, dynamic> data, {
    _LiveSlotAvailability? liveAvailability,
  }) {
    final topInset = MediaQuery.of(context).padding.top;
    final appBarHeight = topInset + 72.0;

    final name = _readString(data['name'], fallback: 'Parking Lot');
    final address = _readString(
      data['address'],
      fallback: 'Address unavailable',
    );
    final imageUrl = _readString(
      data['imageUrl'] ?? data['image'],
      fallback: '',
    );
    final price =
        _readDouble(
          data['price_per_hour'] ?? data['pricePerHour'] ?? data['price'],
        ) ??
        0;
    final fallbackAvailableSlots = _readInt(
      data['available_slots'] ?? data['availableSlots'],
    );
    final fallbackTotalSlots = _readInt(
      data['total_slots'] ?? data['totalSlots'],
    );
    final availableSlots =
        liveAvailability?.availableSlots ?? fallbackAvailableSlots;
    final totalSlots = liveAvailability?.totalSlots ?? fallbackTotalSlots;
    final rating =
        _readDouble(
          data['ratingAverage'] ?? data['averageRating'] ?? data['rating'],
        ) ??
        0;
    final reviewCount = _readInt(
      data['ratingCount'] ?? data['totalReviews'] ?? data['reviews'],
    );
    final hasEv = _readBool(data['hasEV'] ?? data['hasEvCharging']);
    final covered = _readBool(
      data['covered'] ?? data['isCovered'] ?? data['coveredParking'],
    );
    final security = _readBool(data['security'], fallback: true);
    final cctv = _readBool(data['cctv'], fallback: true);
    final isAvailable = availableSlots > 0;
    final statsPrice = price % 1 == 0
        ? price.toStringAsFixed(0)
        : price.toStringAsFixed(1);
    final slotsLabel = isAvailable
        ? '$availableSlots slots available'
        : 'No slots available';
    final latLng = MapService.getLatLng(data);
    final displayData = <String, dynamic>{
      ...data,
      'availableSlots': availableSlots,
      'available_slots': availableSlots,
      'totalSlots': totalSlots,
      'total_slots': totalSlots,
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9FB),
        body: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: appBarHeight)),
                SliverToBoxAdapter(
                  child: _HeroSection(
                    imageUrl: imageUrl,
                    slotsLabel: slotsLabel,
                    isAvailable: isAvailable,
                    isSaveLoading: _isSaveLoading,
                    isSaved: _isSaved,
                    onSaveTap: _toggleSave,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -24),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF9F9FB),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLotInfo(
                            name: name,
                            address: address,
                            rating: rating,
                            reviewCount: reviewCount,
                          ),
                          const SizedBox(height: 24),
                          _buildQuickStats(
                            priceLabel: '₹$statsPrice/hr',
                            totalSlots: totalSlots,
                          ),
                          const SizedBox(height: 24),
                          _buildDistanceCard(),
                          const SizedBox(height: 28),
                          _buildSectionLabel('Top Facilities'),
                          const SizedBox(height: 12),
                          _buildFacilitiesGrid(
                            hasEv: hasEv,
                            covered: covered,
                            security: security,
                            cctv: cctv,
                          ),
                          const SizedBox(height: 28),
                          if (_showLiveAvailability &&
                              liveAvailability != null &&
                              liveAvailability.hasSlots)
                            _buildLiveAvailabilitySection(
                              liveAvailability,
                              displayData,
                            ),
                          _buildSectionLabel('Location Map'),
                          const SizedBox(height: 12),
                          _buildMapCard(displayData, latLng),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: _ActionButton(
                                  icon: Icons.directions_rounded,
                                  label: 'Navigate',
                                  onTap: latLng == null
                                      ? null
                                      : () => _navigateToLot(displayData),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _ActionButton(
                                  icon: _showLiveAvailability
                                      ? Icons.analytics_rounded
                                      : Icons.analytics_outlined,
                                  label: _showLiveAvailability
                                      ? 'Hide Availability'
                                      : 'Live Availability',
                                  onTap: (liveAvailability != null &&
                                          liveAvailability.hasSlots)
                                      ? _toggleLiveAvailability
                                      : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 148),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _TopBar(
              title: 'Lot Details',
              onBack: () => Navigator.of(context).maybePop(),
              onShare: () => _shareLot(displayData),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 30,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Rate',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: const Color(0xFF757687),
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '₹$statsPrice',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1A1C1D),
                              ),
                            ),
                            TextSpan(
                              text: '/hr',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF757687),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 58,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: isAvailable
                            ? AppColors.primaryGradient
                            : null,
                        color: isAvailable ? null : const Color(0xFFE2E2E4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: ElevatedButton(
                        onPressed: isAvailable
                            ? () => _openBooking(
                                displayData,
                                isAvailable: isAvailable,
                              )
                            : null,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: const Color(0xFF757687),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: Text(
                          isAvailable ? 'Book Slot' : 'Sold Out',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isAvailable
                                ? Colors.white
                                : const Color(0xFF757687),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLotInfo({
    required String name,
    required String address,
    required double rating,
    required int reviewCount,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.poppins(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1C1D),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: Color(0xFF454655),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF454655),
                      ),
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFF59E0B),
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  rating.toStringAsFixed(1),
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${NumberFormat.compact().format(reviewCount)} reviews',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: const Color(0xFF757687),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStats({
    required String priceLabel,
    required int totalSlots,
  }) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(value: priceLabel, label: 'Pricing'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(value: totalSlots.toString(), label: 'Total Spots'),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: _StatCard(value: '24/7', label: 'Available'),
        ),
      ],
    );
  }

  Widget _buildDistanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryLight, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -16,
            top: -20,
            child: Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Proximity',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Colors.white.withValues(alpha: 0.84),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _distanceLabel(_distanceMeters),
                      style: GoogleFonts.poppins(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.near_me_rounded,
                size: 38,
                color: Colors.white54,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: const Color(0xFF757687),
      ),
    );
  }

  Widget _buildFacilitiesGrid({
    required bool hasEv,
    required bool covered,
    required bool security,
    required bool cctv,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _FacilityCard(
                icon: Icons.ev_station_rounded,
                label: 'EV Charging',
                enabled: hasEv,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FacilityCard(
                icon: Icons.garage_rounded,
                label: 'Covered Parking',
                enabled: covered,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _FacilityCard(
                icon: Icons.verified_user_rounded,
                label: '24/7 Security',
                enabled: security,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FacilityCard(
                icon: Icons.videocam_rounded,
                label: 'CCTV',
                enabled: cctv,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLiveAvailabilitySection(
    _LiveSlotAvailability availability,
    Map<String, dynamic> data,
  ) {
    const freeColor = Color(0xFF22C55E);
    const occupiedColor = Color(0xFFE2E2E4);
    const occupiedText = Color(0xFF757687);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildSectionLabel('Live Availability'),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: freeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: freeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: const Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE7E8EC)),
          ),
          child: Row(
            children: [
              _availabilityStat(
                  '${availability.availableSlots}', 'Free', freeColor),
              Container(
                  width: 1,
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: const Color(0xFFE2E2E4)),
              _availabilityStat(
                '${availability.totalSlots - availability.availableSlots}',
                'Occupied',
                AppColors.error,
              ),
              Container(
                  width: 1,
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: const Color(0xFFE2E2E4)),
              _availabilityStat(
                  '${availability.totalSlots}', 'Total', AppColors.primary),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Slot grid
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _gridLegend(freeColor, 'Free'),
                  const SizedBox(width: 18),
                  _gridLegend(occupiedColor, 'Occupied'),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: availability.slots.map((slot) {
                  final isFree = !slot.isOccupied;
                  return Container(
                    width: 72,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: isFree
                          ? freeColor.withValues(alpha: 0.1)
                          : occupiedColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFree
                            ? freeColor.withValues(alpha: 0.3)
                            : const Color(0xFFD5D5D8),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          isFree
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                          size: 18,
                          color: isFree ? freeColor : occupiedText,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          slot.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isFree
                                ? const Color(0xFF047857)
                                : occupiedText,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _availabilityStat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF757687),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF757687),
          ),
        ),
      ],
    );
  }

  Widget _buildMapCard(Map<String, dynamic> data, LatLng? latLng) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: latLng == null
                  ? Container(
                      color: const Color(0xFFEDEEF0),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.map_rounded,
                            size: 42,
                            color: Color(0xFF757687),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Map preview unavailable',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF454655),
                            ),
                          ),
                        ],
                      ),
                    )
                  : AbsorbPointer(
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: latLng,
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('lot'),
                            position: latLng,
                          ),
                        },
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        compassEnabled: false,
                        mapToolbarEnabled: false,
                        tiltGesturesEnabled: false,
                        rotateGesturesEnabled: false,
                        scrollGesturesEnabled: false,
                        zoomGesturesEnabled: false,
                      ),
                    ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 14,
              bottom: 14,
              child: FilledButton.icon(
                onPressed: latLng == null ? null : () => _openInMaps(data),
                icon: const Icon(Icons.map_rounded, size: 16),
                label: Text(
                  'Open in Maps',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1A1C1D),
                  disabledBackgroundColor: Colors.white70,
                  disabledForegroundColor: const Color(0xFF757687),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  static double? _readDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static bool _readBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == 'yes' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == 'no' || normalized == '0') {
        return false;
      }
    }
    return fallback;
  }

  static String _distanceLabel(double? meters) {
    if (meters == null) return 'Nearby';
    if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)} km away';
    return '${meters.round()} m away';
  }
}

class _LiveSlotAvailability {
  final int totalSlots;
  final int availableSlots;
  final bool hasSlots;
  final List<_SlotEntry> slots;

  const _LiveSlotAvailability({
    required this.totalSlots,
    required this.availableSlots,
    required this.hasSlots,
    required this.slots,
  });

  static _LiveSlotAvailability fromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    var total = 0;
    var available = 0;
    final entries = <_SlotEntry>[];

    for (final doc in docs) {
      final data = doc.data();
      final status = data['status']?.toString().trim().toLowerCase() ?? '';
      final type = data['type']?.toString().trim().toLowerCase() ?? '';
      final slotType = data['slotType']?.toString().trim().toLowerCase() ?? '';

      final disabled =
          data['enabled'] == false ||
          type == 'disabled' ||
          slotType == 'disabled' ||
          status == 'disabled' ||
          status == 'unavailable' ||
          status == 'blocked';
      if (disabled) continue;

      total += 1;

      final occupied =
          _readBool(data['occupied']) ||
          _readBool(data['isOccupied']) ||
          _readBool(data['taken']) ||
          _readBool(data['isReserved']) ||
          status == 'reserved' ||
          status == 'occupied' ||
          status == 'active' ||
          status == 'taken' ||
          status == 'live';

      if (!occupied) available += 1;

      final label = (data['label'] ?? data['slotNumber'] ?? data['name'] ?? doc.id)
          .toString();
      entries.add(_SlotEntry(id: doc.id, label: label, isOccupied: occupied));
    }

    entries.sort((a, b) => a.label.compareTo(b.label));

    return _LiveSlotAvailability(
      totalSlots: total,
      availableSlots: available,
      hasSlots: docs.isNotEmpty,
      slots: entries,
    );
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == 'yes' ||
          normalized == '1' ||
          normalized == 'reserved' ||
          normalized == 'occupied';
    }
    return false;
  }
}

class _SlotEntry {
  final String id;
  final String label;
  final bool isOccupied;

  const _SlotEntry({
    required this.id,
    required this.label,
    required this.isOccupied,
  });
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onShare;

  const _TopBar({
    required this.title,
    required this.onBack,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _GlassIconButton(icon: Icons.arrow_back_rounded, onTap: onBack),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
          _GlassIconButton(icon: Icons.share_rounded, onTap: onShare),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  final String imageUrl;
  final String slotsLabel;
  final bool isAvailable;
  final bool isSaveLoading;
  final bool isSaved;
  final VoidCallback onSaveTap;

  const _HeroSection({
    required this.imageUrl,
    required this.slotsLabel,
    required this.isAvailable,
    required this.isSaveLoading,
    required this.isSaved,
    required this.onSaveTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 397,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _HeroImage(imageUrl: imageUrl),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC1A1C1D)],
                stops: [0.32, 1],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 28,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x330018AB),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? const Color(0xFF22C55E)
                              : AppColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        slotsLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: isSaveLoading ? null : onSaveTap,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.74),
                      shape: BoxShape.circle,
                      boxShadow: AppColors.cardShadow,
                    ),
                    alignment: Alignment.center,
                    child: isSaveLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isSaved
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isSaved
                                ? const Color(0xFFB91C1C)
                                : const Color(0xFF1A1C1D),
                            size: 22,
                          ),
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

class _HeroImage extends StatelessWidget {
  final String imageUrl;

  const _HeroImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return Image.asset(
        'assets/images/parking_placeholder.png',
        fit: BoxFit.cover,
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Image.asset(
        'assets/images/parking_placeholder.png',
        fit: BoxFit.cover,
      ),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/parking_placeholder.png',
              fit: BoxFit.cover,
            ),
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          ],
        );
      },
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 42,
      height: 42,
      child: Material(
        color: Colors.white.withValues(alpha: 0.7),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Icon(icon, size: 22, color: AppColors.primary),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: const Color(0xFF757687),
            ),
          ),
        ],
      ),
    );
  }
}

class _FacilityCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;

  const _FacilityCard({
    required this.icon,
    required this.label,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = enabled ? AppColors.primary : const Color(0xFF757687);

    return Opacity(
      opacity: enabled ? 1 : 0.72,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE7E8EC)),
          boxShadow: AppColors.cardShadow,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1A1C1D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFFE8E8EA),
          foregroundColor: const Color(0xFF1A1C1D),
          disabledBackgroundColor: const Color(0xFFE8E8EA),
          disabledForegroundColor: const Color(0xFF757687),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
