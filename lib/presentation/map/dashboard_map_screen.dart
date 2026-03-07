import 'dart:async';
import 'dart:ui'; // Required for Glassmorphism
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:lottie/lottie.dart' hide Marker;

import '../../config/map_config.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

// --- IMPORTS ---
import 'search_parking_screen.dart';
import '../../widgets/my_location_dot.dart';
import '../../presentation/booking/booking_screen.dart';
import '../../presentation/booking/my_bookings_screen.dart';
import '../../presentation/profile/profile_screen.dart';
import '../../presentation/vehicle/my_vehicle_screen.dart';
import '../../presentation/booking/parking_ticket_screen.dart';
import '../../presentation/map/find_my_car_screen.dart';
import '../../presentation/notifications/notifications_screen.dart';
import '../../presentation/messages/messages_screen.dart'; // Updated to new MessagesScreen
import '../../widgets/availability_heatmap.dart';

class DashboardMapScreen extends StatefulWidget {
  /// Static flag: intro animation shows only ONCE per app session.
  static bool _hasShownIntro = false;

  const DashboardMapScreen({super.key});

  @override
  State<DashboardMapScreen> createState() => _DashboardMapScreenState();
}

class _DashboardMapScreenState extends State<DashboardMapScreen>
    with TickerProviderStateMixin {
  // --- CONTROLLERS & STATE ---
  final MapController _mapController = MapController();
  LatLng? userLocation;
  StreamSubscription<Position>? locationStream;
  bool showMap = false;
  int selectedIndex = 0;
  bool _firstLocationUpdate = true;

  // --- ANIMATIONS ---
  late AnimationController navAnimController;
  late Animation<double> navAnimation;
  late Animation<double> fadeAnimation;

  // 🌟 POSTER ANIMATION
  late AnimationController posterController;
  late Animation<double> posterScaleAnim;

  // 🌟 PREMIUM BACKGROUND GRADIENT ANIMATION
  AnimationController? _bgAnimController;
  Animation<Color?>? _bgGradientColor1;
  Animation<Color?>? _bgGradientColor2;

  // 🌟 NUMBER COUNTER ANIMATION
  late AnimationController _numberController;
  late Animation<int> _numberAnimation;

  // 🌟 PREMIUM SEARCH OVERLAY ANIMATION
  late AnimationController _searchAnimController;
  late Animation<double> _searchExpandAnimation;
  late Animation<double> _searchFadeAnimation;
  bool _isSearchActive = false;
  final TextEditingController _searchCtrl = TextEditingController();
  List<QueryDocumentSnapshot> _allParkings = [];
  List<QueryDocumentSnapshot> _filteredParkings = [];

  // --- STATE VARIABLES ---
  bool _showIntro = !DashboardMapScreen._hasShownIntro;
  bool _showPoster = false;
  bool _hasShownPoster = false;
  DocumentSnapshot? _nearestParking;
  String _nearestDistance = "";

  // --- STREAMS ---
  final Stream<QuerySnapshot> parkingStream = FirebaseFirestore.instance
      .collection('parking_locations')
      .snapshots();
  final Uri _techxpertUrl = Uri.parse("https://techxpertindia.in/");
  List<String> mostUsedParkings = [];
  bool loadingMostUsed = true;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
    _loadMostUsedParkings();

    // Navbar Animation
    navAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    navAnimation = CurvedAnimation(
      parent: navAnimController,
      curve: Curves.easeOutCubic,
    );
    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: navAnimController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );
    navAnimController.forward();

    // Poster Animation
    posterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    posterScaleAnim = CurvedAnimation(
      parent: posterController,
      curve: Curves.easeOutBack,
    );

    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted && !showMap) setState(() {});
    });

    if (_showIntro) {
      DashboardMapScreen._hasShownIntro = true;
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) setState(() => _showIntro = false);
      });
    }
  }

  // 🌤️ Get Greeting based on time
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  @override
  void dispose() {
    locationStream?.cancel();
    _countdownTimer?.cancel();
    navAnimController.dispose();
    posterController.dispose();
    _bgAnimController?.dispose();
    _numberController.dispose();
    _searchAnimController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // --- LOGIC ---
  Future<void> _startLocationTracking() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;

    locationStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((pos) {
          final newPos = LatLng(pos.latitude, pos.longitude);
          if (mounted) setState(() => userLocation = newPos);

          if (showMap && _firstLocationUpdate) {
            _mapController.move(newPos, 16);
            _firstLocationUpdate = false;
          }

          if (!_hasShownPoster && !_showPoster) {
            _hasShownPoster = true;
            _findNearestParking(newPos);
          }
        });
  }

  Future<void> _findNearestParking(LatLng userPos) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('parking_locations')
          .get();
      if (snapshot.docs.isEmpty) return;

      DocumentSnapshot? closestDoc;
      double minDistance = double.infinity;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final lat = (data['latitude'] as num?)?.toDouble() ?? 0;
        final lng = (data['longitude'] as num?)?.toDouble() ?? 0;

        final dist = Geolocator.distanceBetween(
          userPos.latitude,
          userPos.longitude,
          lat,
          lng,
        );
        if (dist < minDistance) {
          minDistance = dist;
          closestDoc = doc;
        }
      }

      if (closestDoc != null && mounted) {
        String distStr = minDistance > 1000
            ? "${(minDistance / 1000).toStringAsFixed(1)} km"
            : "${minDistance.toInt()} m";

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          setState(() {
            _nearestParking = closestDoc;
            _nearestDistance = distStr;
            _showPoster = true;
          });
          posterController.forward();
        }
      }
    } catch (e) {
      debugPrint("Error finding nearest: $e");
    }
  }

  Future<void> _loadAllParkingsForSearch() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('parking_locations').get();
      if (!mounted) return;
      setState(() {
        _allParkings = snap.docs;
        _filteredParkings = _allParkings;
      });
    } catch (e) {
      debugPrint("Error loading parkings for search: $e");
    }
  }

  void _filterParkings(String query) {
    if (query.isEmpty) {
      setState(() => _filteredParkings = _allParkings);
      return;
    }
    final q = query.toLowerCase();
    setState(() {
      _filteredParkings = _allParkings.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final address = (data['address'] ?? '').toString().toLowerCase();
        return name.contains(q) || address.contains(q);
      }).toList();
    });
  }

  Future<void> _loadMostUsedParkings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await Future.delayed(const Duration(milliseconds: 800));
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .get();
      final Map<String, int> countMap = {};
      for (var doc in snapshot.docs) {
        final name = doc.data()['parkingName'] ?? doc.data()['parking_name'];
        if (name != null) countMap[name] = (countMap[name] ?? 0) + 1;
      }
      final sorted = countMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      if (mounted) {
        setState(() {
          mostUsedParkings = sorted.take(3).map((e) => e.key).toList();
          loadingMostUsed = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => loadingMostUsed = false);
    }
  }

  void _handleFindCar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please login to find your car")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Locating your vehicle..."),
        duration: Duration(milliseconds: 800),
      ),
    );

    try {
      final now = DateTime.now();

      final snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['active', 'upcoming'])
          .get();

      DocumentSnapshot? activeDoc;

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final start = (data["startTime"] ?? data["start_ts"] as Timestamp).toDate();
        final end = (data["endTime"] ?? data["end_ts"] as Timestamp).toDate();

        if (now.isAfter(start) && now.isBefore(end)) {
          activeDoc = doc;
          break; // Found it!
        }
      }

      if (activeDoc == null && snapshot.docs.isNotEmpty) {
        activeDoc = snapshot.docs.last;
      }

      if (activeDoc != null) {
        final data = activeDoc.data() as Map<String, dynamic>;

        if (data['latitude'] != null && data['longitude'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FindMyCarScreen(
                targetLat: (data['latitude'] as num).toDouble(),
                targetLng: (data['longitude'] as num).toDouble(),
                parkingName: data['parkingName'] ?? data['parking_name'] ?? "My Car",
              ),
            ),
          );
        } else {
          _showSnack("Error: Location data missing for this ticket");
        }
      } else {
        _showSnack("No active parking session found");
      }
    } catch (e) {
      debugPrint("Find Car Error: $e");
      _showSnack("Could not load active booking");
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- MAIN BUILD ---
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !showMap,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && showMap) {
          setState(() {
            showMap = false;
            selectedIndex = 0; // Reset nav index when popping from map
          });
        }
      },
      child: Scaffold(
        extendBody: true,
        body: Stack(
          children: [
            // 🌟 Animated Premium Background
            if (_bgAnimController != null)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _bgAnimController!,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _bgGradientColor1?.value ?? const Color(0xFFFAFAFA),
                            _bgGradientColor2?.value ?? const Color(0xFFF1F5F9),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                child: showMap ? _buildMapUI() : _buildDashboardUI(),
              ),
            ),
            // Old nav bar removed — MainShell provides the persistent bottom nav now
            if (_showPoster && _nearestParking != null) _buildPosterOverlay(),
            IgnorePointer(
              ignoring: !_showIntro,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 600),
                opacity: _showIntro ? 1.0 : 0.0,
                curve: Curves.easeOut,
                child: Container(
                  color: const Color(0xFFF8FAFC),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.8, end: 1.0),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.elasticOut,
                          builder: (context, value, child) {
                            return Transform.scale(scale: value, child: child);
                          },
                          child: Lottie.network(
                            'https://lottie.host/9e4d588a-2831-4b47-b3b3-568434524456/2Y5P8u9Xy2.json',
                            width: 250,
                            height: 250,
                            fit: BoxFit.contain,
                            errorBuilder: (ctx, _, __) => const Icon(
                              Icons.local_parking,
                              size: 100,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: Text(
                            "TechXPark",
                            style: AppTextStyles.h1.copyWith(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.0, end: 1.0),
                          duration: const Duration(milliseconds: 1200),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: Opacity(opacity: value, child: child),
                            );
                          },
                          child: Text(
                            "Premium Parking Experience",
                            style: AppTextStyles.body1.copyWith(
                              color: AppColors.textSecondaryLight,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- POSTER OVERLAY ---

  // 🌟 PREMIUM IN-PLACE SEARCH OVERLAY 🌟
  Widget _buildPremiumSearchOverlay() {
    return AnimatedBuilder(
      animation: _searchAnimController,
      builder: (context, child) {
        if (_searchAnimController.value == 0) return const SizedBox.shrink();

        final topPadding = MediaQuery.of(context).padding.top;

        return Positioned.fill(
          child: Stack(
            children: [
              // 1. Frosted Glass Backdrop
              GestureDetector(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  _searchAnimController.reverse().then(
                    (_) => setState(() => _isSearchActive = false),
                  );
                },
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 20 * _searchAnimController.value,
                    sigmaY: 20 * _searchAnimController.value,
                  ),
                  child: Container(
                    color: const Color(
                      0xFFF8FAFC,
                    ).withOpacity(0.85 * _searchAnimController.value),
                  ),
                ),
              ),

              // 2. The Search Content
              Positioned(
                top: topPadding + 20,
                left: 24,
                right: 24,
                bottom: 0,
                child: Column(
                  children: [
                    // Search Input Box
                    SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).animate(_searchExpandAnimation),
                      child: Hero(
                        tag: "search_bar_hero",
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF3B82F6,
                                  ).withOpacity(0.15),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              autofocus: _isSearchActive,
                              onChanged: _filterParkings,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: Color(0xFF0F172A),
                              ),
                              decoration: InputDecoration(
                                hintText: "Search parkings, cities...",
                                hintStyle: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontWeight: FontWeight.normal,
                                ),
                                prefixIcon: IconButton(
                                  icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: Color(0xFF0F172A),
                                  ),
                                  onPressed: () {
                                    FocusScope.of(context).unfocus();
                                    _searchAnimController.reverse().then(
                                      (_) => setState(
                                        () => _isSearchActive = false,
                                      ),
                                    );
                                  },
                                ),
                                suffixIcon: _searchCtrl.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        onPressed: () {
                                          _searchCtrl.clear();
                                          _filterParkings("");
                                        },
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Filtered Results List
                    Expanded(
                      child: FadeTransition(
                        opacity: _searchFadeAnimation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.1),
                            end: Offset.zero,
                          ).animate(_searchFadeAnimation),
                          child: _filteredParkings.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off_rounded,
                                        size: 60,
                                        color: const Color(
                                          0xFF94A3B8,
                                        ).withOpacity(0.5),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        "No parking spots found",
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  padding: EdgeInsets.only(
                                    bottom:
                                        MediaQuery.of(context).padding.bottom +
                                        20,
                                  ),
                                  itemCount: _filteredParkings.length,
                                  itemBuilder: (context, index) {
                                    final data =
                                        _filteredParkings[index].data()
                                            as Map<String, dynamic>;
                                    return _AnimatedScaleButton(
                                      onPressed: () {
                                        FocusScope.of(context).unfocus();
                                        _searchAnimController.reverse().then((
                                          _,
                                        ) {
                                          setState(() {
                                            _isSearchActive = false;
                                            showMap = true; // Switch to Map
                                            selectedIndex =
                                                1; // Highlight Map NavBar Icon
                                          });

                                          // Optional: You could center the map on this location here if you have map controller logic
                                          // _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(data['latitude'], data['longitude']), 16));
                                        });
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.04,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              child: const Icon(
                                                Icons.local_parking_rounded,
                                                color: AppColors.primary,
                                                size: 24,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    data['name'] ?? 'Parking',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 16,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    data['address'] ??
                                                        'Address',
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Color(0xFF64748B),
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.arrow_forward_ios_rounded,
                                              size: 14,
                                              color: Color(0xFFCBD5E1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- POSTER OVERLAY ---
  Widget _buildPosterOverlay() {
    final data = _nearestParking!.data() as Map<String, dynamic>;
    String rawImage = data['image'] ?? "";

    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: () {
              // Optional: Dismiss on tap outside
            },
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Center(
            child: ScaleTransition(
              scale: posterScaleAnim,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(24),
                              ),
                              child: UniversalImage(
                                imagePath: rawImage,
                                height: 220,
                                fit: BoxFit.cover,
                              ),
                            ),
                            // Gradient overlay for better text visibility
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(24),
                                  ),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.4),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.bolt,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      "Nearest to you",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(
                                data['name'] ?? "Parking Spot",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.near_me_rounded,
                                    color: Color(0xFF2563EB),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _nearestDistance,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2563EB),
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Text(
                                    " away",
                                    style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() => _showPoster = false);
                                  _openParkingDetails(
                                    _nearestParking!.id,
                                    data,
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  "VIEW DETAILS",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      posterController.reverse().then((_) {
                        setState(() => _showPoster = false);
                      });
                    },
                    child: Container(
                      height: 54,
                      width: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.5),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- DASHBOARD UI ---
  Widget _buildDashboardUI() {
    final user = FirebaseAuth.instance.currentUser;
    // Calculate bottom padding based on the attached navbar height (~90) + safe area
    final double bottomPadding = MediaQuery.of(context).padding.bottom + 100;

    return FadeTransition(
      opacity: fadeAnimation,
      child: SafeArea(
        bottom:
            false, // Turn off safe area at bottom so content flows under the transparent navbar
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDynamicHeader(user?.uid),
              const SizedBox(height: 28),
              _buildBookingStatusLogic(user?.uid),
              const SizedBox(height: 12),
              _buildParkingNearbySection(),
              const SizedBox(height: 36),
              const Text(
                "Favorite Locations",
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: 16),
              loadingMostUsed ? _buildShimmerList() : _buildRecentsList(),
              const SizedBox(height: 36),
              const Text(
                "Quick Actions",
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: 16),
              _buildActionGrid(),
            ],
          ),
        ),
      ),
    );
  }

  // --- MAP VIEW ---
  Widget _buildMapUI() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: userLocation ?? const LatLng(28.56, 77.32),
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: MapConfig.tileUrl,
              maxZoom: MapConfig.maxZoom,
              userAgentPackageName: MapConfig.userAgent,
            ),
            AvailabilityHeatmapLayer(
              parkingStream: parkingStream,
              onMarkerTap: (docId, data) {
                _openParkingDetails(docId, data);
              },
            ),
            if (userLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: userLocation!,
                    width: 20,
                    height: 20,
                    child: const MyLocationDot(),
                  ),
                ],
              ),
          ],
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 20,
          right: 20,
          child: GestureDetector(
            onTap: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchParkingScreen()),
              );
              if (res != null && res is Map && res['lat'] != null) {
                _mapController.move(LatLng(res['lat'], res['lng']), 17);
              }
            },
            child: _searchBarWidget(),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 20,
          child: GestureDetector(
            onTap: () => setState(() {
              showMap = false;
              selectedIndex = 0; // Reset active nav index
            }),
            child: Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF0F172A),
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openParkingDetails(String id, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          BookingScreen(parkingId: id, parking: {...data, "id": id}),
    );
  }

  // --- PARKING LIST (With Distance) ---
  Widget _buildParkingNearbySection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Parking nearby",
              style: AppTextStyles.h2,
            ),
            TextButton(
              onPressed: () => setState(() {
                showMap = true;
                selectedIndex = 1; // Update nav if clicked from text
              }),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
              ),
              child: const Text(
                "View on map",
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('parking_locations')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return _buildShimmerList();
              var docs = snapshot.data!.docs;
              if (docs.isEmpty)
                return Center(
                  child: Text(
                    "No parking spots found",
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                );

              if (userLocation != null) {
                docs.sort((a, b) {
                  final latA = (a.data() as Map)['latitude'] ?? 0;
                  final lngA = (a.data() as Map)['longitude'] ?? 0;
                  final latB = (b.data() as Map)['latitude'] ?? 0;
                  final lngB = (b.data() as Map)['longitude'] ?? 0;
                  final distA = Geolocator.distanceBetween(
                    userLocation!.latitude,
                    userLocation!.longitude,
                    latA,
                    lngA,
                  );
                  final distB = Geolocator.distanceBetween(
                    userLocation!.latitude,
                    userLocation!.longitude,
                    latB,
                    lngB,
                  );
                  return distA.compareTo(distB);
                });
              }

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                physics: const BouncingScrollPhysics(),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final id = docs[index].id;
                  String rawImage = data['image'] ?? "";

                  String distanceText = "";
                  if (userLocation != null) {
                    final lat = (data['latitude'] as num?)?.toDouble() ?? 0;
                    final lng = (data['longitude'] as num?)?.toDouble() ?? 0;
                    double dist = Geolocator.distanceBetween(
                      userLocation!.latitude,
                      userLocation!.longitude,
                      lat,
                      lng,
                    );
                    distanceText = dist > 1000
                        ? "${(dist / 1000).toStringAsFixed(1)} km"
                        : "${dist.toInt()} m";
                  }

                  return GestureDetector(
                    onTap: () => _openParkingDetails(id, data),
                    child: Container(
                      width: 250,
                      margin: const EdgeInsets.only(right: 16, bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF000000).withOpacity(0.06),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(24),
                                ),
                                child: UniversalImage(
                                  imagePath: rawImage,
                                  height: 140,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(24),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.4),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.local_parking_rounded,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        "${data['available_slots'] ?? 0} spots",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        data['name'] ?? "Parking Spot",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    if (distanceText.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.near_me_rounded,
                                              size: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              distanceText,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_rounded,
                                      size: 14,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        data['address'] ?? "No Address",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF64748B),
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
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerList() {
    return Column(
      children: List.generate(
        3,
        (index) => Shimmer.fromColors(
          baseColor: Colors.grey.shade200,
          highlightColor: Colors.white,
          child: Container(
            height: 76,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookingStatusLogic(String? uid) {
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: uid)
          .where('status', whereIn: ['active', 'upcoming'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
          return const SizedBox.shrink();
        final now = DateTime.now();
        DocumentSnapshot? activeDoc;
        DocumentSnapshot? upcomingDoc;
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final start = (data["startTime"] ?? data["start_ts"] as Timestamp).toDate();
          final end = (data["endTime"] ?? data["end_ts"] as Timestamp).toDate();
          if (now.isAfter(start) && now.isBefore(end))
            activeDoc = doc;
          else if (start.isAfter(now)) {
            if (upcomingDoc == null)
              upcomingDoc = doc;
            else if (start.isBefore(
              ((upcomingDoc.data() as Map)["startTime"] ?? (upcomingDoc.data() as Map)["start_ts"]).toDate(),
            ))
              upcomingDoc = doc;
          }
        }
        if (activeDoc != null) return _heroCardUI(activeDoc, isUpcoming: false);
        if (upcomingDoc != null)
          return _heroCardUI(upcomingDoc, isUpcoming: true);
        return const SizedBox.shrink();
      },
    );
  }

  Widget _heroCardUI(DocumentSnapshot doc, {required bool isUpcoming}) {
    final data = doc.data() as Map<String, dynamic>;
    final endTime = (data["endTime"] ?? data["end_ts"] as Timestamp).toDate();
    final startTime = (data["startTime"] ?? data["start_ts"] as Timestamp).toDate();
    final now = DateTime.now();
    double progress =
        (!isUpcoming && endTime.difference(startTime).inMinutes > 0)
        ? (now.difference(startTime).inMinutes /
                  endTime.difference(startTime).inMinutes)
              .clamp(0.0, 1.0)
        : 0.0;
    String timeLabel = isUpcoming
        ? "Starts in ${startTime.difference(now).inHours}h ${startTime.difference(now).inMinutes % 60}m"
        : "${endTime.difference(now).inHours}h ${endTime.difference(now).inMinutes % 60}m left";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(bottom: 16, top: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xFF0F172A),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isUpcoming ? "RESERVATION" : "ACTIVE TICKET",
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      data["parkingName"] ?? data["parking_name"] ?? "Parking",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Slot ${data['slotId'] ?? data['slot_id']} • Floor ${data['floor'] ?? 'G'}",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (!isUpcoming) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.1),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.access_time_rounded,
                      color: Colors.white60,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        timeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.heavyImpact();
                  final Map<String, dynamic> parkingMap = {
                    "name": data["parkingName"] ?? data["parking_name"],
                    "address": data["address"] ?? "TechXpark Facility",
                    "latitude": data["latitude"],
                    "longitude": data["longitude"],
                    "price_per_hour": data["price_per_hour"] ?? 50,
                  };
                  final Map<String, dynamic> vehicleMap =
                      (data["vehicle"] is Map)
                      ? Map<String, dynamic>.from(data["vehicle"] as Map)
                      : {"number": "UNKNOWN", "type": "car"};
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ParkingTicketScreen(
                        parking: parkingMap,
                        slot: data["slotId"] ?? data["slot_id"] ?? "N/A",
                        floorIndex: (data["floor"] as num?)?.toInt() ?? 0,
                        start: startTime,
                        end: endTime,
                        vehicle: vehicleMap,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  minimumSize: const Size(100, 44),
                ),
                child: const Text(
                  "VIEW",
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- HEADER (PROFESSIONAL) ---
  Widget _buildDynamicHeader(String? uid) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final name = (data["name"] ?? "User").split(" ")[0];

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$_greeting, $name",
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "TechXPark.",
                    style: AppTextStyles.h1.copyWith(
                      fontSize: 28,
                      color: AppColors.textPrimaryLight,
                      letterSpacing: -1.0,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SearchParkingScreen(),
                    ),
                  ),
                  icon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF0F172A),
                    size: 26,
                  ),
                ),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseAuth.instance.currentUser != null
                      ? FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser!.uid)
                          .collection('notifications')
                          .where('read', isEqualTo: false)
                          .snapshots()
                      : null,
                  builder: (context, snapshot) {
                    final unreadCount = snapshot.data?.docs.length ?? 0;
                    return _AnimatedScaleButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          NotificationsPageRoute(),
                        );
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              backgroundColor: Colors.white,
                              radius: 22,
                              child: Icon(
                                unreadCount > 0
                                    ? Icons.notifications_rounded
                                    : Icons.notifications_none_rounded,
                                color: const Color(0xFF0F172A),
                                size: 22,
                              ),
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFE53935),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    unreadCount > 9 ? '9+' : '$unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),

              ],
            ),
          ],
        );
      },
    );
  }

  Widget _searchBarWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: Color(0xFF0F172A), size: 22),
          const SizedBox(width: 12),
          Text(
            "Where to park today?",
            style: AppTextStyles.body1.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Color(0xFF0F172A),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentsList() {
    if (loadingMostUsed)
      return const Center(child: CircularProgressIndicator());
    return Column(
      children: mostUsedParkings.map((name) => _buildRecentTile(name)).toList(),
    );
  }

  Widget _buildRecentTile(String name) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.history_toggle_off_rounded,
            color: Color(0xFF64748B),
            size: 22,
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: Color(0xFF1E293B),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 14,
          color: Color(0xFFCBD5E1),
        ),
        onTap: () async {
          HapticFeedback.mediumImpact();
          final snap = await FirebaseFirestore.instance
              .collection('parking_locations')
              .where('name', isEqualTo: name)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty)
            _openParkingDetails(snap.docs.first.id, snap.docs.first.data());
        },
      ),
    );
  }

  Widget _buildActionGrid() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _buildStaticActionGrid();
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .where('status', whereIn: ['active', 'upcoming'])
          .snapshots(),
      builder: (context, snapshot) {
        bool hasActiveBooking = false;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final now = DateTime.now();
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final start = (data["startTime"] ?? data["start_ts"] as Timestamp).toDate();
            final end = (data["endTime"] ?? data["end_ts"] as Timestamp).toDate();
            if (now.isAfter(start) && now.isBefore(end)) {
              hasActiveBooking = true;
              break;
            }
          }
        }

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.25, // Tweaked for slightly taller premium cards
          children: [
            if (hasActiveBooking)
              QuickActionCard(
                title: "View Active Ticket",
                icon: Icons.confirmation_number_rounded,
                isHighlighted: true,
                onTap: () {
                  // Scrolling/Jumping is handled automatically by the user scrolling up.
                  // For now, this just acts as a quick jump prompt, or we can open ticket.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Your active ticket is displayed above')),
                  );
                },
              )
            else
              QuickActionCard(
                title: "Find Parking",
                icon: Icons.local_parking_rounded,
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchParkingScreen()));
                },
              ),
            QuickActionCard(
              title: "My Bookings",
              icon: Icons.receipt_long_rounded,
              target: const MyBookingsScreen(),
            ),
            QuickActionCard(
              title: "My Garage",
              icon: Icons.garage_rounded,
              target: const MyVehicleScreen(),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .where('participants', arrayContains: user.uid)
                  .snapshots(),
              builder: (context, convSnap) {
                int unreadMessages = 0;
                if (convSnap.hasData) {
                  for (var doc in convSnap.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    unreadMessages += (data['unreadCount']?[user.uid] as num?)?.toInt() ?? 0;
                  }
                }
                return QuickActionCard(
                  title: "Support",
                  icon: Icons.headset_mic_rounded,
                  target: const MessagesScreen(), // Pointed Support to real screen
                  badgeCount: unreadMessages > 0 ? unreadMessages : null,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildStaticActionGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.25,
      children: [
        QuickActionCard(
          title: "Find Parking",
          icon: Icons.local_parking_rounded,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchParkingScreen()));
          },
        ),
        QuickActionCard(
          title: "My Bookings",
          icon: Icons.receipt_long_rounded,
          target: const MyBookingsScreen(),
        ),
        QuickActionCard(
              title: "My Garage",
              icon: Icons.garage_rounded,
              target: const MyVehicleScreen(),
        ),
        QuickActionCard(
          title: "Support",
          icon: Icons.headset_mic_rounded,
          target: const MessagesScreen(),
        ),
      ],
    );
  }

  // 🌟 ATTACHED NAVBAR
  Widget _buildAttachedNavBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ScaleTransition(
        scale: navAnimation,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              // The height adjusts automatically for iPhones/devices with a bottom safe area (home bar)
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom,
                top: 12,
                left: 8,
                right: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(
                  0xFF0F172A,
                ).withOpacity(0.90), // Professional dark glass
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withOpacity(0.15),
                    width: 1,
                  ),
                ),
              ),
              child: SizedBox(
                height: 64, // Fixed visual height above the safe area
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _navIcon(Icons.home_filled, 0, "Home"),

                    // 🗺️ Index 1: Map Button (Replaces GateX)
                    _navIcon(Icons.map_rounded, 1, "Map"),

                    // 🌐 CENTER BUTTON: TechXpert Website
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        launchUrl(_techxpertUrl);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white,
                          child: Image.asset(
                            "assets/images/techxpert_logo.png",
                            height: 32,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.language_rounded,
                                  color: Color(0xFF0F172A),
                                  size: 28,
                                ),
                          ),
                        ),
                      ),
                    ),

                    _navIcon(Icons.receipt_long_rounded, 2, "History"),
                    _navIcon(Icons.person_rounded, 3, "Profile"),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔄 UPDATED NAV LOGIC
  Widget _navIcon(IconData icon, int index, String tooltip) {
    final isSelected = selectedIndex == index;
    return IconButton(
      tooltip: tooltip,
      icon: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: isSelected ? const EdgeInsets.all(8) : EdgeInsets.zero,
        decoration: isSelected
            ? BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              )
            : const BoxDecoration(),
        child: Icon(
          icon,
          color: isSelected ? const Color(0xFF60A5FA) : Colors.white60,
          size: isSelected ? 28 : 26,
        ),
      ),
      onPressed: () {
        HapticFeedback.lightImpact();

        if (index == 1) {
          // 🚗 My Vehicle Logic
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyVehicleScreen()),
          );
        } else {
          setState(() => selectedIndex = index);
          if (index == 2)
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
            );
          if (index == 3)
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            );
        }
      },
    );
  }
} // 🛑 CLOSE _DashboardMapScreenState HERE

// -------------------------------------------------------------------------
// 🛠️ UNIVERSAL IMAGE HELPER
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

    if (cleanPath.isEmpty) {
      return _buildLocalFallback();
    }

    if (cleanPath.startsWith('http')) {
      return Image.network(
        cleanPath,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          debugPrint("❌ Network Image Failed: $error");
          return _buildLocalFallback();
        },
      );
    }

    return Image.asset(
      cleanPath,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        debugPrint("❌ Asset Image Failed: $error");
        return _buildLocalFallback();
      },
    );
  }

  Widget _buildLocalFallback() {
    return Container(
      height: height,
      width: width,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary, // Vibrant Blue
            Color(0xFF8B5CF6), // Purple
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.local_parking_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "TechXPark",
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------------
// 🛠️ ANIMATED QUICK ACTION CARD
// -------------------------------------------------------------------------
class QuickActionCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final Widget? target;
  final VoidCallback? onTap;
  final bool isHighlighted;

  final int? badgeCount;

  const QuickActionCard({
    super.key,
    required this.title,
    required this.icon,
    this.target,
    this.onTap,
    this.isHighlighted = false,
    this.badgeCount,
  });

  @override
  State<QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<QuickActionCard> with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Premium Colors logic
    final bgColor = widget.isHighlighted ? AppColors.primary : Colors.white;
    final iconColor = widget.isHighlighted ? Colors.white : AppColors.primary;
    final iconBgColor = widget.isHighlighted 
        ? Colors.white.withOpacity(0.2) 
        : AppColors.primary.withOpacity(0.1);
    final borderColor = widget.isHighlighted 
        ? AppColors.primary 
        : AppColors.primary.withOpacity(0.05);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        HapticFeedback.lightImpact();
        if (widget.onTap != null) {
          widget.onTap!();
        } else if (widget.target != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => widget.target!));
        }
      },
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: (widget.isHighlighted ? AppColors.primary : Colors.black)
                    .withOpacity(_isPressed ? 0.04 : 0.08),
                blurRadius: _isPressed ? 10 : 20,
                offset: Offset(0, _isPressed ? 4 : 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(widget.icon, color: iconColor, size: 24),
                  ),
                  const Spacer(),
                  Text(
                    widget.title,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: widget.isHighlighted ? Colors.white : AppColors.textPrimaryLight,
                    ),
                  ),
                  if (widget.isHighlighted) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 6, 
                          height: 6, 
                          decoration: BoxDecoration(
                            color: Colors.white, 
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.white.withOpacity(0.5), blurRadius: 4)
                            ]
                          )
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "In Progress", 
                          style: TextStyle(
                            fontSize: 11, 
                            color: Colors.white70, 
                            fontWeight: FontWeight.bold
                          )
                        ),
                      ],
                    ),
                  ]
                ],
              ),
              if (widget.badgeCount != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Center(
                      child: Text(
                        widget.badgeCount! > 9 ? '9+' : '${widget.badgeCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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
}

// -------------------------------------------------------------------------
// 🚀 PREMIUM FINTECH MICRO-INTERACTIONS
// -------------------------------------------------------------------------

/// A button that smoothly scales down when pressed (Apple style)
class _AnimatedScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const _AnimatedScaleButton({required this.child, required this.onPressed});

  @override
  State<_AnimatedScaleButton> createState() => _AnimatedScaleButtonState();
}

class _AnimatedScaleButtonState extends State<_AnimatedScaleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// An icon wrapper that naturally floats/bounces lightly
class _AnimatedBounceIcon extends StatefulWidget {
  final Widget child;
  const _AnimatedBounceIcon({required this.child});

  @override
  State<_AnimatedBounceIcon> createState() => _AnimatedBounceIconState();
}

class _AnimatedBounceIconState extends State<_AnimatedBounceIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -3.0, end: 3.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
