import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../vehicle/my_vehicle_screen.dart';
import 'slot_selection_screen.dart';

class SelectVehicleScreen extends StatefulWidget {
  final Map<String, dynamic> parking;
  final String parkingId;
  final DateTime start;
  final DateTime end;

  const SelectVehicleScreen({
    super.key,
    required this.parking,
    required this.parkingId,
    required this.start,
    required this.end,
  });

  @override
  State<SelectVehicleScreen> createState() => _SelectVehicleScreenState();
}

class _SelectVehicleScreenState extends State<SelectVehicleScreen> {
  String? _selectedVehicleId;
  String _activeFilter = 'All';

  Stream<QuerySnapshot<Map<String, dynamic>>> _vehicleStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream<QuerySnapshot<Map<String, dynamic>>>.empty();
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('vehicles')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<String?> _loadPreferredVehicleId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return userDoc.data()?['selected_vehicle_id']?.toString();
  }

  Future<void> _openAddVehicle() async {
    HapticFeedback.lightImpact();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const MyVehicleScreen(isAddFlow: true),
      ),
    );
  }

  Future<void> _openGarage() async {
    HapticFeedback.selectionClick();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const MyVehicleScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppColors.bgDark : const Color(0xFFF9F9FB);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: background,
        body: FutureBuilder<String?>(
          future: _loadPreferredVehicleId(),
          builder: (context, preferredSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _vehicleStream(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? const [];
                final preferredId = preferredSnapshot.data;
                final vehicles = docs
                    .map((doc) => _VehicleItem.fromDoc(doc, preferredId))
                    .toList();
                final visibleVehicles = _applyFilter(vehicles, _activeFilter);
                final selectedId = _resolveSelectedId(vehicles);
                final selectedVehicle = vehicles
                    .where((vehicle) => vehicle.id == selectedId)
                    .cast<_VehicleItem?>()
                    .firstOrNull;

                return Stack(
                  children: [
                    CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverAppBar(
                          pinned: true,
                          backgroundColor: background.withValues(alpha: 0.84),
                          surfaceTintColor: Colors.transparent,
                          elevation: 0,
                          leading: IconButton(
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1C1D),
                            ),
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                          titleSpacing: 0,
                          title: Text(
                            'Select Vehicle',
                            style: GoogleFonts.poppins(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1C1D),
                            ),
                          ),
                          actions: [
                            PopupMenuButton<String>(
                              tooltip: 'More options',
                              color: isDark
                                  ? AppColors.surfaceDark
                                  : Colors.white,
                              surfaceTintColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              onSelected: (value) {
                                if (value == 'garage') {
                                  _openGarage();
                                } else if (value == 'add') {
                                  _openAddVehicle();
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem<String>(
                                  value: 'garage',
                                  child: Text('Manage garage'),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'add',
                                  child: Text('Add vehicle'),
                                ),
                              ],
                              icon: Icon(
                                Icons.more_vert_rounded,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1C1D),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 150),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              _buildFilterPills(isDark),
                              const SizedBox(height: 28),
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) ...[
                                const SizedBox(height: 80),
                                const Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                  ),
                                ),
                              ] else if (vehicles.isEmpty) ...[
                                _buildEmptyState(isDark),
                              ] else ...[
                                _buildSectionLabel('Your Fleet'),
                                const SizedBox(height: 14),
                                if (visibleVehicles.isEmpty)
                                  _buildNoMatchesState(isDark)
                                else
                                  ...visibleVehicles.map(
                                    (vehicle) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 14,
                                      ),
                                      child: _VehicleCard(
                                        vehicle: vehicle,
                                        isSelected: selectedId == vehicle.id,
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            _selectedVehicleId = vehicle.id;
                                          });
                                          debugPrint(
                                            'Selected vehicle: ${vehicle.id}',
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                _buildAddVehicleButton(isDark),
                                const SizedBox(height: 32),
                                _buildInfoCard(isDark),
                              ],
                            ]),
                          ),
                        ),
                      ],
                    ),
                    _BottomBar(
                      enabled: selectedVehicle != null,
                      label: 'Continue to Parking',
                      onTap: selectedVehicle == null
                          ? null
                          : () {
                              HapticFeedback.mediumImpact();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => SlotSelectionScreen(
                                    parkingId: widget.parkingId,
                                    parking: widget.parking,
                                    start: widget.start,
                                    end: widget.end,
                                    vehicle: selectedVehicle.toBookingMap(),
                                  ),
                                ),
                              );
                            },
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<_VehicleItem> _applyFilter(List<_VehicleItem> vehicles, String filter) {
    if (filter == 'All') return vehicles;

    return vehicles.where((vehicle) {
      switch (filter) {
        case 'Car':
          return vehicle.category == _VehicleCategory.car;
        case 'Bike':
          return vehicle.category == _VehicleCategory.bike;
        case 'EV':
          return vehicle.category == _VehicleCategory.ev;
        default:
          return true;
      }
    }).toList();
  }

  String? _resolveSelectedId(List<_VehicleItem> vehicles) {
    if (vehicles.isEmpty) return null;

    if (_selectedVehicleId != null &&
        vehicles.any((vehicle) => vehicle.id == _selectedVehicleId)) {
      return _selectedVehicleId;
    }

    final preferred = vehicles
        .where((vehicle) => vehicle.isDefault)
        .cast<_VehicleItem?>()
        .firstOrNull;
    return preferred?.id ?? vehicles.first.id;
  }

  Widget _buildFilterPills(bool isDark) {
    const filters = ['All', 'Car', 'Bike', 'EV'];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final label = filters[index];
          final isActive = _activeFilter == label;

          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _activeFilter = label);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primaryLight
                    : (isDark
                          ? AppColors.surfaceDark
                          : const Color(0xFFF3F3F5)),
                borderRadius: BorderRadius.circular(999),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF454655)),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
        color: const Color(0xFF757687),
      ),
    );
  }

  Widget _buildAddVehicleButton(bool isDark) {
    return GestureDetector(
      onTap: _openAddVehicle,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white24 : const Color(0xFFC5C5D8),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline_rounded,
              color: isDark ? Colors.white70 : const Color(0xFF757687),
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              'Add New Vehicle',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF1A1C1D),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFF3F3F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehicle Verification',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1A1C1D),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ensure your license plate is clean and visible. TechXPark uses AI cameras for seamless entry and exit.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark ? Colors.white60 : const Color(0xFF757687),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF3F3F5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.directions_car_rounded,
              size: 34,
              color: isDark ? Colors.white38 : const Color(0xFF757687),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'No vehicles added',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF1A1C1D),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your car, bike, or EV to keep the booking flow smooth.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.white60 : const Color(0xFF757687),
            ),
          ),
          const SizedBox(height: 24),
          _buildAddVehicleButton(isDark),
          const SizedBox(height: 24),
          _buildInfoCard(isDark),
        ],
      ),
    );
  }

  Widget _buildNoMatchesState(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Text(
        'No ${_activeFilter.toLowerCase()} vehicles available right now.',
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white60 : const Color(0xFF757687),
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final _VehicleItem vehicle;
  final bool isSelected;
  final VoidCallback onTap;

  const _VehicleCard({
    required this.vehicle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 180),
        scale: isSelected ? 1 : 0.995,
        child: Stack(
          children: [
            if (isSelected)
              Positioned.fill(
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryLight, AppColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
            Container(
              margin: EdgeInsets.all(isSelected ? 1.5 : 0),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : (isDark ? Colors.white12 : const Color(0xFFE7E8EC)),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.16)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: isSelected ? 22 : 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : (isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFF3F3F5)),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      vehicle.icon,
                      size: 30,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.white70 : const Color(0xFF454655)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              vehicle.name,
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1A1C1D),
                              ),
                            ),
                            if (vehicle.isDefault)
                              _VehicleBadge(
                                label: 'Default',
                                color: const Color(0xFFDDE3FF),
                                textColor: const Color(0xFF303C9A),
                              ),
                            if (vehicle.category == _VehicleCategory.ev)
                              _VehicleBadge(
                                label: 'EV',
                                color: AppColors.primary.withValues(alpha: 0.1),
                                textColor: AppColors.primary,
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          vehicle.number,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white60
                                : const Color(0xFF757687),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? null
                          : Border.all(
                              color: isDark
                                  ? Colors.white24
                                  : const Color(0xFFC5C5D8),
                              width: 2,
                            ),
                    ),
                    alignment: Alignment.center,
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          )
                        : null,
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

class _VehicleBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _VehicleBadge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
          color: textColor,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final bool enabled;
  final String label;
  final VoidCallback? onTap;

  const _BottomBar({required this.enabled, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: SizedBox(
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: enabled ? AppColors.primaryGradient : null,
                color: enabled ? null : const Color(0xFFE2E2E4),
                borderRadius: BorderRadius.circular(999),
              ),
              child: ElevatedButton.icon(
                onPressed: onTap,
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
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: enabled ? Colors.white : const Color(0xFF757687),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _VehicleCategory { car, bike, ev }

class _VehicleItem {
  final String id;
  final String name;
  final String number;
  final String typeLabel;
  final _VehicleCategory category;
  final bool isDefault;
  final Map<String, dynamic> raw;

  const _VehicleItem({
    required this.id,
    required this.name,
    required this.number,
    required this.typeLabel,
    required this.category,
    required this.isDefault,
    required this.raw,
  });

  IconData get icon {
    switch (category) {
      case _VehicleCategory.bike:
        return Icons.two_wheeler_rounded;
      case _VehicleCategory.ev:
        return Icons.electric_car_rounded;
      case _VehicleCategory.car:
        return Icons.directions_car_rounded;
    }
  }

  static _VehicleItem fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String? preferredVehicleId,
  ) {
    final data = doc.data();
    final normalizedType = _normalizeType(data['type'] ?? data['vehicleType']);
    final category = switch (normalizedType) {
      'bike' => _VehicleCategory.bike,
      'ev' => _VehicleCategory.ev,
      _ => _VehicleCategory.car,
    };
    final number = _displayNumber(data);
    final fallbackName = switch (category) {
      _VehicleCategory.bike => 'Bike',
      _VehicleCategory.ev => 'Electric Vehicle',
      _VehicleCategory.car => 'Car',
    };

    return _VehicleItem(
      id: doc.id,
      name: _readString(data['name'], fallback: fallbackName),
      number: number,
      typeLabel: _displayTypeLabel(category),
      category: category,
      isDefault: preferredVehicleId == doc.id || (data['isDefault'] == true),
      raw: data,
    );
  }

  Map<String, dynamic> toBookingMap() {
    return {
      ...raw,
      'id': id,
      'name': name,
      'number': number,
      'vehicleNumber': number,
      'type': typeLabel,
      'vehicleType': typeLabel,
      'isDefault': isDefault,
    };
  }

  static String _displayTypeLabel(_VehicleCategory category) {
    switch (category) {
      case _VehicleCategory.bike:
        return 'Bike';
      case _VehicleCategory.ev:
        return 'EV';
      case _VehicleCategory.car:
        return 'Car';
    }
  }

  static String _normalizeType(dynamic rawType) {
    final value = rawType?.toString().trim().toLowerCase() ?? '';
    if (value.contains('bike') || value.contains('scooter')) return 'bike';
    if (value.contains('ev') || value.contains('electric')) return 'ev';
    return 'car';
  }

  static String _displayNumber(Map<String, dynamic> data) {
    final value = _readString(
      data['number'] ?? data['vehicleNumber'],
      fallback: 'Number not added',
    );
    return value.toUpperCase();
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }
}
