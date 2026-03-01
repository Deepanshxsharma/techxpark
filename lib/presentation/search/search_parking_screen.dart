import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shimmer/shimmer.dart';

import '../booking/booking_screen.dart';

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
  final List<String> _sortOptions = ["Nearest", "Cheapest", "Most Slots"];

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

  // ---------------- LOCATION ----------------
  Future<void> _initLocation() async {
    try {
      if (widget.userLocation != null) {
        _myLocation = widget.userLocation;
      } else {
        final pos = await Geolocator.getCurrentPosition();
        _myLocation = LatLng(pos.latitude, pos.longitude);
      }
    } catch (_) {}
    
    // Don't call applyFilters here to avoid overwriting initial load
  }

  // ---------------- FIRESTORE ----------------
  Future<void> _loadData() async {
    // Simulate a small delay for the shimmer effect (optional)
    await Future.delayed(const Duration(milliseconds: 300)); 

    try {
      final snap =
          await FirebaseFirestore.instance.collection('parking_locations').get();

      final data = snap.docs.map((d) {
        final data = d.data();
        return {
          "id": d.id, // Capture the Document ID
          "name": data['name'] ?? '',
          "latitude": (data['latitude'] as num?)?.toDouble() ?? 0.0,
          "longitude": (data['longitude'] as num?)?.toDouble() ?? 0.0,
          "price_per_hour": data['price_per_hour'] ?? 0,
          "available_slots": data['available_slots'] ?? 0,
          "address": data['address'] ?? '',
          // Add other fields if needed by BookingScreen
          "total_floors": data['total_floors'] ?? 1,
          "image": data['image'] ?? null,
          "description": data['description'] ?? null,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _allParks = data;
          _suggestions = List.from(data); // ✅ Initially show ALL data
          _loading = false;
        });
        
        // Apply sort if location is available
        if (_myLocation != null) _applyFilters();
      }
    } catch (e) {
      debugPrint("Error loading search data: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---------------- SEARCH LOGIC ----------------
  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), _applyFilters);
  }

  void _applyFilters() {
    final query = _controller.text.trim().toLowerCase();
    List<Map<String, dynamic>> temp;

    // 1. Filter Logic
    if (query.isEmpty) {
      temp = List.from(_allParks); // ✅ Show everything if search is empty
    } else {
      temp = _allParks.where((p) {
        final name = p['name'].toString().toLowerCase();
        final address = p['address'].toString().toLowerCase();
        return name.contains(query) || address.contains(query);
      }).toList();
    }

    // 2. Sort Logic
    temp.sort((a, b) {
      switch (_selectedSortIndex) {
        case 1: // Cheapest
          return (a['price_per_hour'] as num)
              .compareTo(b['price_per_hour'] as num);

        case 2: // Most Slots
          return (b['available_slots'] as num)
              .compareTo(a['available_slots'] as num);

        case 0: // Nearest
        default:
          if (_myLocation == null) return 0;
          final da = _distance(
              _myLocation!, LatLng(a['latitude'], a['longitude']));
          final db = _distance(
              _myLocation!, LatLng(b['latitude'], b['longitude']));
          return da.compareTo(db);
      }
    });

    if (mounted) {
      setState(() => _suggestions = temp);
    }
  }

  double _distance(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
        a.latitude, a.longitude, b.latitude, b.longitude);
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            _buildSearchBar(),
            _buildFilterChips(),
            Expanded(
              child: _loading
                  ? _buildShimmer()
                  : _suggestions.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _suggestions.length,
                          itemBuilder: (_, i) =>
                              _parkingCard(_suggestions[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: false, // Set to false to prevent keyboard popup immediately
              decoration: const InputDecoration(
                hintText: "Search parking...",
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.mic_none_rounded,
                color: Color(0xFF2563EB)),
            onPressed: () => HapticFeedback.lightImpact(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _sortOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final selected = _selectedSortIndex == i;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedSortIndex = i);
              _applyFilters();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color:
                    selected ? const Color(0xFF2563EB) : Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                    color: selected
                        ? Colors.transparent
                        : Colors.grey.shade300),
              ),
              child: Center(
                child: Text(
                  _sortOptions[i],
                  style: TextStyle(
                      color:
                          selected ? Colors.white : Colors.grey.shade700,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      itemCount: 5,
      padding: const EdgeInsets.all(20),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: 100,
          margin: const EdgeInsets.only(bottom: 15),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }

  Widget _parkingCard(Map<String, dynamic> p) {
    final lat = p['latitude'];
    final lng = p['longitude'];
    final price = p['price_per_hour'];
    final slots = p['available_slots'];

    double? dist;
    if (_myLocation != null) {
      dist = _distance(_myLocation!, LatLng(lat, lng));
    }

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        // ✅ NAVIGATION FIX: 
        // Pass the 'id' separately so BookingScreen works correctly
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingScreen(
              parkingId: p['id'], // 🔑 Vital for sensor logic
              parking: p,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03), blurRadius: 10)
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.local_parking_rounded,
                  color: Color(0xFF2563EB), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p['name'],
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _tag(Icons.attach_money, "₹$price/hr",
                          Colors.green),
                      const SizedBox(width: 10),
                      _tag(Icons.grid_view_rounded,
                          "$slots Slots",
                          slots > 5 ? Colors.orange : Colors.red),
                    ],
                  ),
                ],
              ),
            ),
            if (dist != null)
              Text(
                dist < 1000
                    ? "${dist.toStringAsFixed(0)} m"
                    : "${(dist / 1000).toStringAsFixed(1)} km",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade400),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded,
              size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text("No Parking Found",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}