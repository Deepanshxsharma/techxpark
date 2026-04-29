import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/app_colors.dart';
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
  String? _selectedSlotId;
  String? _selectedSlotLabel;
  int _selectedFloor = 0;
  String _activeFilter = 'Nearest';
  int _reloadTick = 0;

  Stream<QuerySnapshot<Map<String, dynamic>>> _slotStream() {
    return FirebaseFirestore.instance
        .collection('parking_locations')
        .doc(widget.parkingId)
        .collection('slots')
        .snapshots();
  }

  void _retry() {
    setState(() => _reloadTick++);
  }

  void _navigateToConfirmBooking(_SlotItem selectedSlot) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ConfirmBookingScreen(
          parking: widget.parking,
          parkingId: widget.parkingId,
          selectedSlot: selectedSlot.id,
          floorIndex: selectedSlot.floor,
          start: widget.start,
          end: widget.end,
          vehicle: widget.vehicle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lotName = widget.parking['name']?.toString() ?? 'Parking Lot';
    final hourlyPrice = _readPrice(
      widget.parking['price_per_hour'] ??
          widget.parking['pricePerHour'] ??
          widget.parking['price'],
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9FB),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          key: ValueKey(_reloadTick),
          stream: _slotStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingState();
            }

            if (snapshot.hasError) {
              return _buildErrorState();
            }

            final docs = snapshot.data?.docs ?? const [];
            debugPrint('Slots: ${docs.length}');

            final slots = docs.map((doc) => _SlotItem.fromDoc(doc)).toList()
              ..sort((a, b) => a.sortKey.compareTo(b.sortKey));

            final floors = slots.map((slot) => slot.floor).toSet().toList()
              ..sort();

            if (floors.isNotEmpty && !floors.contains(_selectedFloor)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _selectedFloor = floors.first;
                  _selectedSlotId = null;
                  _selectedSlotLabel = null;
                });
              });
            }

            final effectiveFloor = floors.isEmpty ? 0 : _selectedFloor;
            final floorSlots = slots
                .where((slot) => slot.floor == effectiveFloor)
                .toList();
            final availableCount = floorSlots
                .where((slot) => slot.isSelectable)
                .length;
            final sectionLabel = _sectionLabelFor(floorSlots);

            final selectedSlot = floorSlots
                .where((slot) => slot.id == _selectedSlotId)
                .cast<_SlotItem?>()
                .firstOrNull;

            if (selectedSlot != null && !selectedSlot.isSelectable) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _selectedSlotId != selectedSlot.id) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Slot just got booked'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: AppColors.error,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                );
                setState(() {
                  _selectedSlotId = null;
                  _selectedSlotLabel = null;
                });
              });
            }

            return Stack(
              children: [
                Column(
                  children: [
                    _TopBar(onBack: () => Navigator.of(context).maybePop()),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          children: [
                            Expanded(
                              child: ListView(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(bottom: 164),
                                children: [
                                  _SummarySection(
                                    lotName: lotName,
                                    levelLabel: _levelLabel(effectiveFloor),
                                    sectionLabel: sectionLabel,
                                    availableCount: availableCount,
                                    filters: const ['Nearest', 'Covered', 'EV'],
                                    activeFilter: _activeFilter,
                                    floors: floors,
                                    selectedFloor: effectiveFloor,
                                    onFilterChanged: (filter) {
                                      HapticFeedback.selectionClick();
                                      setState(() => _activeFilter = filter);
                                    },
                                    onFloorChanged: (floor) {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _selectedFloor = floor;
                                        _selectedSlotId = null;
                                        _selectedSlotLabel = null;
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 22),
                                  _LegendRow(),
                                  const SizedBox(height: 18),
                                  if (floorSlots.isEmpty)
                                    _buildEmptyFloorState()
                                  else
                                    _SlotCanvas(
                                      slots: floorSlots,
                                      selectedSlotId: _selectedSlotId,
                                      onSlotTap: (slot) {
                                        if (!slot.isSelectable) return;
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _selectedSlotId = slot.id;
                                          _selectedSlotLabel = slot.label;
                                        });
                                        debugPrint('Selected: ${slot.id}');
                                      },
                                    ),
                                  if (availableCount == 0 &&
                                      floorSlots.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 20),
                                      child: _InlineNotice(
                                        text:
                                            'No slots available on this level',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                _BottomBar(
                  selectedSlotLabel: _selectedSlotLabel,
                  levelLabel: _levelLabel(effectiveFloor),
                  priceLabel: hourlyPrice,
                  enabled: selectedSlot != null,
                  onContinue: selectedSlot == null
                      ? null
                      : () {
                          HapticFeedback.mediumImpact();
                          _navigateToConfirmBooking(selectedSlot);
                        },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      body: Column(
        children: [
          _TopBar(onBack: () => Navigator.of(context).maybePop()),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  Shimmer.fromColors(
                    baseColor: const Color(0xFFE8ECF4),
                    highlightColor: const Color(0xFFF8FAFC),
                    child: Column(
                      children: [
                        Container(
                          height: 178,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(height: 18, width: 220, color: Colors.white),
                        const SizedBox(height: 18),
                        Container(
                          height: 440,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ],
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

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 52,
                  color: AppColors.error,
                ),
                const SizedBox(height: 18),
                Text(
                  'Could not load slots',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1C1D),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please check the connection and try again.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    height: 1.5,
                    color: const Color(0xFF757687),
                  ),
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: _retry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFloorState() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          const Icon(
            Icons.local_parking_rounded,
            size: 44,
            color: Color(0xFF9AA5BC),
          ),
          const SizedBox(height: 14),
          Text(
            'No slots available',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1C1D),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This level has no slots yet. Try another level or come back in a moment.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.5,
              color: const Color(0xFF757687),
            ),
          ),
        ],
      ),
    );
  }

  static String _levelLabel(int floor) =>
      'Level ${(floor + 1).toString().padLeft(2, '0')}';

  static String _readPrice(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;
    final formatted = number % 1 == 0
        ? number.toStringAsFixed(0)
        : number.toStringAsFixed(2);
    return '₹$formatted/hr';
  }

  static String _sectionLabelFor(List<_SlotItem> slots) {
    final sections =
        slots
            .map((slot) => slot.section)
            .where((section) => section.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    if (sections.isEmpty) return 'Section Open';
    if (sections.length == 1) return 'Section ${sections.first}';
    return 'Section ${sections.first}-${sections.last}';
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(18, topPadding + 10, 18, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.primary,
            ),
          ),
          Expanded(
            child: Text(
              'Select Parking Slot',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1C1D),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Live',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: const Color(0xFF757687),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final String lotName;
  final String levelLabel;
  final String sectionLabel;
  final int availableCount;
  final List<String> filters;
  final String activeFilter;
  final List<int> floors;
  final int selectedFloor;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<int> onFloorChanged;

  const _SummarySection({
    required this.lotName,
    required this.levelLabel,
    required this.sectionLabel,
    required this.availableCount,
    required this.filters,
    required this.activeFilter,
    required this.floors,
    required this.selectedFloor,
    required this.onFilterChanged,
    required this.onFloorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 760;

        final summaryCard = Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lotName,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$levelLabel · $sectionLabel',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF454655),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SummaryPill(
                    title: 'Available',
                    value: '$availableCount Slots',
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F3F5),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: Color(0xFF10B981),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Live availability updates',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (floors.length > 1) ...[
                const SizedBox(height: 20),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: floors.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final floor = floors[index];
                      final isActive = floor == selectedFloor;

                      return GestureDetector(
                        onTap: () => onFloorChanged(floor),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.primaryLight
                                : const Color(0xFFF3F3F5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            SlotSelectionScreenStateHelpers.levelLabel(floor),
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isActive
                                  ? Colors.white
                                  : const Color(0xFF454655),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );

        final filtersCard = Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filters',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: const Color(0xFF757687),
                ),
              ),
              const SizedBox(height: 14),
              ...filters.map(
                (filter) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _FilterButton(
                    label: filter,
                    icon: switch (filter) {
                      'Nearest' => Icons.near_me_rounded,
                      'Covered' => Icons.roofing_rounded,
                      _ => Icons.ev_station_rounded,
                    },
                    isActive: activeFilter == filter,
                    onTap: () => onFilterChanged(filter),
                  ),
                ),
              ),
            ],
          ),
        );

        if (stacked) {
          return Column(
            children: [summaryCard, const SizedBox(height: 16), filtersCard],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: summaryCard),
            const SizedBox(width: 18),
            Expanded(child: filtersCard),
          ],
        );
      },
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryPill({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1C1D),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: isActive ? 0 : 0,
          backgroundColor: isActive ? AppColors.primaryLight : Colors.white,
          foregroundColor: isActive ? Colors.white : const Color(0xFF1A1C1D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (isActive) const Icon(Icons.done_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 28,
      runSpacing: 12,
      children: const [
        _LegendItem(
          color: Color(0xFFE6EDFF),
          borderColor: Color(0xFFD5DDF7),
          label: 'Available',
        ),
        _LegendItem(color: Color(0xFFE2E2E4), label: 'Taken'),
        _LegendItem(
          color: AppColors.primaryLight,
          glow: true,
          label: 'Selected',
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final Color? borderColor;
  final bool glow;
  final String label;

  const _LegendItem({
    required this.color,
    this.borderColor,
    this.glow = false,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1.5)
                : null,
            boxShadow: glow
                ? [
                    BoxShadow(
                      color: AppColors.primaryLight.withValues(alpha: 0.35),
                      blurRadius: 14,
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: const Color(0xFF757687),
          ),
        ),
      ],
    );
  }
}

class _SlotCanvas extends StatelessWidget {
  final List<_SlotItem> slots;
  final String? selectedSlotId;
  final ValueChanged<_SlotItem> onSlotTap;

  const _SlotCanvas({
    required this.slots,
    required this.selectedSlotId,
    required this.onSlotTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 700;
        final crossAxisCount = isWide ? 4 : 2;
        final rows = (slots.length / crossAxisCount).ceil();
        final rowGap = isWide ? 112.0 : 84.0;
        final tileGap = isWide ? 20.0 : 14.0;
        final tileHeight = isWide ? 112.0 : 96.0;
        return Container(
          padding: EdgeInsets.all(isWide ? 28 : 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F5),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      rows > 1 ? rows - 1 : 0,
                      (index) => Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                border: Border.all(
                                  color: const Color(0x331A1C1D),
                                  width: 0.6,
                                  style: BorderStyle.solid,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: slots.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: rowGap,
                  crossAxisSpacing: tileGap,
                  childAspectRatio: isWide ? 1.25 : 1.05,
                  mainAxisExtent: tileHeight,
                ),
                itemBuilder: (context, index) {
                  final slot = slots[index];
                  final isSelected = slot.id == selectedSlotId;

                  return _SlotTile(
                    slot: slot,
                    isSelected: isSelected,
                    onTap: slot.isSelectable ? () => onSlotTap(slot) : null,
                  );
                },
              ),
              if (rows > 1)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Column(
                      children: List.generate(rows, (index) {
                        if (index == rows - 1) {
                          return const SizedBox.shrink();
                        }

                        return Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 30),
                              child: Text(
                                'Lane ${(index + 2).toString().padLeft(2, '0')} Driveway',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 3,
                                  color: const Color(0x331A1C1D),
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SlotTile extends StatelessWidget {
  final _SlotItem slot;
  final bool isSelected;
  final VoidCallback? onTap;

  const _SlotTile({
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isTaken = !slot.isSelectable;
    final backgroundColor = isSelected
        ? AppColors.primaryLight
        : isTaken
        ? const Color(0xFFE2E2E4)
        : Colors.white;
    final textColor = isSelected
        ? Colors.white
        : isTaken
        ? const Color(0x661A1C1D)
        : const Color(0x661C31D4);

    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: isSelected ? 1.05 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? null
                : Border.all(
                    color: isTaken
                        ? Colors.transparent
                        : const Color(0x260018AB),
                  ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: AppColors.primaryLight.withValues(alpha: 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Center(
            child: isSelected
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        slot.label,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Icon(
                        Icons.directions_car_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ],
                  )
                : Text(
                    slot.label,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final String text;

  const _InlineNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7E8EC)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF757687),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final String? selectedSlotLabel;
  final String levelLabel;
  final String priceLabel;
  final bool enabled;
  final VoidCallback? onContinue;

  const _BottomBar({
    required this.selectedSlotLabel,
    required this.levelLabel,
    required this.priceLabel,
    required this.enabled,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 28,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 640;
              final info = _BottomInfo(
                selectedSlotLabel: selectedSlotLabel,
                levelLabel: levelLabel,
                priceLabel: priceLabel,
              );
              final button = SizedBox(
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: enabled ? AppColors.primaryGradient : null,
                    color: enabled ? null : const Color(0xFFE2E2E4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: const Color(0xFF757687),
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    label: Text(
                      'Continue',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: enabled ? Colors.white : const Color(0xFF757687),
                      ),
                    ),
                  ),
                ),
              );

              if (stacked) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [info, const SizedBox(height: 14), button],
                );
              }

              return Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 18),
                  SizedBox(width: 220, child: button),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BottomInfo extends StatelessWidget {
  final String? selectedSlotLabel;
  final String levelLabel;
  final String priceLabel;

  const _BottomInfo({
    required this.selectedSlotLabel,
    required this.levelLabel,
    required this.priceLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected Slot',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: const Color(0xFF757687),
              ),
            ),
            const SizedBox(height: 2),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: selectedSlotLabel ?? 'Choose one',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1C1D),
                    ),
                  ),
                  TextSpan(
                    text: ' · $levelLabel',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Container(width: 1, height: 42, color: const Color(0xFFE2E2E4)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pricing',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: const Color(0xFF757687),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              priceLabel,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1A1C1D),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SlotItem {
  final String id;
  final String label;
  final int floor;
  final bool isOccupied;
  final bool isDisabled;

  const _SlotItem({
    required this.id,
    required this.label,
    required this.floor,
    required this.isOccupied,
    required this.isDisabled,
  });

  bool get isSelectable => !isOccupied && !isDisabled;

  String get sortKey => label.padLeft(8, '0');

  String get section {
    final match = RegExp(r'^[A-Za-z]+').firstMatch(label);
    return match?.group(0)?.toUpperCase() ?? '';
  }

  static _SlotItem fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final label = data['slotNumber']?.toString().trim().isNotEmpty == true
        ? data['slotNumber'].toString().trim()
        : doc.id;
    final floor = _readInt(data['floor']);
    final status = data['status']?.toString().trim().toLowerCase();
    final occupied =
        _readBool(data['occupied']) ||
        _readBool(data['isOccupied']) ||
        _readBool(data['taken']) ||
        status == 'occupied' ||
        status == 'taken' ||
        status == 'reserved';
    final type = data['type']?.toString().trim().toLowerCase();

    return _SlotItem(
      id: doc.id,
      label: label,
      floor: floor,
      isOccupied: occupied,
      isDisabled: type == 'disabled',
    );
  }

  static bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 'yes';
    }
    return false;
  }

  static int _readInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class SlotSelectionScreenStateHelpers {
  static String levelLabel(int floor) =>
      'Level ${(floor + 1).toString().padLeft(2, '0')}';
}
