import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../services/booking_helper.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

import 'confirm_booking_screen.dart';
import 'my_bookings_screen.dart';

enum SlotSelectionMode { auto, manual }

class SlotSelectionScreen extends StatefulWidget {
  final String parkingId;
  final Map<String, dynamic> parking;
  final DateTime start;
  final DateTime end;
  final Map<String, dynamic> vehicle;

  const SlotSelectionScreen({
    super.key,
    required this.parkingId,
    required this.parking,
    required this.start,
    required this.end,
    required this.vehicle,
  });

  @override
  State<SlotSelectionScreen> createState() => _SlotSelectionScreenState();
}

class _SlotSelectionScreenState extends State<SlotSelectionScreen> {
  int selectedFloorIndex = 0;
  String? selectedSlotId;
  SlotSelectionMode mode = SlotSelectionMode.manual;

  bool _bookingLimitReached = false;

  @override
  void initState() {
    super.initState();
    _checkBookingLimit();
  }

  Future<void> _checkBookingLimit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final limitReached = await hasReachedBookingLimit(uid);
      if (limitReached && mounted) {
        setState(() => _bookingLimitReached = true);
      }
    }
  }

  // --- Auto Select State ---
  bool _prefClosest = true;
  bool _prefEV = false;
  bool _prefDisabled = false;
  bool _prefCovered = true;
  bool _prefLower = true;

  bool _isScanning = false;
  int _scanPhase = 0;
  Map<String, dynamic>? _foundSlot;
  int? _foundSlotFloor;
  String _foundSlotReason = "";
  final List<String> _ignoredSlotIds = [];

  // --- Manual Mode Search & Filter ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _selectedFilter = "All"; // "All", "Available", "EV", "Disabled", "Near Entry"

  // 🛣️ Map Specific Colors (Light Concrete Theme)
  final Color _asphaltColor = const Color(0xFFF1F5F9); // Light Concrete
  final Color _parkingLineColor = const Color(0xFFCBD5E1); // Slate 300 for lines

  /// 🔥 LIVE SENSOR SLOT
  final DatabaseReference _sensorRef =
      FirebaseDatabase.instance.ref("sensor_slots/F1A04");

  /// 🔹 FIRESTORE SLOT STREAM
  Stream<QuerySnapshot> _slotStream(int floorIndex) {
    return FirebaseFirestore.instance
        .collection("parking_locations")
        .doc(widget.parkingId)
        .collection("slots")
        .where("floor", isEqualTo: floorIndex)
        .snapshots();
  }

  Future<void> _startAutoScan() async {
    setState(() {
      _isScanning = true;
      _scanPhase = 0;
      _foundSlot = null;
    });

    for(int i=1; i<=4; i++) {
       await Future.delayed(const Duration(milliseconds: 600));
       if (mounted) setState(() => _scanPhase = i);
    }
    
    await _handleAutoSelect();
    
    if (mounted) {
       setState(() {
          _isScanning = false;
       });
    }
  }

  /// 🤖 AUTO SLOT ASSIGNMENT SCORING ENGINE
  Future<void> _handleAutoSelect() async {
    HapticFeedback.mediumImpact();
    final totalFloors = widget.parking['total_floors'] ?? 1;

    Map<String, dynamic>? bestSlot;
    int? bestFloor;
    int highestScore = -1;

    for (int floorIndex = 0; floorIndex < totalFloors; floorIndex++) {
      final slotsSnap = await FirebaseFirestore.instance
          .collection("parking_locations")
          .doc(widget.parkingId)
          .collection("slots")
          .where("floor", isEqualTo: floorIndex)
          .get();

      for (final slot in slotsSnap.docs) {
        final slotId = slot.id;
        
        if (_ignoredSlotIds.contains(slotId)) continue; // Skip if rejected

        final data = slot.data();
        bool taken = data["taken"] == true;

        // 🔥 Override using sensor for live slot
        if (slotId == "F1A04") {
          final sensorSnap = await _sensorRef.get();
          if (sensorSnap.exists && sensorSnap.value != null) {
            try {
              final val = sensorSnap.value;
              if (val is Map) taken = val['taken'] == true;
              else if (val is bool) taken = val;
            } catch (_) {}
          }
        }

        if (!taken) {
           int score = 0;
           final type = data['type'] ?? 'car';
           final isCovered = data['covered'] ?? true;
           // Assume numerical distance or fallback to a default
           final rawDist = data['distance_to_entrance'];
           final distance = (rawDist is num) ? rawDist.toInt() : 50;

           // + 30 points: closest to entrance
           int distScore = 30 - math.min(30, (distance / 5).floor());
           if (_prefClosest) score += distScore;

           // + 20 points: matches EV preference
           if (_prefEV && type == 'ev') score += 20;
           else if (!_prefEV && type == 'ev') score -= 50; // Heavy penalty if taking an EV spot without needing it
           else if (type != 'ev') score += 5; // Standard car in normal spot

           // + 20 points: matches floor preference
           if (_prefLower && floorIndex <= 1) score += 20;

           // + 15 points: covered
           if (_prefCovered && isCovered) score += 15;

           // + 15 points: disabled access
           if (_prefDisabled && type == 'disabled') score += 15;
           else if (!_prefDisabled && type == 'disabled') score -= 50; // Heavy penalty taking disabled spot

           if (score > highestScore) {
              highestScore = score;
              bestSlot = data;
              bestSlot['id'] = slotId;
              bestFloor = floorIndex;
           }
        }
      }
    }

    if (bestSlot != null) {
      _foundSlot = bestSlot;
      _foundSlotFloor = bestFloor;
      
      List<String> reasons = [];
      if (_prefClosest) reasons.add("Closest available to entrance");
      if (_prefEV && bestSlot['type'] == 'ev') reasons.add("Matches your EV preference");
      if (_prefLower && bestFloor! <= 1) reasons.add("Located on lower level");
      if (_prefCovered && (bestSlot['covered'] ?? true)) reasons.add("Covered parking spot");
      if (_prefDisabled && bestSlot['type'] == 'disabled') reasons.add("Accessible parking spot");
      if (reasons.isEmpty) reasons.add("Best overall spot right now");
      
      _foundSlotReason = reasons.join("|");
    } else {
       _foundSlot = null;
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
           content: const Text("❌ No available slots matching criteria"),
           backgroundColor: AppColors.error,
           behavior: SnackBarBehavior.floating,
         ));
       }
    }
  }

  /// ✅ NAVIGATE TO CONFIRM BOOKING
  void _navigateToConfirmBooking(String slotId, int floorIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmBookingScreen(
          parking: widget.parking,
          parkingId: widget.parkingId,
          selectedSlot: slotId,
          floorIndex: floorIndex,
          start: widget.start,
          end: widget.end,
          vehicle: widget.vehicle,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 70,
        leading: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.bgLight,
            shape: BoxShape.circle,
          ),
          child: const BackButton(color: AppColors.textPrimaryLight),
        ),
        title: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection("parking_locations")
              .doc(widget.parkingId)
              .collection("slots")
              .where("taken", isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            int availableCount = 0;
            if (snapshot.hasData) {
              availableCount = snapshot.data!.docs.length;
            }
            final parkingName = widget.parking['name'] ?? 'Parking Lot';
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_bookingLimitReached) _buildLimitBanner(),
                Text("Choose Your Spot",
                    style: AppTextStyles.h3.copyWith(color: AppColors.textPrimaryLight)),
                const SizedBox(height: 2),
                Text(
                  "$parkingName • $availableCount spots free", 
                  style: AppTextStyles.captionBold.copyWith(color: AppColors.primary, fontSize: 12)
                ),
              ],
            );
          },
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: AppColors.bgLight,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.info_outline_rounded, color: AppColors.primary),
              onPressed: _showLotInfo,
            ),
          )
        ],
      ),
      body: Column(
        children: [
          _buildTopControls(),
          if (mode == SlotSelectionMode.auto)
            _buildAutoModeUI()
          else
            _buildRealisticMapGrid(), 
          
          if (mode == SlotSelectionMode.manual) _buildBottomAction(),
        ],
      ),
    );
  }

  void _showLotInfo() {
    // Show lot details in a bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: AppColors.borderLight, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text(widget.parking['name'] ?? 'Parking Info', style: AppTextStyles.h2),
              const SizedBox(height: 12),
              Text(widget.parking['address'] ?? 'Address not available', style: AppTextStyles.body2),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.access_time_rounded, color: AppColors.success, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text("Open 24/7", style: AppTextStyles.body2SemiBold),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= UI SECTIONS =================

  Widget _buildTopControls() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.only(bottom: 32, top: 16),
      child: Column(
        children: [
          _buildPremiumModeToggle(),
          if (mode == SlotSelectionMode.manual) ...[
            const SizedBox(height: 24),
            _buildFloorSelector(),
            const SizedBox(height: 16),
            _buildSearchAndFilter(),
            const SizedBox(height: 16),
            _buildLegend(),
          ]
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendItem(AppColors.success, "Available"),
        const SizedBox(width: 20),
        _legendItem(AppColors.error, "Occupied"),
        const SizedBox(width: 20),
        _legendItem(AppColors.primary, "Selected"),
      ],
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color, 
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 4)]
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTextStyles.captionBold,
        ),
      ],
    );
  }

  Widget _buildPremiumModeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(child: _premiumModeCard(SlotSelectionMode.auto, "Auto Select", "We pick the best spot", Icons.auto_awesome_rounded)),
          const SizedBox(width: 16),
          Expanded(child: _premiumModeCard(SlotSelectionMode.manual, "Manual", "Choose your own", Icons.map_rounded)),
        ],
      ),
    );
  }

  Widget _premiumModeCard(SlotSelectionMode m, String title, String subtitle, IconData icon) {
    final active = mode == m;
    
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => mode = m);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: active ? LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ) : null,
          color: active ? null : AppColors.bgLight,
          border: Border.all(color: active ? Colors.transparent : AppColors.borderLight),
          boxShadow: active ? [
            BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))
          ] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: active ? Colors.white : AppColors.primary, size: 28),
                if (m == SlotSelectionMode.auto)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.success.withOpacity(active ? 1.0 : 0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text("RECOMMENDED", style: TextStyle(color: active ? Colors.white : AppColors.success, fontSize: 8, fontWeight: FontWeight.bold)),
                  )
              ],
            ),
            const SizedBox(height: 16),
            Text(title, style: AppTextStyles.body1Bold.copyWith(color: active ? Colors.white : AppColors.textPrimaryLight)),
            const SizedBox(height: 4),
            Text(subtitle, style: AppTextStyles.caption.copyWith(color: active ? Colors.white.withOpacity(0.8) : AppColors.textSecondaryLight, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.bgLight,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.trim().toUpperCase()),
              style: AppTextStyles.body2SemiBold,
              decoration: InputDecoration(
                hintText: "Search slot (e.g. F1A04)",
                hintStyle: AppTextStyles.body2,
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondaryLight),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondaryLight, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        },
                      )
                    : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: [
              _filterChip("All"),
              _filterChip("Available"),
              _filterChip("EV"),
              _filterChip("Disabled"),
              _filterChip("Near Entry"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filterChip(String label) {
    final active = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = label);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? AppColors.primary : AppColors.borderLight),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.captionBold.copyWith(
              color: active ? Colors.white : AppColors.textSecondaryLight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloorSelector() {
    return SizedBox(
      height: 64,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: widget.parking['total_floors'] ?? 1,
        itemBuilder: (_, index) {
          final isSelected = selectedFloorIndex == index;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                selectedFloorIndex = index;
                selectedSlotId = null; // Clear selection when switching floors
              });
            },
            child: StreamBuilder<QuerySnapshot>(
              stream: _slotStream(index),
              builder: (context, snapshot) {
                int total = 0;
                int free = 0;
                if (snapshot.hasData) {
                   total = snapshot.data!.docs.length;
                   free = snapshot.data!.docs.where((d) => d['taken'] == false).length;
                }
                
                Color statusColor = free == 0 ? AppColors.error : AppColors.success;
                if (free > 0 && free <= 3) statusColor = AppColors.warning;
                
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.borderLight,
                    ),
                    boxShadow: isSelected 
                      ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] 
                      : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                         children: [
                            Text(
                              "Level ${index + 1}",
                              style: AppTextStyles.captionBold.copyWith(color: isSelected ? Colors.white : AppColors.textPrimaryLight),
                            ),
                            if (free > 0) ...[
                               const SizedBox(width: 8),
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                 decoration: BoxDecoration(color: statusColor.withOpacity(isSelected ? 1.0 : 0.1), borderRadius: BorderRadius.circular(8)),
                                 child: Text("$free free", style: TextStyle(color: isSelected ? Colors.white : statusColor, fontSize: 8, fontWeight: FontWeight.bold)),
                               )
                            ] else ...[
                               const SizedBox(width: 8),
                               Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                 decoration: BoxDecoration(color: AppColors.error.withOpacity(isSelected ? 1.0 : 0.1), borderRadius: BorderRadius.circular(8)),
                                 child: Text("FULL", style: TextStyle(color: isSelected ? Colors.white : AppColors.error, fontSize: 8, fontWeight: FontWeight.bold)),
                               )
                            ]
                         ]
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 80, height: 4,
                        decoration: BoxDecoration(color: isSelected ? Colors.white30 : AppColors.bgLight, borderRadius: BorderRadius.circular(2)),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: total == 0 ? 0 : (total - free) / total,
                          child: Container(decoration: BoxDecoration(color: isSelected ? Colors.white : statusColor, borderRadius: BorderRadius.circular(2))),
                        ),
                      )
                    ],
                  ),
                );
              }
            )
          );
        },
      ),
    );
  }

  Widget _buildAutoModeUI() {
    return Expanded(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
               if (!_isScanning && _foundSlot == null) _buildPreferencesCard(),
               if (_isScanning) _buildScanningRadar(),
               if (!_isScanning && _foundSlot != null) _buildAutoResultCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreferencesCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.tune_rounded, color: AppColors.primary)),
              const SizedBox(width: 16),
              Text("AI Preferences", style: AppTextStyles.h3),
            ],
          ),
          const SizedBox(height: 24),
          _buildPrefToggle("Closest to entrance", Icons.directions_walk_rounded, _prefClosest, (v) => setState(() => _prefClosest = v)),
          _buildPrefToggle("Need EV charging", Icons.electrical_services_rounded, _prefEV, (v) => setState(() => _prefEV = v)),
          _buildPrefToggle("Need disabled access", Icons.accessible_rounded, _prefDisabled, (v) => setState(() => _prefDisabled = v)),
          _buildPrefToggle("Prefer covered spot", Icons.roofing_rounded, _prefCovered, (v) => setState(() => _prefCovered = v)),
          _buildPrefToggle("Prefer lower floor", Icons.arrow_downward_rounded, _prefLower, (v) => setState(() => _prefLower = v)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
               _ignoredSlotIds.clear();
               _startAutoScan();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 20),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 8,
              shadowColor: AppColors.primary.withOpacity(0.4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Text("Find Best Slot", style: AppTextStyles.buttonText.copyWith(color: Colors.white)),
              ],
            ),
          )
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  Widget _buildPrefToggle(String title, IconData icon, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondaryLight),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: AppTextStyles.body2SemiBold)),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningRadar() {
    final List<String> texts = [
      "Scanning available slots...",
      "Checking your preferences...",
      "Finding perfect match...",
      "Almost there...",
      "Finishing up..."
    ];

    return Container(
      margin: const EdgeInsets.only(top: 64),
      child: Center(
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 2)),
                ).animate(onPlay: (controller) => controller.repeat()).scale(begin: const Offset(0.5, 0.5), end: const Offset(1.5, 1.5), duration: 1500.ms).fade(begin: 1.0, end: 0.0),
                Container(
                  width: 160, height: 160,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 2)),
                ).animate(onPlay: (controller) => controller.repeat(reverse: false)).scale(begin: const Offset(0.2, 0.2), end: const Offset(1.2, 1.2), duration: 1500.ms, delay: 500.ms).fade(begin: 1.0, end: 0.0),
                const SizedBox(width: 64, height: 64, child: CircularProgressIndicator(strokeWidth: 4, valueColor: AlwaysStoppedAnimation(AppColors.primary))),
                const Icon(Icons.radar_rounded, color: AppColors.primary, size: 32),
              ],
            ),
            const SizedBox(height: 48),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                texts[math.min(_scanPhase, texts.length - 1)],
                key: ValueKey<int>(_scanPhase),
                style: AppTextStyles.body1.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildAutoResultCard() {
    final slot = _foundSlot!;
    final reasons = _foundSlotReason.split("|");
    final slotFloorStr = widget.parking['floors'][_foundSlotFloor]['name'] ?? "Level ${_foundSlotFloor! + 1}";

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.success.withOpacity(0.3), width: 2),
        boxShadow: [BoxShadow(color: AppColors.success.withOpacity(0.1), blurRadius: 32, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28)),
              const SizedBox(width: 12),
              Text("Perfect Spot Found!", style: AppTextStyles.h3.copyWith(color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.bgLight, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Slot ${slot['id']}", style: AppTextStyles.h1.copyWith(color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Text("$slotFloorStr", style: AppTextStyles.body2SemiBold),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)]),
                  child: Column(
                    children: [
                      const Icon(Icons.directions_walk_rounded, color: AppColors.primary, size: 24),
                      Text("${slot['distance_to_entrance'] ?? 42}m", style: AppTextStyles.captionBold),
                    ],
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text("Why this spot?", style: AppTextStyles.body1Bold),
          const SizedBox(height: 12),
          ...reasons.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.check_rounded, color: AppColors.success, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(r, style: AppTextStyles.body2)),
              ],
            ),
          ).animate().fadeIn(delay: (200 + reasons.indexOf(r) * 150).ms).slideX(begin: 0.1)),
          
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      selectedSlotId = slot['id'];
                      selectedFloorIndex = _foundSlotFloor!;
                      mode = SlotSelectionMode.manual;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("View Map", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _navigateToConfirmBooking(slot['id'], _foundSlotFloor!);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Confirm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
               _ignoredSlotIds.add(slot['id']);
               _startAutoScan();
            },
            child: const Text("Find Another", style: TextStyle(color: AppColors.textSecondaryLight, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    ).animate().slideY(begin: 0.1, duration: 500.ms, curve: Curves.easeOutBack).fadeIn();
  }

  // 🌟 REALISTIC PARKING MAP GRID
  Widget _buildRealisticMapGrid() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        decoration: BoxDecoration(
          color: _asphaltColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 16, offset: const Offset(0, -8))],
          border: Border.all(color: AppColors.borderLight, width: 2),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: Stack(
            children: [
               Positioned.fill(
                 child: CustomPaint(
                   painter: _AsphaltRoadPainter(),
                 ),
               ),
               StreamBuilder<QuerySnapshot>(
                 stream: _slotStream(selectedFloorIndex),
                 builder: (context, slotSnap) {
                   if (!slotSnap.hasData) {
                     return Shimmer.fromColors(
                       baseColor: Colors.black.withOpacity(0.04),
                       highlightColor: Colors.black.withOpacity(0.08),
                       child: GridView.builder(
                         padding: const EdgeInsets.only(left: 32, right: 32, top: 48, bottom: 120),
                         gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 2.2, crossAxisSpacing: 80, mainAxisSpacing: 10),
                         itemCount: 10,
                         itemBuilder: (_, __) => Container(
                           decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                         ),
                       ),
                     );
                   }
             
                   final allDocs = slotSnap.data!.docs;
              
              // Apply search & filter
              final docs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final slotId = doc.id;
                final type = data['type'] ?? 'car';
                final isOccupied = data['taken'] == true;
                final dist = data['distance_to_entrance'];
                final distance = dist is num ? dist.toInt() : 50;
                
                // Search query match
                if (_searchQuery.isNotEmpty && !slotId.toUpperCase().contains(_searchQuery)) {
                  return false;
                }
                
                // Filter chip match
                if (_selectedFilter == "Available" && isOccupied) return false;
                if (_selectedFilter == "EV" && type != "ev") return false;
                if (_selectedFilter == "Disabled" && type != "disabled") return false;
                if (_selectedFilter == "Near Entry" && distance > 25) return false;
                
                return true;
              }).toList();
        
              if (docs.isEmpty) {
                return Center(child: Text("No slots match your search", style: AppTextStyles.body1.copyWith(color: AppColors.textSecondaryLight)));
              }
             
                   return GridView.builder(
                     padding: const EdgeInsets.only(left: 32, right: 32, top: 48, bottom: 120),
                     gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                       crossAxisCount: 2,
                       childAspectRatio: 2.2,
                       crossAxisSpacing: 80,
                       mainAxisSpacing: 10,
                     ),
                     itemCount: docs.length,
                     itemBuilder: (_, idx) {
                       final slot = docs[idx];
                       final slotId = slot.id;
                       final data = slot.data() as Map<String, dynamic>;
             
                       bool occupied = data["taken"] == true;
                       final type = data['type'] ?? 'car';
             
                       if (slotId == "F1A04") {
                         return StreamBuilder<DatabaseEvent>(
                           stream: _sensorRef.onValue,
                           builder: (_, snap) {
                             bool liveOccupied = occupied;
                             if (snap.hasData && snap.data!.snapshot.value != null) {
                               try {
                                 final val = snap.data!.snapshot.value;
                                 if (val is Map) liveOccupied = val['taken'] == true;
                                 else if (val is bool) liveOccupied = val;
                               } catch (_) {}
                             }
                             return _realisticSlotTile(slotId, liveOccupied, type, isSmart: true);
                           },
                         );
                       }
             
                       return _realisticSlotTile(slotId, occupied, type);
                     },
                   );
                 },
               ),
               Positioned(
                 bottom: 0, left: 0, right: 0,
                 height: 80,
                 child: Container(
                   decoration: BoxDecoration(
                     gradient: LinearGradient(colors: [_asphaltColor.withOpacity(0), _asphaltColor], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                   ),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.center,
                     crossAxisAlignment: CrossAxisAlignment.end,
                     children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(color: AppColors.success.withOpacity(0.2), border: Border.all(color: AppColors.success), borderRadius: BorderRadius.circular(8)),
                          child: const Text("↓ ENTRY", style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        ),
                        const SizedBox(width: 32),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(color: AppColors.error.withOpacity(0.2), border: Border.all(color: AppColors.error), borderRadius: BorderRadius.circular(8)),
                          child: const Text("↑ EXIT", style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, letterSpacing: 2)),
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

  // 🌟 REALISTIC SLOT TILE
  Widget _realisticSlotTile(String slotId, bool isOccupied, String type, {bool isSmart = false}) {
    final isSelected = selectedSlotId == slotId;

    Color tintColor = Colors.transparent;
    Widget? typeIcon;
    if (type == 'ev') {
      tintColor = const Color(0xFF10B981).withOpacity(0.1); // Green tinted for EV
      typeIcon = const Icon(Icons.electrical_services_rounded, color: Color(0xFF10B981), size: 16);
    } else if (type == 'disabled') {
      tintColor = const Color(0xFF3B82F6).withOpacity(0.1); // Blue tinted for Disabled
      typeIcon = const Icon(Icons.accessible_rounded, color: Color(0xFF3B82F6), size: 16);
    }
    
    if (isOccupied) tintColor = AppColors.error.withOpacity(0.1);
    if (isSelected) tintColor = AppColors.primary.withOpacity(0.9);

    return GestureDetector(
      onTap: isOccupied ? () {
        HapticFeedback.heavyImpact();
      } : () {
        HapticFeedback.selectionClick();
        setState(() => selectedSlotId = slotId);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: tintColor,
          border: Border.all(color: isSelected ? AppColors.primary : (isOccupied ? AppColors.error.withOpacity(0.3) : _parkingLineColor), width: isSelected ? 3 : 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 4))] : [],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 4,
              child: Text(
                slotId,
                style: AppTextStyles.captionBold.copyWith(
                  fontSize: 10,
                  color: isSelected ? Colors.white : (isOccupied ? AppColors.error : AppColors.textSecondaryLight),
                ),
              ),
            ),
            
            if (typeIcon != null && !isOccupied && !isSelected)
              Positioned(bottom: 4, child: typeIcon),

            if (isOccupied)
              const Icon(Icons.directions_car_filled_rounded, color: AppColors.error, size: 48)
            else if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 32)
                .animate().scale(curve: Curves.easeOutBack)
            else 
              Center(
                child: Text("P", style: AppTextStyles.h3.copyWith(color: AppColors.success.withOpacity(0.6), fontWeight: FontWeight.bold, fontSize: 24)),
              ),

            if (isSmart)
              Positioned(
                top: 4, right: 4,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.redAccent, blurRadius: 4)]),
                ).animate(onPlay: (controller) => controller.repeat(reverse: true)).fade(begin: 1.0, end: 0.2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: selectedSlotId == null 
        ? const SizedBox(width: double.infinity) 
        : Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 32, offset: const Offset(0, -8))],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _bookingLimitReached ? null : () {
                   HapticFeedback.lightImpact();
                   _navigateToConfirmBooking(selectedSlotId!, selectedFloorIndex);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: _bookingLimitReached ? 0 : 8,
                  shadowColor: AppColors.primary.withOpacity(0.4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _bookingLimitReached ? "Booking Limit Reached (3/3)" : "RESERVE $selectedSlotId", 
                      style: AppTextStyles.buttonText.copyWith(color: Colors.white)
                    ),
                    if (!_bookingLimitReached) ...[
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white),
                    ]
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildLimitBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Booking Limit Reached (3/3)',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  )),
                Text('Cancel an existing booking first.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF92400E),
                  )),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MyBookingsScreen())),
            child: const Text('View',
              style: TextStyle(
                color: Color(0xFFF59E0B),
                fontWeight: FontWeight.w800,
              )),
          ),
        ],
      ),
    );
  }
}

class _AsphaltRoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1) // Slate 300 for dashed lines
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Draw dashed center line
    double startY = 30;
    final centerX = size.width / 2;
    while (startY < size.height - 30) {
      canvas.drawLine(Offset(centerX, startY), Offset(centerX, startY + 24), paint);
      startY += 48;
    }

    // Draw directional arrows
    _drawArrow(canvas, Offset(centerX - 35, size.height / 3), false); // Up arrow
    _drawArrow(canvas, Offset(centerX + 35, size.height * 2 / 3), true); // Down arrow
  }

  void _drawArrow(Canvas canvas, Offset center, bool isDown) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1).withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    final path = Path();
    if (isDown) {
      path.moveTo(center.dx, center.dy + 30);
      path.lineTo(center.dx - 15, center.dy);
      path.lineTo(center.dx - 6, center.dy);
      path.lineTo(center.dx - 6, center.dy - 30);
      path.lineTo(center.dx + 6, center.dy - 30);
      path.lineTo(center.dx + 6, center.dy);
      path.lineTo(center.dx + 15, center.dy);
    } else {
      path.moveTo(center.dx, center.dy - 30);
      path.lineTo(center.dx - 15, center.dy);
      path.lineTo(center.dx - 6, center.dy);
      path.lineTo(center.dx - 6, center.dy + 30);
      path.lineTo(center.dx + 6, center.dy + 30);
      path.lineTo(center.dx + 6, center.dy);
      path.lineTo(center.dx + 15, center.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
