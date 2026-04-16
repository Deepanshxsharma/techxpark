import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../config/map_config.dart';
import '../booking/booking_screen.dart';

/// Premium Search Parking Screen based on HTML template.
class SearchParkingScreen extends StatefulWidget {
  final LatLng? userLocation;

  const SearchParkingScreen({super.key, this.userLocation});

  @override
  State<SearchParkingScreen> createState() => _SearchParkingScreenState();
}

class _SearchParkingScreenState extends State<SearchParkingScreen> {
  // Theme colors from the HTML
  static const Color _primary = Color(0xFF0018AB);
  static const Color _primaryContainer = Color(0xFF1C31D4);
  static const Color _onSurface = Color(0xFF1A1C1D);
  static const Color _onSurfaceVariant = Color(0xFF454655);
  static const Color _surfaceContainerLow = Color(0xFFF3F3F5);
  static const Color _surfaceVariant = Color(0xFFE2E2E4);
  static const Color _error = Color(0xFFBA1A1A);
  static const Color _primaryFixed = Color(0xFFDFE0FF);
  static const Color _white = Colors.white;

  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _allParks = [];
  List<Map<String, dynamic>> _suggestions = [];

  bool _loading = true;
  LatLng? _myLocation;

  int _selectedSortIndex = 0;
  final List<_SortOption> _sortOptions = [
    _SortOption('All', null),
    _SortOption('Nearby', null),
    _SortOption('EV Charging', Icons.ev_station),
    _SortOption('Covered', null),
    _SortOption('Cheapest', null),
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    _initLocation();
    _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _initLocation() async {
    try {
      if (widget.userLocation != null) {
        _myLocation = widget.userLocation;
      } else {
        final pos = await Geolocator.getCurrentPosition();
        _myLocation = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      final snap = await FirebaseFirestore.instance.collection('parking_locations').get();
      final data = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name': data['name'] ?? '',
          'latitude': (data['latitude'] as num?)?.toDouble() ?? 0.0,
          'longitude': (data['longitude'] as num?)?.toDouble() ?? 0.0,
          'price_per_hour': data['price_per_hour'] ?? 0,
          'available_slots': data['available_slots'] ?? 0,
          'address': data['address'] ?? '',
          'image': data['image'],
          'imageUrl': data['imageUrl'],
          'rating': data['rating'],
        };
      }).toList();

      if (mounted) {
        setState(() {
          _allParks = data;
          _suggestions = List.from(data);
          _loading = false;
        });
        if (_myLocation != null) _applyFilters();
      }
    } catch (e) {
      debugPrint('Error loading search data: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _applyFilters);
  }

  void _applyFilters() {
    final query = _controller.text.trim().toLowerCase();
    List<Map<String, dynamic>> temp;

    if (query.isEmpty) {
      temp = List.from(_allParks);
    } else {
      temp = _allParks.where((p) {
        final name = p['name'].toString().toLowerCase();
        final address = p['address'].toString().toLowerCase();
        return name.contains(query) || address.contains(query);
      }).toList();
    }

    temp.sort((a, b) {
      switch (_selectedSortIndex) {
        case 4: // Cheapest
          return (a['price_per_hour'] as num).compareTo(b['price_per_hour'] as num);
        case 0:
        case 1:
        default:
          if (_myLocation == null) return 0;
          final da = _distance(_myLocation!, LatLng(a['latitude'], a['longitude']));
          final db = _distance(_myLocation!, LatLng(b['latitude'], b['longitude']));
          return da.compareTo(db);
      }
    });

    if (mounted) setState(() => _suggestions = temp);
  }

  double _distance(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _surfaceContainerLow,
        body: Stack(
          children: [
            _buildMapBackground(),
            _buildMapControls(),
            _buildBottomSheet(),
            _buildTopHeader(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapBackground() {
    return Positioned.fill(
      child: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(12.9716, 77.5946), // Bangalore coordinates
          initialZoom: 14.0,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: MapConfig.tileUrl,
            userAgentPackageName: MapConfig.userAgent,
            maxZoom: MapConfig.maxZoom.toInt(),
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: const LatLng(12.9716, 77.5946),
                width: 48,
                height: 48,
                child: _buildUserLocationDot(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserLocationDot() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _primary,
                shape: BoxShape.circle,
                border: Border.all(color: _white, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 16),
              _buildFilterChips(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: _white.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: _onSurface.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                color: _primary,
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w500,
                    color: _onSurface,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: "Search parking or destination",
                    hintStyle: GoogleFonts.manrope(color: _onSurfaceVariant),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (_controller.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: _onSurfaceVariant),
                  onPressed: () {
                    _controller.clear();
                    _applyFilters();
                    FocusScope.of(context).unfocus();
                  },
                )
              else
                const Padding(
                  padding: EdgeInsets.only(right: 8.0, left: 4.0),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuDuu6Ue-ca06g5wnizAowQNuCSFzPph8xThIhKUY5AHk-qJZIBOA6tby7YVKMdzWZeUSap6Yi7wxVQdO10Sj5xnniJqYIXZAbPWLnYBCFnmIKIgBM1XdUEDI9WisY5-mAFD0thC2VQwbayyxrbRaS7UhhVtUV35uVTu8jmYzoBnpg0zyy1EzMRmteHKKRA64KQYYxIfGiLh0be5gNFVMHbSlnRDse4T-giYkwSwHrQh41FGQjaD_C2p6-LpLZNB3YvsU06KTuWJ-N5y',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _sortOptions.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedSortIndex == index;
          final option = _sortOptions[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(option.label),
              avatar: option.icon != null
                  ? Icon(option.icon, size: 18, color: isSelected ? _white : _onSurface)
                  : null,
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedSortIndex = index);
                  _applyFilters();
                }
              },
              backgroundColor: _white.withOpacity(0.75),
              selectedColor: _primaryContainer,
              labelStyle: GoogleFonts.manrope(
                color: isSelected ? _white : _onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(99),
                side: BorderSide(color: isSelected ? Colors.transparent : _white.withOpacity(0.5)),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapControls() {
    return Positioned(
      top: 150,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'btn1',
            onPressed: () {},
            backgroundColor: _white,
            elevation: 8.0,
            shape: const CircleBorder(),
            mini: true,
            child: const Icon(Icons.layers, color: _onSurface, size: 20),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'btn2',
            onPressed: () {},
            backgroundColor: _white,
            elevation: 8.0,
            shape: const CircleBorder(),
            mini: true,
            child: const Icon(Icons.my_location, color: _primary, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.2,
      maxChildSize: 0.85,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -10),
              )
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _surfaceVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Nearby Spaces",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: _onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _loading
                              ? "Finding parking spots..."
                              : "${_suggestions.length} parking locations found",
                          style: GoogleFonts.manrope(
                            color: _onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.expand_more, size: 20),
                      label: Text(
                        "Sort by",
                        style: GoogleFonts.manrope(
                          color: _primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? _buildShimmer()
                    : _suggestions.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                            physics: const BouncingScrollPhysics(),
                            itemCount: _suggestions.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final p = _suggestions[index];
                              if (index == 0) {
                                return _buildParkingCardSelected(p);
                              } else {
                                return _buildParkingCardSecondary(p);
                              }
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParkingCardSelected(Map<String, dynamic> p) {
    final price = p['price_per_hour'];
    final slots = p['available_slots'] as int;
    final String? imageUrl = p['imageUrl'] ?? p['image'];
    final rating = (p['rating'] as num?)?.toDouble() ?? 4.5;
    
    double? dist;
    if (_myLocation != null) {
      dist = _distance(_myLocation!, LatLng(p['latitude'], p['longitude']));
    }
    String distStr = dist != null
        ? (dist < 1000 ? '${dist.toStringAsFixed(0)} m' : '${(dist / 1000).toStringAsFixed(1)} km')
        : '';

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _primary.withOpacity(0.1)),
      ),
      child: Stack(
        children: [
          // Banner
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: const BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16)),
              ),
              child: Text(
                "SELECTED",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: _white,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 64,
                        height: 64,
                        color: _surfaceContainerLow,
                        child: imageUrl != null && imageUrl.isNotEmpty
                            ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.local_parking, color: _primary))
                            : const Icon(Icons.local_parking, color: _primary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['name'],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.star, color: _primary, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                rating.toStringAsFixed(1),
                                style: GoogleFonts.manrope(
                                  color: _primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (distStr.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(
                                  "• $distStr",
                                  style: GoogleFonts.manrope(color: _onSurfaceVariant),
                                ),
                              ]
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "₹$price/hr",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$slots slots left",
                          style: GoogleFonts.manrope(
                            color: slots > 5 ? _onSurfaceVariant : _error,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookingScreen(parkingId: p['id'], parking: p),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: _white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(99),
                          ),
                          elevation: 4,
                          shadowColor: _primary.withOpacity(0.3),
                        ),
                        child: Text(
                          "View Details",
                          style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(14),
                        side: const BorderSide(color: _surfaceVariant),
                      ),
                      child: const Icon(Icons.directions, color: _onSurface),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParkingCardSecondary(Map<String, dynamic> p) {
    final price = p['price_per_hour'];
    final slots = p['available_slots'] as int;
    final String? imageUrl = p['imageUrl'] ?? p['image'];
    final rating = (p['rating'] as num?)?.toDouble() ?? 4.5;
    
    double? dist;
    if (_myLocation != null) {
      dist = _distance(_myLocation!, LatLng(p['latitude'], p['longitude']));
    }
    String distStr = dist != null
        ? (dist < 1000 ? '${dist.toStringAsFixed(0)} m' : '${(dist / 1000).toStringAsFixed(1)} km')
        : '';

    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingScreen(parkingId: p['id'], parking: p),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 56,
                height: 56,
                color: _surfaceContainerLow,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.local_parking, color: _onSurfaceVariant))
                    : const Icon(Icons.local_parking, color: _onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p['name'],
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: _onSurfaceVariant, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.manrope(
                          color: _onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      if (distStr.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          "• $distStr",
                          style: GoogleFonts.manrope(
                            color: _onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ]
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "₹$price/hr",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$slots slots left",
                  style: GoogleFonts.manrope(
                    color: slots > 5 ? _primary : _error,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      itemCount: 4,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: 96,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 52,
              color: _primary.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No parking found',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search or adjust filters',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: _onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SortOption {
  final String label;
  final IconData? icon;
  const _SortOption(this.label, this.icon);
}
