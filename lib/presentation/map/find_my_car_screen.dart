import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../theme/app_colors.dart';

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
  GoogleMapController? _mapController;
  LatLng? _currentPos;
  StreamSubscription<Position>? _positionStream;
  String _distanceText = "Calculating...";

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  Future<void> _startTracking() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    const settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 2,
    );
    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((position) {
          if (!mounted) return;

          final newPos = LatLng(position.latitude, position.longitude);
          final distance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            widget.targetLat,
            widget.targetLng,
          );

          setState(() {
            _currentPos = newPos;
            _distanceText = distance > 1000
                ? "${(distance / 1000).toStringAsFixed(1)} km away"
                : "${distance.toInt()} meters away";
          });

          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newPos, 18));
        });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetPos = LatLng(widget.targetLat, widget.targetLng);
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('car'),
        position: targetPos,
        infoWindow: InfoWindow(title: widget.parkingName, snippet: 'My Car'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
      if (_currentPos != null)
        Marker(
          markerId: const MarkerId('user'),
          position: _currentPos!,
          infoWindow: const InfoWindow(title: 'You'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
    };
    final polylines = <Polyline>{
      if (_currentPos != null)
        Polyline(
          polylineId: const PolylineId('user-to-car'),
          points: [_currentPos!, targetPos],
          width: 4,
          color: AppColors.primary,
          patterns: [PatternItem.dash(16), PatternItem.gap(10)],
        ),
    };

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: targetPos, zoom: 16),
            mapType: MapType.normal,
            myLocationEnabled: _currentPos != null,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            markers: markers,
            polylines: polylines,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.near_me,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Walk to ${widget.parkingName}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _distanceText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
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
}
