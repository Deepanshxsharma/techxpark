import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/map_service.dart';
import '../../services/parking_filter_service.dart';
import '../../theme/app_colors.dart';
import '../parking_details/lot_detail_navigation.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  LatLng? _userLocation;

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  static const _defaultCenter = LatLng(28.6139, 77.2090); // New Delhi fallback
  static const _filters = <String>[
    ParkingFilterService.allFilterLabel,
    ParkingFilterService.evFilterLabel,
  ];

  int _selectedFilterIndex = 0;
  String get _selectedFilter => _filters[_selectedFilterIndex];

  @override
  void initState() {
    super.initState();
    MapService.loadMarkerIcons().then((_) {
      if (mounted) setState(() {});
    });
    _fetchUserLocation();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserLocation() async {
    final loc = await MapService.getUserLocation();
    if (!mounted) return;
    setState(() {
      _userLocation = loc;
    });
    if (loc != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(loc, 14));
    }
  }

  void _recenterMap() {
    final target = _userLocation ?? _defaultCenter;
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 14));
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: ParkingFilterService.streamParking(_selectedFilter),
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];
            debugPrint('TOTAL DOCS: ${docs.length}');
            final markers = _buildMarkers(docs);
            final lots = _buildLotList(docs);

            return Stack(
              children: [
                // ── Full-screen Google Map ──
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _userLocation ?? _defaultCenter,
                    zoom: 14,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  markers: markers,
                  onMapCreated: (controller) {
                    _mapController = controller;
                    _setMapStyle(controller);
                  },
                ),

                // ── Top safe-area floating bar ──
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 20,
                  right: 20,
                  child: _FloatingHeader(
                    onRecenter: _recenterMap,
                    lotCount: lots.length,
                  ),
                ),

                Positioned(
                  top: MediaQuery.of(context).padding.top + 82,
                  left: 20,
                  right: 20,
                  child: _MapFilterChips(
                    filters: _filters,
                    selectedIndex: _selectedFilterIndex,
                    onSelected: (index) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedFilterIndex = index);
                    },
                  ),
                ),

                // ── Loading indicator ──
                if (snapshot.connectionState == ConnectionState.waiting &&
                    docs.isEmpty)
                  const Center(child: CircularProgressIndicator()),

                // ── Draggable bottom sheet ──
                if (lots.isNotEmpty)
                  DraggableScrollableSheet(
                    controller: _sheetController,
                    initialChildSize: 0.12,
                    minChildSize: 0.08,
                    maxChildSize: 0.55,
                    snap: true,
                    snapSizes: const [0.12, 0.35, 0.55],
                    builder: (context, scrollController) {
                      return _BottomSheet(
                        scrollController: scrollController,
                        lots: lots,
                        userLocation: _userLocation,
                        onLotTap: (lot) {
                          _mapController?.animateCamera(
                            CameraUpdate.newLatLngZoom(
                              LatLng(
                                lot['latitude'] as double,
                                lot['longitude'] as double,
                              ),
                              16,
                            ),
                          );
                          openLotDetail(context, lot['id'] as String, lot);
                        },
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Set<Marker> _buildMarkers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .map((doc) {
          final data = {...doc.data(), 'id': doc.id};
          return MapService.createSmartMarker(
            id: doc.id,
            data: data,
            onTap: () => openLotDetail(context, doc.id, data),
          );
        })
        .whereType<Marker>()
        .toSet();
  }

  List<Map<String, dynamic>> _buildLotList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final lots = <Map<String, dynamic>>[];
    for (final doc in docs) {
      final data = {...doc.data(), 'id': doc.id};
      final pos = MapService.getLatLng(data);
      if (pos == null) continue;
      data['latitude'] = pos.latitude;
      data['longitude'] = pos.longitude;
      if (_userLocation != null) {
        data['_distance'] = Geolocator.distanceBetween(
          _userLocation!.latitude,
          _userLocation!.longitude,
          pos.latitude,
          pos.longitude,
        );
      }
      lots.add(data);
    }
    lots.sort((a, b) {
      final da = a['_distance'] as double? ?? double.infinity;
      final db = b['_distance'] as double? ?? double.infinity;
      return da.compareTo(db);
    });
    return lots;
  }

  Future<void> _setMapStyle(GoogleMapController controller) async {
    // Subtle clean style - use default for now
  }
}

class _MapFilterChips extends StatelessWidget {
  final List<String> filters;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _MapFilterChips({
    required this.filters,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final selected = selectedIndex == index;
          final isEv = ParkingFilterService.isEvFilter(filters[index]);
          return ChoiceChip(
            selected: selected,
            showCheckmark: false,
            avatar: isEv
                ? Icon(
                    Icons.bolt_rounded,
                    size: 16,
                    color: selected ? Colors.white : AppColors.evGreen,
                  )
                : null,
            label: Text(filters[index]),
            onSelected: (_) => onSelected(index),
            selectedColor: isEv ? AppColors.evGreen : AppColors.primary,
            backgroundColor: Colors.white,
            labelStyle: GoogleFonts.poppins(
              color: selected ? Colors.white : AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(
              color: selected ? Colors.transparent : AppColors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          );
        },
      ),
    );
  }
}

// ── Floating header bar ──────────────────────────────────────────────────────

class _FloatingHeader extends StatelessWidget {
  final VoidCallback onRecenter;
  final int lotCount;

  const _FloatingHeader({required this.onRecenter, required this.lotCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.map_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Explore Parking',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF181C20),
                  ),
                ),
                Text(
                  '$lotCount spots nearby',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF757686),
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: const Color(0xFFF1F4F9),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onRecenter,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.my_location_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Draggable bottom sheet ───────────────────────────────────────────────────

class _BottomSheet extends StatelessWidget {
  final ScrollController scrollController;
  final List<Map<String, dynamic>> lots;
  final LatLng? userLocation;
  final ValueChanged<Map<String, dynamic>> onLotTap;

  const _BottomSheet({
    required this.scrollController,
    required this.lots,
    required this.userLocation,
    required this.onLotTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 32,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: ListView.builder(
        controller: scrollController,
        padding: EdgeInsets.zero,
        itemCount: lots.length + 1, // +1 for handle
        itemBuilder: (context, index) {
          if (index == 0) return _buildHandle();
          final lot = lots[index - 1];
          return _LotTile(
            lot: lot,
            userLocation: userLocation,
            onTap: () => onLotTap(lot),
          );
        },
      ),
    );
  }

  Widget _buildHandle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 4),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD0D5DD),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Text(
                  'Nearby Parking',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF181C20),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${lots.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
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

// ── Individual lot tile ──────────────────────────────────────────────────────

class _LotTile extends StatelessWidget {
  final Map<String, dynamic> lot;
  final LatLng? userLocation;
  final VoidCallback onTap;

  const _LotTile({
    required this.lot,
    required this.userLocation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = lot['name']?.toString() ?? 'Parking Lot';
    final isEv = MapService.isEvLot(lot);

    final price = MapService.readNumber(
      lot['price_per_hour'] ?? lot['pricePerHour'] ?? lot['price'],
    );
    final slots = MapService.readInt(
      lot['available_slots'] ?? lot['availableSlots'],
    );
    final isFull = slots <= 0;
    final distance = lot['_distance'] as double?;
    final evSlots = MapService.readInt(lot['ev_slots'] ?? lot['evSlots']);
    final evAvail = MapService.readInt(
      lot['ev_available'] ?? lot['evAvailable'],
      fallback: evSlots,
    );

    // Colors based on EV status
    final accentColor = isEv ? const Color(0xFF00C853) : AppColors.primary;
    final accentBg = isEv
        ? const Color(0xFFE0F7E9)
        : AppColors.primary.withValues(alpha: 0.08);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isEv ? const Color(0xFFA5D6A7) : const Color(0xFFEEF0F4),
              ),
            ),
            child: Row(
              children: [
                // Parking / EV icon
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isFull ? const Color(0xFFFCE8E8) : accentBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isEv
                        ? Icons.ev_station_rounded
                        : Icons.local_parking_rounded,
                    color: isFull ? const Color(0xFFBA1A1A) : accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF181C20),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (distance != null) ...[
                            Icon(
                              Icons.near_me_rounded,
                              size: 11,
                              color: const Color(0xFF757686),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _formatDistance(distance),
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: const Color(0xFF757686),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isFull
                                  ? const Color(0xFFFCE8E8)
                                  : const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isFull ? 'Full' : '$slots free',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isFull
                                    ? const Color(0xFFBA1A1A)
                                    : const Color(0xFF1B5E20),
                              ),
                            ),
                          ),
                          // EV badge
                          if (isEv) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F7E9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.bolt_rounded,
                                    size: 10,
                                    color: Color(0xFF00C853),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '$evAvail/$evSlots EV',
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF00C853),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Price
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${price.toStringAsFixed(price % 1 == 0 ? 0 : 1)}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                    Text(
                      '/hr',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFF757686),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
