import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../presentation/parking_details/lot_detail_navigation.dart';
import '../services/map_service.dart';
import '../theme/app_colors.dart';

class WelcomePosterModal extends StatefulWidget {
  final VoidCallback onClose;
  final LatLng? initialUserPosition;

  const WelcomePosterModal({
    super.key,
    required this.onClose,
    this.initialUserPosition,
  });

  @override
  State<WelcomePosterModal> createState() => _WelcomePosterModalState();
}

class _WelcomePosterModalState extends State<WelcomePosterModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  _PosterLot? _nearestLot;
  bool _isLoading = true;
  bool _isOpeningBooking = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.92,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    _loadNearestLot();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadNearestLot() async {
    try {
      final userPosition =
          widget.initialUserPosition ?? await MapService.getUserLocation();
      final snapshot = await FirebaseFirestore.instance
          .collection('parking_locations')
          .limit(30)
          .get();

      final lots = snapshot.docs
          .map((doc) => _PosterLot.fromDoc(doc, userPosition))
          .where((lot) => lot.isActive)
          .toList();

      final availableLots = lots
          .where((lot) => lot.availableSlots > 0)
          .toList();
      final source = availableLots.isNotEmpty ? availableLots : lots;
      source.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));

      if (!mounted) return;
      setState(() {
        _nearestLot = source.isEmpty ? null : source.first;
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('Welcome poster error: $error');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _dismiss() async {
    await _controller.reverse();
    if (!mounted) return;
    widget.onClose();
  }

  Future<void> _openBooking() async {
    if (_nearestLot == null || _isOpeningBooking) return;

    setState(() => _isOpeningBooking = true);

    try {
      await _dismiss();
      if (!mounted) return;

      openLotDetail(
        context,
        _nearestLot!.id,
        _nearestLot!.raw,
        collectionName: 'parking_locations',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open details: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOpeningBooking = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _dismiss,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(color: Colors.black.withValues(alpha: 0.56)),
                ),
              ),
            ),
            Center(
              child: ScaleTransition(
                scale: _scale,
                child: SlideTransition(
                  position: _slide,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _isLoading
                        ? _buildSkeleton()
                        : _nearestLot == null
                        ? _buildEmptyState()
                        : _buildPoster(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoster() {
    final lot = _nearestLot!;

    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.10),
            blurRadius: 56,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── HERO IMAGE ───
            SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    lot.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                      child: const Center(
                        child: Icon(Icons.local_parking_rounded,
                            size: 72, color: Colors.white70),
                      ),
                    ),
                  ),
                  // Gradient fade
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.45, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.25),
                          Colors.transparent,
                          Colors.white,
                        ],
                      ),
                    ),
                  ),
                  // Close button
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: _dismiss,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: const Icon(Icons.close_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Share button
                  Positioned(
                    top: 12,
                    right: 54,
                    child: GestureDetector(
                      onTap: () {},
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: const Icon(Icons.share_rounded,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ─── CONTENT CARD ───
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Live badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'NEAREST SPOT FOUND',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.8,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              lot.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1A1C1D),
                                height: 1.15,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: const Color(0xFFE2E8F0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF00C853),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'LIVE',
                              style: GoogleFonts.manrope(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1A1C1D),
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Stats grid
                  Row(
                    children: [
                      Expanded(
                        child: _posterStatCard(
                          icon: Icons.near_me_rounded,
                          title: 'PROXIMITY',
                          value: _proximityValue(lot.distanceMeters),
                          subtitle: lot.distanceLabel,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _posterStatCard(
                          icon: Icons.payments_rounded,
                          title: 'PRICE',
                          value: '₹${lot.pricePerHour}/hr',
                          subtitle: 'Standard vehicle rate',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Feature badges
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (lot.hasEv)
                        _posterFeatureBadge(
                          Icons.ev_station_rounded,
                          'EV Charging',
                          isPrimary: true,
                        ),
                      _posterFeatureBadge(
                          Icons.fence_rounded, 'Underground'),
                      _posterFeatureBadge(
                          Icons.schedule_rounded, '24/7'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Availability footer
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Icon(
                            Icons.directions_car_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${lot.availableSlots} spots available',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A1C1D),
                                ),
                              ),
                              Text(
                                'Verified by TechXPark AI',
                                style: GoogleFonts.manrope(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // CTA buttons
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isOpeningBooking ? null : _openBooking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                        shadowColor: AppColors.primary.withValues(alpha: 0.3),
                      ).copyWith(
                        elevation: WidgetStateProperty.all(8),
                      ),
                      child: _isOpeningBooking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              'Book This Spot',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _dismiss,
                      icon: const Icon(Icons.map_rounded, size: 20),
                      label: Text(
                        'Show on Map',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A1C1D),
                        backgroundColor: const Color(0xFFE8E8EA),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
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

  Widget _posterStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F5).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1C1D),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF454655),
            ),
          ),
        ],
      ),
    );
  }

  Widget _posterFeatureBadge(IconData icon, String label,
      {bool isPrimary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: isPrimary
            ? AppColors.primary.withValues(alpha: 0.06)
            : const Color(0xFFE8E8EA),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 16,
              color: isPrimary ? AppColors.primary : const Color(0xFF454655)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isPrimary ? AppColors.primary : const Color(0xFF454655),
            ),
          ),
        ],
      ),
    );
  }

  String _proximityValue(double meters) {
    if (meters == double.maxFinite) return 'Nearby';
    final mins = (meters / 80).round(); // ~80m per minute walking
    if (mins <= 1) return '1 min away';
    return '$mins mins away';
  }

  Widget _buildSkeleton() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 240,
            decoration: const BoxDecoration(
              gradient: AppColors.primaryGradient,
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Finding nearest parking...',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 200,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_parking_rounded,
            size: 56,
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Parking Nearby',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No parking lots are available right now. Check back in a bit.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: _dismiss,
            child: Text(
              'Explore App',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _PosterLot {
  final String id;
  final String name;
  final String imageUrl;
  final int availableSlots;
  final int pricePerHour;
  final double rating;
  final double distanceMeters;
  final bool hasEv;
  final bool isActive;
  final Map<String, dynamic> raw;

  const _PosterLot({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.availableSlots,
    required this.pricePerHour,
    required this.rating,
    required this.distanceMeters,
    required this.hasEv,
    required this.isActive,
    required this.raw,
  });

  factory _PosterLot.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    LatLng? userPosition,
  ) {
    final data = doc.data();
    final position = MapService.getLatLng(data);
    final distanceMeters = userPosition == null || position == null
        ? double.maxFinite
        : Geolocator.distanceBetween(
            userPosition.latitude,
            userPosition.longitude,
            position.latitude,
            position.longitude,
          );

    return _PosterLot(
      id: doc.id,
      name: (data['name'] ?? 'Parking Lot').toString(),
      imageUrl: _resolveImage(doc.id, data),
      availableSlots: MapService.readInt(
        data['available_slots'] ?? data['availableSlots'],
      ),
      pricePerHour: MapService.readNumber(
        data['pricePerHour'] ?? data['price_per_hour'] ?? data['price'],
      ).round(),
      rating: MapService.readNumber(
        data['rating'] ?? data['ratingAverage'] ?? data['rating_average'],
        fallback: 4.5,
      ),
      distanceMeters: distanceMeters,
      hasEv: MapService.isEvLot(data),
      isActive: _isActive(data),
      raw: {'id': doc.id, ...data},
    );
  }

  String get distanceLabel {
    if (distanceMeters == double.maxFinite) return 'Nearby';
    if (distanceMeters < 1000) return '${distanceMeters.round()} m away';
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km away';
  }

  String get ratingLabel => rating.toStringAsFixed(1);

  static bool _isActive(Map<String, dynamic> data) {
    final value = data['isActive'] ?? data['active'] ?? true;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.toLowerCase();
      return normalized == 'true' || normalized == 'active';
    }
    return true;
  }

  static String _resolveImage(String id, Map<String, dynamic> data) {
    final image = (data['imageUrl'] ?? data['image'] ?? data['thumbnail'] ?? '')
        .toString();
    if (image.trim().isNotEmpty) {
      return image;
    }

    const fallbacks = [
      'https://images.unsplash.com/photo-1506521781263-d8422e82f27a?w=900&fit=crop&q=80',
      'https://images.unsplash.com/photo-1573348722427-f1d6819fdf98?w=900&fit=crop&q=80',
      'https://images.unsplash.com/photo-1590674899484-d5640e854abe?w=900&fit=crop&q=80',
    ];
    return fallbacks[id.hashCode.abs() % fallbacks.length];
  }
}
