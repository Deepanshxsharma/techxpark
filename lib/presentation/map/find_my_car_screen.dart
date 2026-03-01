import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class FindMyCarScreen extends StatefulWidget {
  final double targetLat;
  final double targetLng;
  final String parkingName;

  const FindMyCarScreen({
    super.key,
    required this.targetLat,
    required this.targetLng,
    required this.parkingName,
  });

  @override
  State<FindMyCarScreen> createState() => _FindMyCarScreenState();
}

class _FindMyCarScreenState extends State<FindMyCarScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPos;
  StreamSubscription<Position>? _positionStream;
  String _distanceText = "Calculating...";

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  void _startTracking() async {
    // 1. Check Permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    // 2. Start Live Stream
    const settings = LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 2);
    _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen((Position pos) {
      if (!mounted) return;

      final newPos = LatLng(pos.latitude, pos.longitude);
      final dist = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, 
        widget.targetLat, widget.targetLng
      );

      setState(() {
        _currentPos = newPos;
        // Format Distance nicely
        _distanceText = dist > 1000 
            ? "${(dist / 1000).toStringAsFixed(1)} km away" 
            : "${dist.toInt()} meters away";
      });

      // Keep the user centered, or fit bounds to show both user and car
      _mapController.move(newPos, 18); 
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetPos = LatLng(widget.targetLat, widget.targetLng);

    return Scaffold(
      body: Stack(
        children: [
          // 1. THE RADAR MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: targetPos,
              initialZoom: 16,
            ),
            children: [
              TileLayer(
                // Use a Dark Mode map for that "Radar" look
                urlTemplate: "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png",
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              
              // The Path Line (User -> Car)
              if (_currentPos != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_currentPos!, targetPos],
                      strokeWidth: 4.0,
                      color: Colors.blueAccent,
                      isDotted: true, // Makes it look like a guide path
                    ),
                  ],
                ),

              MarkerLayer(
                markers: [
                  // 🚗 The Car Marker (Destination)
                  Marker(
                    point: targetPos,
                    width: 60,
                    height: 60,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.directions_car_filled, color: Colors.red, size: 24),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                          child: const Text("My Car", style: TextStyle(color: Colors.white, fontSize: 10)),
                        )
                      ],
                    ),
                  ),

                  // 🔵 The User Marker (Moving)
                  if (_currentPos != null)
                    Marker(
                      point: _currentPos!,
                      width: 20,
                      height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.5), blurRadius: 10)]
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 2. BACK BUTTON
          Positioned(
            top: 50, left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 3. BOTTOM INFO CARD
          Positioned(
            bottom: 40, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B), // Dark Slate
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.near_me, color: Colors.blueAccent, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Walk to ${widget.parkingName}", 
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 4),
                        Text(_distanceText, 
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)
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
}