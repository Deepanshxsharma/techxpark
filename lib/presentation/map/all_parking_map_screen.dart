// lib/presentation/map/all_parking_map_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:techxpark/presentation/parking_details/parking_details_screen.dart';

import '../../config/map_config.dart';

class AllParkingMapScreen extends StatefulWidget {
  const AllParkingMapScreen({super.key});

  @override
  State<AllParkingMapScreen> createState() => _AllParkingMapScreenState();
}

class _AllParkingMapScreenState extends State<AllParkingMapScreen> {
  final MapController _mapController = MapController();

  LatLng? userLocation;
  bool locationLoaded = false;

  static const LatLng fallbackCenter = LatLng(19.0760, 72.8777); // Mumbai

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  // ⭐ GET USER LOCATION SAFELY
  Future<void> _getUserLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position pos =
          await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      if (!mounted) return; // PREVENT setState AFTER dispose

      setState(() {
        userLocation = LatLng(pos.latitude, pos.longitude);
        locationLoaded = true;
      });

      if (!mounted) return;
      _mapController.move(userLocation!, 15);

    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F2FF),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Parkings Map", style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),

      // 📍 Re-center to user
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff4D6FFF),
        onPressed: () {
          if (userLocation != null) {
            _mapController.move(userLocation!, 15);
          } else {
            _getUserLocation();
          }
        },
        child: const Icon(Icons.my_location),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('parking_locations').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text("Error: ${snapshot.error}",
                  style: const TextStyle(color: Colors.red)),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final List<Marker> markers = [];

          LatLng initialCenter = userLocation ?? fallbackCenter;

          // ⭐ ADD PARKING MARKERS
          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>? ?? {};

            final double? lat =
                (data['lat'] is num) ? (data['lat'] as num).toDouble() : null;
            final double? lng =
                (data['lng'] is num) ? (data['lng'] as num).toDouble() : null;

            if (lat == null || lng == null) continue;

            final point = LatLng(lat, lng);

            markers.add(
              Marker(
                point: point,
                width: 50,
                height: 50,
                child: GestureDetector(
                  onTap: () => _openBottomSheet(data),
                  child: const Icon(
                    Icons.location_on,
                    size: 44,
                    color: Color(0xff4D6FFF),
                  ),
                ),
              ),
            );
          }

          // ⭐ ADD USER MARKER
          if (userLocation != null) {
            markers.add(
              Marker(
                point: userLocation!,
                width: 40,
                height: 40,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            );
          }

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: 13,
              maxZoom: 18,
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.tileUrl,
                maxZoom: MapConfig.maxZoom,
                userAgentPackageName: MapConfig.userAgent,
              ),
              MarkerLayer(markers: markers),
            ],
          );
        },
      ),
    );
  }

  // ⭐ Bottom sheet when tapping marker
  void _openBottomSheet(Map<String, dynamic> data) {
    final name = data['name'] ?? "Parking Spot";
    final price = (data['price'] ?? 0).toDouble();
    final distance = (data['distance'] ?? 0).toDouble();
    final rating = (data['rating'] ?? 0).toDouble();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  const Icon(Icons.local_parking,
                      size: 40, color: Color(0xff4D6FFF)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  const Icon(Icons.star, size: 18, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text(rating.toStringAsFixed(1)),
                  const Spacer(),
                  Text("₹${price.toStringAsFixed(0)} / hr"),
                ],
              ),

              const SizedBox(height: 18),

              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ParkingDetailsScreen(data: data),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff4D6FFF),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text("View Details"),
              ),
            ],
          ),
        );
      },
    );
  }
}
