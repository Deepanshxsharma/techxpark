import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import 'confirm_booking_screen.dart';

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
  int _selectedFloor = 0;
  String? _selectedSlotId;
  String? _selectedSlotLabel;

  // ── Firebase slot stream ────────────────────────────────────────────
  Stream<QuerySnapshot> _slotStream(int floorIndex) {
    return FirebaseFirestore.instance
        .collection('parking_locations')
        .doc(widget.parkingId)
        .collection('slots')
        .where('floor', isEqualTo: floorIndex)
        .snapshots();
  }

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

  @override
  Widget build(BuildContext context) {
    final lotName = widget.parking['name'] ?? 'Parking Lot';
    final totalFloors = (widget.parking['total_floors'] as num?)?.toInt() ?? 1;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(color: Color(0xFF0D1117)),
        centerTitle: true,
        title: Column(
          children: [
            const Text(
              'Select Slot',
              style: TextStyle(
                color: Color(0xFF0D1117),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              lotName,
              style: const TextStyle(
                color: Color(0xFF9AA5BC),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ═══════════════════════════════════════════════════════
          // FLOOR SELECTOR
          // ═══════════════════════════════════════════════════════
          _buildFloorSelector(totalFloors),

          const SizedBox(height: 12),

          // ═══════════════════════════════════════════════════════
          // LEGEND
          // ═══════════════════════════════════════════════════════
          _buildLegend(),

          const SizedBox(height: 8),

          // ═══════════════════════════════════════════════════════
          // SLOT GRID
          // ═══════════════════════════════════════════════════════
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _slotStream(_selectedFloor),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildShimmerGrid();
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_parking_rounded,
                            size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          'No slots on this floor',
                          style: TextStyle(
                            color: Color(0xFF9AA5BC),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;
                // Sort by slotNumber
                docs.sort((a, b) {
                  final aNum = (a.data() as Map)['slotNumber'] ?? a.id;
                  final bNum = (b.data() as Map)['slotNumber'] ?? b.id;
                  return aNum.toString().compareTo(bNum.toString());
                });

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final slotId = doc.id;
                    final label = data['slotNumber']?.toString() ?? slotId;
                    final isTaken = data['taken'] == true || data['isOccupied'] == true;
                    final type = data['type']?.toString() ?? 'normal';
                    final isDisabled = type == 'disabled';
                    final isSelected = _selectedSlotId == slotId;

                    return _buildSlotTile(
                      slotId: slotId,
                      label: label,
                      isTaken: isTaken,
                      isDisabled: isDisabled,
                      isSelected: isSelected,
                    );
                  },
                );
              },
            ),
          ),

          // ═══════════════════════════════════════════════════════
          // BOTTOM CONFIRM BUTTON
          // ═══════════════════════════════════════════════════════
          _buildBottomButton(),
        ],
      ),
    );
  }

  // ─── FLOOR SELECTOR ─────────────────────────────────────────────────
  Widget _buildFloorSelector(int totalFloors) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: totalFloors,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isActive = _selectedFloor == index;
          final label = index == 0 ? 'Ground' : 'Floor $index';

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedFloor = index;
                _selectedSlotId = null;
                _selectedSlotLabel = null;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF2845D6) : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: isActive
                    ? null
                    : Border.all(color: const Color(0xFFE8ECF4), width: 1.5),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF5C6B8A),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── LEGEND ─────────────────────────────────────────────────────────
  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _legendItem(
            color: Colors.white,
            borderColor: const Color(0xFFE8ECF4),
            label: 'Available',
          ),
          const SizedBox(width: 20),
          _legendItem(
            color: const Color(0xFF2845D6),
            borderColor: null,
            label: 'Selected',
          ),
          const SizedBox(width: 20),
          _legendItem(
            color: const Color(0xFFE8ECF4),
            borderColor: null,
            label: 'Taken',
          ),
        ],
      ),
    );
  }

  Widget _legendItem({
    required Color color,
    Color? borderColor,
    required String label,
  }) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: borderColor != null
                ? Border.all(color: borderColor, width: 1.5)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF9AA5BC),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─── SLOT TILE ──────────────────────────────────────────────────────
  Widget _buildSlotTile({
    required String slotId,
    required String label,
    required bool isTaken,
    required bool isDisabled,
    required bool isSelected,
  }) {
    if (isDisabled) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8ECF4), width: 1.5),
        ),
        child: const Center(
          child: Text(
            '—',
            style: TextStyle(
              color: Color(0xFFC4CEDD),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    if (isTaken) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4F6FB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8ECF4), width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFC4CEDD),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // Available or Selected
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() {
          if (_selectedSlotId == slotId) {
            _selectedSlotId = null;
            _selectedSlotLabel = null;
          } else {
            _selectedSlotId = slotId;
            _selectedSlotLabel = label;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2845D6) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? null
              : Border.all(color: const Color(0xFFE8ECF4), width: 1.5),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color(0xFF2845D6).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF0D1117),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 2),
                const Icon(Icons.check, color: Colors.white, size: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── BOTTOM BUTTON ──────────────────────────────────────────────────
  Widget _buildBottomButton() {
    final hasSelection = _selectedSlotId != null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE8ECF4), width: 1)),
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: hasSelection
                ? () {
                    HapticFeedback.lightImpact();
                    _navigateToConfirmBooking(_selectedSlotId!, _selectedFloor);
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  hasSelection ? const Color(0xFF2845D6) : const Color(0xFFE8ECF4),
              disabledBackgroundColor: const Color(0xFFE8ECF4),
              elevation: 0,
              shadowColor: hasSelection
                  ? const Color(0xFF2845D6).withOpacity(0.3)
                  : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              hasSelection
                  ? 'Continue with Slot ${_selectedSlotLabel ?? _selectedSlotId}'
                  : 'Select a slot',
              style: TextStyle(
                color: hasSelection ? Colors.white : const Color(0xFF9AA5BC),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── SHIMMER LOADING ────────────────────────────────────────────────
  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8ECF4),
      highlightColor: const Color(0xFFF4F6FB),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.0,
        ),
        itemCount: 16,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
