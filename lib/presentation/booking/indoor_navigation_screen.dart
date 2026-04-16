import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'painters/parking_map_config.dart';
import 'painters/parking_basement_painter.dart'; // NEW MODULAR PAINTER
import 'painters/floor_painter.dart';
import 'painters/infrastructure_painter.dart';

/// Premium Indoor Parking Navigation Screen.
///
/// Renders a realistic top-down basement parking map using CustomPainter:
/// - Concrete floor texture, lane markings, direction arrows
/// - Pillars, walls, entry/exit gates, ramp indicators
/// - Slot bays with white boundary lines and status colors
/// - Animated driving path from entry → booked slot
/// - Moving vehicle dot along the path
/// - Direction instruction bar at bottom
/// - Multi-floor selector, zoom/pan via InteractiveViewer
class IndoorNavigationScreen extends StatefulWidget {
  final String parkingId;
  final String parkingName;
  final String bookedSlotId;
  final int bookedFloor;

  const IndoorNavigationScreen({
    super.key,
    required this.parkingId,
    required this.parkingName,
    required this.bookedSlotId,
    required this.bookedFloor,
  });

  @override
  State<IndoorNavigationScreen> createState() => _IndoorNavigationScreenState();
}

class _IndoorNavigationScreenState extends State<IndoorNavigationScreen>
    with TickerProviderStateMixin {
  // State
  int _selectedFloor = 0;
  List<Map<String, dynamic>> _slots = [];
  bool _loading = true;
  int _totalFloors = 1;

  // Animations
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _pathController;
  late Animation<double> _pathAnim;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late AnimationController _vehicleController;

  final TransformationController _transformController =
      TransformationController();

  // Real-time tracking overlay
  Map<String, String> _previousStateMap = {};

  // Layout constants
  static const double _mapW = 800;
  static const double _mapH = 600;

  @override
  void initState() {
    super.initState();
    _selectedFloor = widget.bookedFloor;

    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _pathController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..forward();
    _pathAnim = CurvedAnimation(parent: _pathController, curve: Curves.easeInOut);

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _vehicleController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();

    _loadSlots();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pathController.dispose();
    _fadeController.dispose();
    _vehicleController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  // Stream Subscription for real-time slot updates
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _slotsStream;

  Future<void> _loadSlots() async {
    _slotsStream = FirebaseFirestore.instance
        .collection('parking_locations')
        .doc(widget.parkingId)
        .collection('slots')
        .snapshots();

    _slotsStream.listen((snap) {
      final slots = snap.docs.map((doc) {
        final d = doc.data();
        d['id'] = doc.id;
        return d;
      }).toList();

      int maxFloor = 0;
      for (final s in slots) {
        final f = (s['floor'] as num?)?.toInt() ?? 0;
        if (f > maxFloor) maxFloor = f;
      }

      // Check for state changes to show toasts
      if (_previousStateMap.isNotEmpty && mounted) {
         for (final s in slots) {
            final id = s['id'] as String;
            final prevStatus = _previousStateMap[id];
            final currStatus = s['status'] as String? ?? 'available';
            
            if (prevStatus != null && prevStatus != currStatus) {
               // Status changed!
               if (currStatus == 'available') {
                  final slotNum = s['slotNumber'] ?? id;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 12),
                          Text('Slot $slotNum just became available!'),
                        ],
                      ),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      duration: const Duration(seconds: 4),
                    ),
                  );
               }
            }
         }
      }

      // Update snapshot cache
      final newMap = <String, String>{};
      for (final s in slots) {
         newMap[s['id'] as String] = s['status'] as String? ?? 'available';
      }
      _previousStateMap = newMap;

      if (mounted) {
        setState(() {
          _slots = slots;
          _totalFloors = maxFloor + 1;
          _loading = false;
        });
      }
    });
  }

  List<Map<String, dynamic>> get _currentFloorSlots =>
      _slots.where((s) => (s['floor'] as num?)?.toInt() == _selectedFloor).toList();

  // Direction instruction
  String get _directionHint {
    final progress = _pathAnim.value;
    if (progress < 0.25) return '↓  Enter and go straight 20m';
    if (progress < 0.5) return '→  Turn right at Lane B';
    if (progress < 0.75) return '↑  Continue straight 15m';
    if (progress < 0.95) return '←  Your slot is on the left';
    return '🅿️  You have arrived — Slot ${widget.bookedSlotId}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark, // Deep slate background
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.info, strokeWidth: 2))
          : FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  _buildLegend(),
                  _buildFloorSelector(),
                  Expanded(
                    child: Stack(
                      children: [
                        _buildMapViewer(),
                        _buildSearchBar(),
                        _buildBottomActions(),
                        _buildMiniMap(),
                      ],
                    ),
                  ),
                  _buildDirectionBar(),
                ],
              ),
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  APP BAR
  // ═══════════════════════════════════════════════════════════════════════════

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surfaceDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textPrimaryDark, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Indoor Navigation',
                  style: AppTextStyles.h2.copyWith(color: AppColors.textPrimaryDark, fontSize: 16)),
              const SizedBox(width: 8),
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.2 + (_pulseAnim.value * 0.8)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 4, height: 4,
                        decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 4)]),
                      ),
                      const SizedBox(width: 4),
                      const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Text(widget.parkingName,
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryDark)),
        ],
      ),
      actions: [
        // Search icon removed since we now have the inline Search Bar
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  TOP SEARCH BAR
  // ═══════════════════════════════════════════════════════════════════════════

  final TextEditingController _searchController = TextEditingController();
  int? _highlightedSlotIdx;

  void _searchSlot(String query) {
    if (query.isEmpty) return;
    
    final lower = query.toLowerCase();
    final idx = _currentFloorSlots.indexWhere((s) {
       final id = (s['id'] as String?)?.toLowerCase() ?? '';
       final num = (s['slotNumber'] as String?)?.toLowerCase() ?? '';
       return id == lower || num == lower;
    });

    if (idx >= 0) {
      setState(() => _highlightedSlotIdx = idx);
      
      // Fly to animation
      // We use the matrix from the InteractiveViewer controller
      final pos = SlotLayoutHelper(_currentFloorSlots.length).slotCenter(idx);
      final targetScale = 2.5;
      
      // Screen center approx
      final sw = MediaQuery.of(context).size.width;
      final sh = MediaQuery.of(context).size.height * 0.5;

      final dx = sw / 2 - pos.dx * targetScale;
      final dy = sh / 2 - pos.dy * targetScale;
      
      final m = Matrix4.identity()
        ..translate(dx, dy)
        ..scale(targetScale);
        
      _transformController.value = m;
      HapticFeedback.lightImpact();

      // Clear highlight after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _highlightedSlotIdx == idx) {
          setState(() => _highlightedSlotIdx = null);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Slot $query not found on this level.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        )
      );
    }
  }

  Widget _buildSearchBar() {
    return Positioned(
      top: 16, left: 16, right: 16,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surfaceDark.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 4)),
          ]
        ),
        child: TextField(
          controller: _searchController,
          style: AppTextStyles.body1.copyWith(color: AppColors.textPrimaryDark),
          textInputAction: TextInputAction.search,
          onSubmitted: _searchSlot,
          decoration: InputDecoration(
            hintText: 'Search for a slot...',
            hintStyle: AppTextStyles.body1.copyWith(color: AppColors.textSecondaryDark),
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondaryDark),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondaryDark, size: 20),
              onPressed: () {
                _searchController.clear();
                setState(() => _highlightedSlotIdx = null);
              },
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MINI MAP THUMBNAIL
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMiniMap() {
    return Positioned(
      top: 84, // Below search bar
      right: 16,
      child: Container(
        width: 100,
        height: 75,
        decoration: BoxDecoration(
          color: AppColors.bgDark.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24, width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: IgnorePointer(
          child: CustomPaint(
             size: const Size(100, 75),
             painter: _MiniMapPainter(_currentFloorSlots),
          ),
        ),
      ),
    );
  }
  // ═══════════════════════════════════════════════════════════════════════════
  //  FLOOR SELECTOR PILLS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFloorSelector() {
    return Container(
      height: 60,
      width: double.infinity,
      color: AppColors.surfaceDark,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        scrollDirection: Axis.horizontal,
        itemCount: _totalFloors,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final isSelected = _selectedFloor == i;
          final isBooked = widget.bookedFloor == i;
          
          Color bgColor = isSelected ? AppColors.info : AppColors.bgDark;
          Color textColor = isSelected ? Colors.white : AppColors.textSecondaryDark;
          
          if (isBooked && !isSelected) {
             bgColor = AppColors.info.withValues(alpha: 0.15);
             textColor = AppColors.info;
          }

          return GestureDetector(
            onTap: () {
              if (!isSelected) {
                setState(() => _selectedFloor = i);
                _pathController.reset();
                _pathController.forward();
                HapticFeedback.selectionClick();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.transparent : AppColors.borderDark,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   if (isBooked) ...[
                     Icon(Icons.star_rounded, size: 14, color: isSelected ? Colors.white : AppColors.warning),
                     const SizedBox(width: 4),
                   ],
                   Text(
                     'Level ${i + 1}',
                     style: AppTextStyles.body2SemiBold.copyWith(color: textColor),
                   ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  LEGEND
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: AppColors.surfaceDark,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _legendDot(AppColors.success, 'Available'),
          _legendDot(AppColors.error, 'Occupied'),
          _legendDot(AppColors.info, 'Your Slot'),
          _legendDot(AppColors.warning, 'Reserved'),
          _legendDot(AppColors.textSecondaryDark, 'Blocked'),
        ],
      ),
    );
  }

  Widget _legendDot(Color c, String label) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
      ),
      const SizedBox(width: 4),
      Text(label,
          style: AppTextStyles.captionBold.copyWith(color: AppColors.textSecondaryDark, fontSize: 10, fontWeight: FontWeight.normal)),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MAP VIEWER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMapViewer() {
    return InteractiveViewer(
      transformationController: _transformController,
      minScale: 0.4,
      maxScale: 5.0,
      boundaryMargin: const EdgeInsets.all(200),
      child: Center(
        child: SizedBox(
          width: _mapW,
          height: _mapH,
          child: Stack(
            children: [
              // Static Floor Layer (Never Repaints)
              RepaintBoundary(
                child: CustomPaint(
                  size: const Size(_mapW, _mapH),
                  painter: _StaticFloorBackgroundPainter(),
                ),
              ),
              // Dynamic Slots & Animated Layers
              AnimatedBuilder(
                animation: Listenable.merge([_pulseAnim, _pathAnim, _vehicleController]),
                builder: (_, __) => CustomPaint(
                  size: const Size(_mapW, _mapH),
                  painter: ParkingBasementPainter(
                    slots: _currentFloorSlots,
                    bookedSlotId: widget.bookedSlotId,
                    isBookedFloor: _selectedFloor == widget.bookedFloor,
                    pulseValue: _pulseAnim.value,
                    pathProgress: _pathAnim.value,
                    vehiclePhase: _vehicleController.value,
                    skipStaticLayers: true, // Tell the main painter to skip floor and infra
                  ),
                  child: _buildSlotOverlays(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Overlay widgets for slot labels and the "YOUR SLOT" badge.
  Widget _buildSlotOverlays() {
    final slots = _currentFloorSlots;
    final layout = SlotLayoutHelper(slots.length);
    final isBookedFloor = _selectedFloor == widget.bookedFloor;

    return Stack(
      children: [
        for (int i = 0; i < slots.length; i++) ...[
          () {
            final pos = layout.slotRect(i);
            
            // --- VIRTUALIZATION ---
            // Only draw slot overlays that are visible in the viewport
            final viewport = _transformController.value.clone()..invert();
            final screenRect = Rect.fromLTWH(
               viewport.getTranslation().x,
               viewport.getTranslation().y,
               MediaQuery.of(context).size.width * viewport.getMaxScaleOnAxis(),
               MediaQuery.of(context).size.height * viewport.getMaxScaleOnAxis(),
            ).inflate(100); // 100px overdraw margin
            
            if (!screenRect.overlaps(pos)) {
               return const SizedBox.shrink();
            }
            // ----------------------

            final slot = slots[i];
            final isBooked = slot['id'] == widget.bookedSlotId && isBookedFloor;
            final isHighlighted = _highlightedSlotIdx == i;
            final slotNum = slot['slotNumber'] ?? slot['id'] ?? '${i + 1}';

            return Positioned(
              left: pos.left,
              top: pos.top,
              width: pos.width,
              height: pos.height,
              child: Semantics(
                label: isBooked
                    ? 'Your booked slot $slotNum'
                    : 'Slot $slotNum',
                button: true,
                onTapHint: 'View slot details',
                child: GestureDetector(
                  onTap: () {
                     HapticFeedback.lightImpact();
                     _showSlotDetails(slot);
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Golden Highlight Glow for Search Matches
                      if (isHighlighted)
                        Positioned.fill(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBBF24).withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFFFBBF24).withValues(alpha: 0.6), blurRadius: 12),
                              ],
                            ),
                          ),
                        ),
                      Center(
                         // Increase tap target size globally for accessibility
                        child: Container(
                          width: double.infinity, height: double.infinity,
                          color: Colors.transparent, // expand hit area
                          alignment: Alignment.center,
                          child: Text(
                            '$slotNum',
                            style: AppTextStyles.captionBold.copyWith(
                              color: isBooked ? Colors.white : Colors.white.withValues(alpha: 0.6),
                              fontSize: isBooked ? 10 : 8,
                              fontWeight: isBooked ? FontWeight.w800 : FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }(),
        ],

        // YOUR SLOT badge
        if (isBookedFloor) ...[
          () {
            final bookedIdx = slots.indexWhere((s) => s['id'] == widget.bookedSlotId);
            if (bookedIdx < 0) return const SizedBox.shrink();
            final pos = SlotLayoutHelper(slots.length).slotRect(bookedIdx);
            return Positioned(
              left: pos.left - 4,
              top: pos.top - 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.info,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.info.withValues(alpha: 0.4),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: const Text('⭐ YOUR SLOT',
                    style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              ),
            );
          }(),
        ],

        // ENTRY label
        Positioned(
          left: _mapW / 2 - 28,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.login_rounded, color: Colors.white, size: 10),
              SizedBox(width: 3),
              Text('ENTRY', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),

        // EXIT label
        Positioned(
          right: 14,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.logout_rounded, color: Colors.white, size: 10),
              SizedBox(width: 3),
              Text('EXIT', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DIRECTION BAR
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  //  PREMIUM DIRECTION BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDirectionBar() {
    final isBookedFloor = _selectedFloor == widget.bookedFloor;

    return AnimatedBuilder(
      animation: _pathAnim,
      builder: (_, __) {
        final progress = _pathAnim.value;
        final isArrived = progress >= 0.98;

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5), 
                blurRadius: 24, 
                offset: const Offset(0, -8)
              )
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                if (isBookedFloor) ...[
                  // Primary Status Header
                  Row(
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: isArrived ? AppColors.success.withValues(alpha: 0.15) : AppColors.info.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          isArrived ? Icons.check_circle_rounded : Icons.navigation_rounded,
                          color: isArrived ? AppColors.success : AppColors.info, 
                          size: 24
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArrived ? 'Destination Reached' : 'Heading to Slot ${widget.bookedSlotId}',
                              style: AppTextStyles.h3.copyWith(color: AppColors.textPrimaryDark, fontSize: 18),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isArrived ? 'You may park your vehicle.' : 'ETA ${(30 * (1 - progress)).round()} sec • ${(120 * (1 - progress)).round()}m',
                              style: AppTextStyles.body2.copyWith(
                                color: isArrived ? AppColors.success : AppColors.info,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Circular Progress
                      if (!isArrived)
                        SizedBox(
                          width: 48, height: 48,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 4,
                                backgroundColor: Colors.white12,
                                valueColor: const AlwaysStoppedAnimation(AppColors.info),
                              ),
                              Center(
                                child: Text('${(progress * 100).toInt()}%', 
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Route Steps (Upcoming)
                  if (!isArrived) ...[
                    const SizedBox(height: 24),
                    _buildRouteStep(
                      icon: Icons.straight_rounded,
                      title: 'Continue straight on Entry Lane',
                      distance: '${(60 * (1 - progress)).round()}m',
                      isActive: progress < 0.4,
                      isDone: progress >= 0.4,
                    ),
                    _buildRouteStep(
                      icon: Icons.turn_right_rounded,
                      title: 'Turn right into Lane B',
                      distance: '${(40 * (1 - progress)).clamp(0, 40).round()}m',
                      isActive: progress >= 0.4 && progress < 0.8,
                      isDone: progress >= 0.8,
                    ),
                    _buildRouteStep(
                      icon: Icons.turn_left_rounded,
                      title: 'Your slot is on the left',
                      distance: '${(20 * (1 - progress)).clamp(0, 20).round()}m',
                      isActive: progress >= 0.8,
                      isDone: false,
                      isLast: true,
                    ),
                  ],

                  // Actions
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                             _pathController.reset();
                             _pathController.forward();
                             HapticFeedback.mediumImpact();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Recalculate'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimaryDark,
                            side: const BorderSide(color: Colors.white24),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.share_location_rounded, size: 18),
                          label: const Text('Share Route'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),

                ] else ...[
                  // Wrong Floor Warning State
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Wrong Floor', style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold, color: AppColors.warning)),
                              const SizedBox(height: 2),
                              Text('Your booked slot is on Level ${widget.bookedFloor + 1}.',
                                  style: AppTextStyles.body2.copyWith(color: AppColors.textSecondaryDark)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _selectedFloor = widget.bookedFloor);
                            _pathController.reset();
                            _pathController.forward();
                            HapticFeedback.selectionClick();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warning,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Go to Floor', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRouteStep({
    required IconData icon,
    required String title,
    required String distance,
    required bool isActive,
    required bool isDone,
    bool isLast = false,
  }) {
    final color = isDone ? AppColors.textSecondaryDark : (isActive ? AppColors.textPrimaryDark : Colors.white38);
    final iconColor = isDone ? AppColors.success : (isActive ? AppColors.info : Colors.white38);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline timeline
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Icon(isDone ? Icons.check_circle_rounded : icon, color: iconColor, size: 20),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isDone ? AppColors.success : Colors.white12,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: AppTextStyles.body2SemiBold.copyWith(color: color)),
                  if (!isDone && isActive)
                    Text(distance, style: AppTextStyles.captionBold.copyWith(color: AppColors.info)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BOTTOM ACTIONS (AR VIEW, REPORT, CALL)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildBottomActions() {
    return Positioned(
      right: 16,
      bottom: 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMapAction(Icons.view_in_ar_rounded, 'AR View', AppColors.primary),
          const SizedBox(height: 12),
          _buildMapAction(Icons.report_problem_outlined, 'Report', AppColors.textPrimaryDark),
          const SizedBox(height: 12),
          _buildMapAction(Icons.support_agent_rounded, 'Call', AppColors.textPrimaryDark),
        ],
      ),
    );
  }

  Widget _buildMapAction(IconData icon, String label, Color color) {
    return GestureDetector(
      onTap: () => HapticFeedback.lightImpact(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  //  SLOT DETAILS BOTTOM SHEET
  // ═══════════════════════════════════════════════════════════════════════════

  void _showSlotDetails(Map<String, dynamic> slot) {
    final status = slot['status'] as String? ?? 'available';
    final slotNum = slot['slotNumber'] ?? slot['id'] ?? 'Unknown';
    final type = slot['type'] ?? 'car';
    final isBooked = slot['id'] == widget.bookedSlotId && _selectedFloor == widget.bookedFloor;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Slot $slotNum', style: AppTextStyles.h2.copyWith(color: AppColors.textPrimaryDark)),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isBooked ? AppColors.info.withValues(alpha: 0.15) : (status == 'available' ? AppColors.success.withValues(alpha: 0.15) : AppColors.error.withValues(alpha: 0.15)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                isBooked ? 'YOUR SLOT' : status.toUpperCase(),
                                style: TextStyle(
                                  color: isBooked ? AppColors.info : (status == 'available' ? AppColors.success : AppColors.error),
                                  fontSize: 10, fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Level ${_selectedFloor + 1} • ${type.toString().toUpperCase()} Parking', style: AppTextStyles.body2.copyWith(color: AppColors.textSecondaryDark)),
                      ],
                    ),
                    if (status == 'available')
                       Text('\$2/hr', style: AppTextStyles.h3.copyWith(color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Features', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondaryDark)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _featureBadge(Icons.videocam_rounded, 'CCTV'),
                              const SizedBox(width: 8),
                              _featureBadge(Icons.local_police_rounded, 'Secured'),
                              const SizedBox(width: 8),
                              if (type == 'ev') _featureBadge(Icons.bolt_rounded, 'Charging'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (status == 'available') {
                      // Trigger new booking flow (mocked)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Starting booking flow...')));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBooked ? AppColors.info : (status == 'available' ? AppColors.primary : AppColors.surfaceLight),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    isBooked ? 'Manage Booking' : (status == 'available' ? 'Book Slot Now' : 'Notify When Available'),
                    style: TextStyle(
                      color: isBooked || status == 'available' ? Colors.white : AppColors.textSecondaryDark,
                      fontWeight: FontWeight.bold, fontSize: 16
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _featureBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textSecondaryDark, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MINI MAP PAINTER
// ═══════════════════════════════════════════════════════════════════════════

class _MiniMapPainter extends CustomPainter {
  final List<Map<String, dynamic>> slots;

  _MiniMapPainter(this.slots);

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / ParkingMapConfig.mapW;
    final scaleY = size.height / ParkingMapConfig.mapH;
    
    final floorRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(floorRect, Paint()..color = const Color(0xFF1E293B));
    
    final wallPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(floorRect.deflate(2), wallPaint);

    final availPaint = Paint()..color = AppColors.success;
    final occPaint = Paint()..color = AppColors.error;
    
    final layout = SlotLayoutHelper(slots.length);
    for (int i = 0; i < slots.length; i++) {
       final realRect = layout.slotRect(i);
       final miniRect = Rect.fromLTWH(
          realRect.left * scaleX, 
          realRect.top * scaleY, 
          realRect.width * scaleX, 
          realRect.height * scaleY
       );
       
       final isAvail = slots[i]['status'] == 'available';
       canvas.drawRect(miniRect, isAvail ? availPaint : occPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) => true;
}

// ═══════════════════════════════════════════════════════════════════════════
//  STATIC FLOOR BACKGROUND PAINTER
// ═══════════════════════════════════════════════════════════════════════════

class _StaticFloorBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    FloorPainter.drawFloor(canvas, size); // Generic floor paint
    InfrastructurePainter.drawInfrastructure(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


