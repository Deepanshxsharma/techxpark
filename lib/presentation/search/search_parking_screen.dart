import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shimmer/shimmer.dart';

import '../../theme/app_colors.dart';
import '../booking/booking_screen.dart';

/// Search Parking Screen — Stitch design.
/// Premium search bar, animated sort chips, parking cards with images,
/// distance badges, and graceful empty state.
class SearchParkingScreen extends StatefulWidget {
  final LatLng? userLocation;

  const SearchParkingScreen({super.key, this.userLocation});

  @override
  State<SearchParkingScreen> createState() => _SearchParkingScreenState();
}

class _SearchParkingScreenState extends State<SearchParkingScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  List<Map<String, dynamic>> _allParks = [];
  List<Map<String, dynamic>> _suggestions = [];

  bool _loading = true;
  LatLng? _myLocation;

  int _selectedSortIndex = 0;
  final List<_SortOption> _sortOptions = [
    _SortOption('Nearest', Icons.near_me),
    _SortOption('Cheapest', Icons.currency_rupee),
    _SortOption('Most Slots', Icons.grid_view_rounded),
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
      final snap = await FirebaseFirestore.instance
          .collection('parking_locations')
          .get();
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
          'total_floors': data['total_floors'] ?? 1,
          'image': data['image'],
          'imageUrl': data['imageUrl'],
          'description': data['description'],
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
        case 1:
          return (a['price_per_hour'] as num)
              .compareTo(b['price_per_hour'] as num);
        case 2:
          return (b['available_slots'] as num)
              .compareTo(a['available_slots'] as num);
        case 0:
        default:
          if (_myLocation == null) return 0;
          final da =
              _distance(_myLocation!, LatLng(a['latitude'], a['longitude']));
          final db =
              _distance(_myLocation!, LatLng(b['latitude'], b['longitude']));
          return da.compareTo(db);
      }
    });

    if (mounted) setState(() => _suggestions = temp);
  }

  double _distance(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
        a.latitude, a.longitude, b.latitude, b.longitude);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF9F9FB),
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 12),
              _buildSearchBar(isDark),
              const SizedBox(height: 4),
              _buildSortChips(isDark),
              Expanded(
                child: _loading
                    ? _buildShimmer(isDark)
                    : _suggestions.isEmpty
                        ? _buildEmptyState(isDark)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                            physics: const BouncingScrollPhysics(),
                            itemCount: _suggestions.length + 1,
                            itemBuilder: (_, i) {
                              if (i == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 12, left: 4),
                                  child: Text(
                                    '${_suggestions.length} result${_suggestions.length != 1 ? 's' : ''} found',
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white54
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                );
                              }
                              return _buildParkingCard(
                                  _suggestions[i - 1], isDark);
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SEARCH BAR
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSearchBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back,
                color: isDark ? Colors.white : const Color(0xFF0029B9)),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: false,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Search parking...',
                hintStyle: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close,
                  color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                  size: 20),
              onPressed: () {
                _controller.clear();
                _applyFilters();
              },
            )
          else
            IconButton(
              icon: Icon(Icons.mic_none_rounded,
                  color: AppColors.primary),
              onPressed: () => HapticFeedback.lightImpact(),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SORT CHIPS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSortChips(bool isDark) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _sortOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final selected = _selectedSortIndex == i;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedSortIndex = i);
              _applyFilters();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: selected ? AppColors.primaryGradient : null,
                color: selected
                    ? null
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.circular(999),
                border: selected
                    ? null
                    : Border.all(
                        color: isDark
                            ? Colors.white12
                            : const Color(0xFFE2E8F0)),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Icon(
                    _sortOptions[i].icon,
                    size: 16,
                    color: selected
                        ? Colors.white
                        : (isDark
                            ? Colors.white54
                            : const Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _sortOptions[i].label,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? Colors.white
                          : (isDark
                              ? Colors.white70
                              : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PARKING CARD — Premium with image, distance, price
  // ═══════════════════════════════════════════════════════════════
  Widget _buildParkingCard(Map<String, dynamic> p, bool isDark) {
    final lat = p['latitude'] as double;
    final lng = p['longitude'] as double;
    final price = p['price_per_hour'];
    final slots = p['available_slots'] as int;
    final imageUrl =
        (p['imageUrl'] as String?) ?? (p['image'] as String?);
    final rating = (p['rating'] as num?)?.toDouble();

    double? dist;
    if (_myLocation != null) {
      dist = _distance(_myLocation!, LatLng(lat, lng));
    }

    String distStr = '';
    if (dist != null) {
      distStr = dist < 1000
          ? '${dist.toStringAsFixed(0)} m'
          : '${(dist / 1000).toStringAsFixed(1)} km';
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingScreen(
              parkingId: p['id'],
              parking: p,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: 100,
                height: 96,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, e, st) =>
                            _buildImagePlaceholder(isDark),
                      )
                    : _buildImagePlaceholder(isDark),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + rating
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p['name'],
                            style: TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (rating != null) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.star,
                              size: 14, color: const Color(0xFFF59E0B)),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white70
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Tags row
                    Row(
                      children: [
                        _infoBadge(
                          '₹$price/hr',
                          AppColors.success,
                          isDark,
                        ),
                        const SizedBox(width: 8),
                        _infoBadge(
                          '$slots Slots',
                          slots > 5
                              ? const Color(0xFFF59E0B)
                              : AppColors.error,
                          isDark,
                        ),
                        if (distStr.isNotEmpty) ...[
                          const Spacer(),
                          Text(
                            distStr,
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white38
                                  : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBadge(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder(bool isDark) {
    return Container(
      color: isDark
          ? AppColors.inputBgDark
          : AppColors.primary.withValues(alpha: 0.06),
      child: Center(
        child: Icon(
          Icons.local_parking,
          color: AppColors.primary.withValues(alpha: 0.3),
          size: 32,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SHIMMER LOADING
  // ═══════════════════════════════════════════════════════════════
  Widget _buildShimmer(bool isDark) {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.all(20),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor:
            isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade200,
        highlightColor:
            isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade100,
        child: Container(
          height: 96,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceDark
                  : AppColors.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 52,
              color: isDark
                  ? Colors.white38
                  : AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No parking found',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search or adjust filters',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortOption {
  final String label;
  final IconData icon;
  const _SortOption(this.label, this.icon);
}