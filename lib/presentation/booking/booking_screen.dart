import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';

// --- IMPORTS ---
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

import '../vehicle/my_vehicle_screen.dart';
import 'parking_overview_screen.dart';
import 'booking_time_screen.dart';

class BookingScreen extends StatefulWidget {
  final String parkingId;
  final Map<String, dynamic> parking;

  const BookingScreen({
    super.key,
    required this.parkingId,
    required this.parking,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? vehicle;
  bool vehicleLoading = true;

  // Animation Controller for "Slide Up" effect
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _loadVehicle();

    // Initialize Entrance Animation
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadVehicle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => vehicleLoading = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        final selectedId = userDoc.data()?["selected_vehicle_id"];
        if (selectedId != null) {
          final vDoc = await FirebaseFirestore.instance
              .collection("users")
              .doc(user.uid)
              .collection("vehicles")
              .doc(selectedId)
              .get();
          if (mounted) setState(() => vehicle = vDoc.data());
        }
      }
    } catch (e) {
      debugPrint("Error loading vehicle: $e");
    }

    if (mounted) setState(() => vehicleLoading = false);
  }

  void _openMap() async {
    HapticFeedback.mediumImpact();
    final lat = (widget.parking['latitude'] as num?)?.toDouble();
    final lng = (widget.parking['longitude'] as num?)?.toDouble();

    if (lat == null || lng == null) {
      _showSnack("Invalid location coordinates", isError: true);
      return;
    }

    final Uri googleMapsUrl = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
    );

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      } else {
        _showSnack('Could not launch Maps', isError: true);
      }
    } catch (e) {
      _showSnack("Error opening maps: $e", isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.textPrimaryLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- HELPER METHODS ---

  List<String> _galleryImagesFor(Map<String, dynamic> data) {
    final gallery = <String>[];
    final rawGallery =
        data['imageGallery'] ?? data['gallery'] ?? data['images'];
    if (rawGallery is List) {
      for (final item in rawGallery) {
        final url = item?.toString().trim() ?? '';
        if (url.isNotEmpty && !gallery.contains(url)) {
          gallery.add(url);
        }
      }
    }

    final primary = (data['imageUrl'] ?? data['image'] ?? '').toString().trim();
    if (primary.isNotEmpty && !gallery.contains(primary)) {
      gallery.insert(0, primary);
    }

    return gallery;
  }

  double _doubleValue(dynamic v, {double fallback = 0.0}) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  int _intValue(dynamic v, {int fallback = 0}) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  List<Map<String, dynamic>> _zonesFor(Map<String, dynamic> data) {
    final rawZones = data['zones'];
    final totalSlots = _intValue(
      data['totalSlots'] ?? data['total_slots'],
      fallback: 0,
    );

    if (rawZones is! List || rawZones.isEmpty) {
      return [
        {'name': 'General Zone', 'capacity': totalSlots, 'lifters': 0},
      ];
    }

    final zoneCount = rawZones.length;
    final baseCapacity = zoneCount == 0 ? 0 : totalSlots ~/ zoneCount;
    final remainder = zoneCount == 0 ? 0 : totalSlots % zoneCount;

    return List<Map<String, dynamic>>.generate(zoneCount, (index) {
      final raw = rawZones[index];
      final zone = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final name = zone['name']?.toString().trim().isNotEmpty == true
          ? zone['name'].toString().trim()
          : 'Zone ${index + 1}';
      final capacity = _intValue(
        zone['capacity'] ?? zone['totalSlots'] ?? zone['slots'],
        fallback: baseCapacity + (index < remainder ? 1 : 0),
      );
      return {
        'name': name,
        'capacity': capacity,
        'lifters': _intValue(zone['lifters'], fallback: 0),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.parking;
    final String name = p['name'] ?? 'Parking Detail';
    final String imageUrl = p['image'] ?? "";

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // 1. 🖼️ PREMIUM HEADER
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.bgDark,
            elevation: 0,
            leading: Center(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: "parking_image_${widget.parkingId}",
                    child: UniversalImage(
                      imagePath: imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                          AppColors.bgDark.withValues(alpha: 0.9),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 24,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "OPEN 24/7",
                            style: AppTextStyles.captionBold.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: AppTextStyles.h1.copyWith(
                            color: Colors.white,
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                p['address'] ?? "Unknown Location",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.body2.copyWith(
                                  color: Colors.white70,
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
          ),

          // 2. 📝 CONTENT BODY (Animated)
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Row
                      _buildStatsRow(p),
                      const SizedBox(height: 32),

                      _buildGallerySection(p),
                      const SizedBox(height: 32),

                      _buildReviewSection(p),
                      const SizedBox(height: 32),

                      _buildZonesSection(p),
                      const SizedBox(height: 32),

                      // Live Grid Button
                      _buildLiveGridButton(),
                      const SizedBox(height: 20),

                      // Directions Button
                      _buildDirectionsButton(),
                      const SizedBox(height: 32),

                      Text("Facilities", style: AppTextStyles.h2),
                      const SizedBox(height: 16),
                      _buildFacilitiesRow(),

                      const SizedBox(height: 32),

                      // Vehicle Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Your Vehicle", style: AppTextStyles.h2),
                          TextButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MyVehicleScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              "Change",
                              style: AppTextStyles.textButton,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      vehicleLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            )
                          : _buildVehicleCard(),

                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomAction(p),
    );
  }

  // --- WIDGETS ---

  Widget _buildStatsRow(Map p) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem(
            Icons.local_parking_rounded,
            "${p['available_slots'] ?? 0}",
            "Available",
            AppColors.primary,
          ),
          Container(width: 1, height: 40, color: AppColors.borderLight),
          _statItem(
            Icons.layers_rounded,
            "${p['total_floors'] ?? 1}",
            "Floors",
            AppColors.warning,
          ),
          Container(width: 1, height: 40, color: AppColors.borderLight),
          _statItem(
            Icons.star_rounded,
            "4.8",
            "Rating",
            const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: AppTextStyles.h2),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildGallerySection(Map<String, dynamic> p) {
    final images = _galleryImagesFor(p);
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Image Gallery', style: AppTextStyles.h2.copyWith(fontSize: 20)),
        const SizedBox(height: 16),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: UniversalImage(
                  imagePath: images[index],
                  width: 164,
                  height: 118,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewSection(Map<String, dynamic> p) {
    final rating = _doubleValue(
      p['rating'] ?? p['ratingAverage'] ?? p['averageRating'],
      fallback: 4.5,
    );
    final reviews = _intValue(
      p['reviews'] ?? p['ratingCount'] ?? p['rating_count'],
      fallback: 0,
    );
    final type = p['type']?.toString() ?? 'Smart Parking';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rating & Reviews', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFF59E0B),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${rating.toStringAsFixed(1)} (${reviews.toString()} reviews)',
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: 4),
                  Text(type, style: AppTextStyles.captionBold),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZonesSection(Map<String, dynamic> p) {
    final zones = _zonesFor(p);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Zones', style: AppTextStyles.h2.copyWith(fontSize: 20)),
        const SizedBox(height: 16),
        Column(
          children: zones.map((zone) {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zone['name']?.toString() ?? 'Zone',
                          style: AppTextStyles.h3,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${zone['capacity']?.toString() ?? '0'} slots • ${zone['lifters']?.toString() ?? '0'} lifters',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildLiveGridButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [AppColors.bgDark, Color(0xFF1E293B)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgDark.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ParkingOverviewScreen(parkingId: widget.parkingId),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.grid_view_rounded, color: AppColors.success),
                const SizedBox(width: 12),
                Text("View Live Parking Grid", style: AppTextStyles.buttonText),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionsButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _openMap,
        icon: const Icon(
          Icons.near_me_rounded,
          size: 20,
          color: AppColors.primary,
        ),
        label: Text(
          "Navigate to Location",
          style: AppTextStyles.body1.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          side: const BorderSide(color: AppColors.borderLight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: AppColors.surfaceLight,
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildFacilitiesRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _facilityCard(Icons.videocam_outlined, "CCTV", "24/7 Rec"),
        _facilityCard(Icons.security_rounded, "Guard", "On Duty"),
        _facilityCard(Icons.ev_station_rounded, "EV Spot", "Available"),
      ],
    );
  }

  Widget _facilityCard(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.textSecondaryLight, size: 28),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTextStyles.body2SemiBold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard() {
    if (vehicle == null) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyVehicleScreen()),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.primary,
                size: 36,
              ),
              const SizedBox(height: 12),
              Text(
                "Add Your Vehicle",
                style: AppTextStyles.body1.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.directions_car_filled,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehicle!['number'] ?? "N/A",
                  style: AppTextStyles.body1.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${vehicle!['brand']} • ${vehicle!['color']}",
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: AppColors.success, size: 28),
        ],
      ),
    );
  }

  Widget _buildBottomAction(Map p) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: vehicle == null
              ? () {
                  _showSnack("Please add a vehicle first");
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MyVehicleScreen()),
                  );
                }
              : () {
                  HapticFeedback.heavyImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BookingTimeScreen(
                        parkingId: widget.parkingId,
                        parking: Map<String, dynamic>.from(p),
                      ),
                    ),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            shadowColor: AppColors.primary.withValues(alpha: 0.4),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("BOOK PARKING SLOT", style: AppTextStyles.buttonText),
              SizedBox(width: 12),
              Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------
// 🛠️ UNIVERSAL IMAGE WIDGET (Included)
// -------------------------------------------------------------------------

class UniversalImage extends StatelessWidget {
  final String? imagePath;
  final double height;
  final double width;
  final BoxFit fit;

  const UniversalImage({
    super.key,
    this.imagePath,
    this.height = 280,
    this.width = double.infinity,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    String cleanPath = (imagePath ?? "").trim().replaceAll('"', '');
    if (cleanPath.isEmpty) return _buildLocalFallback();

    if (cleanPath.startsWith('http')) {
      return Image.network(
        cleanPath,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (ctx, err, stack) => _buildLocalFallback(),
      );
    }
    return Image.asset(
      cleanPath,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (ctx, err, stack) => _buildLocalFallback(),
    );
  }

  Widget _buildLocalFallback() {
    return Container(
      height: height,
      width: width,
      color: AppColors.bgDark,
      child: const Center(
        child: Icon(
          Icons.local_parking_rounded,
          color: Colors.white24,
          size: 60,
        ),
      ),
    );
  }
}
