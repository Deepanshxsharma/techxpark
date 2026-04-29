// lib/presentation/map/osrm_navigation_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:techxpark/theme/app_colors.dart';
import 'package:techxpark/utils/navigation_utils.dart';

import '../booking/parking_timer_screen.dart';

class OsrmNavigationScreen extends StatefulWidget {
  final double destinationLat;
  final double destinationLng;

  final String? bookingId;
  final Map<String, dynamic>? parking;
  final String? slot;
  final int? floorIndex;
  final DateTime? start;
  final DateTime? end;

  const OsrmNavigationScreen({
    super.key,
    required this.destinationLat,
    required this.destinationLng,
    this.bookingId,
    this.parking,
    this.slot,
    this.floorIndex,
    this.start,
    this.end,
  });

  @override
  State<OsrmNavigationScreen> createState() => _OsrmNavigationScreenState();
}

class _OsrmNavigationScreenState extends State<OsrmNavigationScreen> {
  GoogleMapController? _mapController;
  final Location _location = Location();

  LatLng? _current;
  StreamSubscription<LocationData>? _locSub;

  List<LatLng> _routePoints = [];
  double _routeDistanceMeters = 0;
  double _routeDurationSeconds = 0;

  bool _loadingRoute = false;
  String? _routeError;
  bool _timerOpened = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _locSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    if (!await _location.serviceEnabled()) {
      if (!await _location.requestService()) return;
    }

    var permission = await _location.hasPermission();
    if (permission == PermissionStatus.denied) {
      permission = await _location.requestPermission();
      if (permission != PermissionStatus.granted) return;
    }

    final loc = await _location.getLocation();
    if (loc.latitude == null || loc.longitude == null) return;

    _current = LatLng(loc.latitude!, loc.longitude!);
    if (mounted) setState(() {});
    _moveToLocation(_current!, zoom: 15);

    await _fetchRoute();

    _locSub = _location.onLocationChanged.listen((loc) async {
      if (loc.latitude == null || loc.longitude == null) return;
      final newPos = LatLng(loc.latitude!, loc.longitude!);
      _current = newPos;

      if (mounted) setState(() {});
      _moveToLocation(newPos, zoom: 15);

      final dest = LatLng(widget.destinationLat, widget.destinationLng);
      final dist = _distanceMeters(newPos, dest);

      if (dist < 30 &&
          !_timerOpened &&
          widget.bookingId != null &&
          widget.start != null &&
          widget.end != null) {
        _timerOpened = true;

        if (!mounted) return;
        // Use safePush to avoid navigator crashes when the route is
        // being disposed rapidly.
        safePush(
          context,
          ParkingTimerScreen(
            bookingId: widget.bookingId!,
            parking: widget.parking!,
            slot: widget.slot!,
            floorIndex: widget.floorIndex!,
            start: widget.start!,
            end: widget.end!,
          ),
        );
      }

      if (_routePoints.isNotEmpty) {
        final moved = _distanceMeters(_routePoints.first, newPos);
        if (moved > 40) {
          _fetchRoute();
        }
      }
    });
  }

  Future<void> _fetchRoute() async {
    if (_current == null) return;

    setState(() {
      _loadingRoute = true;
      _routeError = null;
    });

    final url = Uri.parse(
      "https://router.project-osrm.org/route/v1/driving/"
      "${_current!.longitude},${_current!.latitude};"
      "${widget.destinationLng},${widget.destinationLat}"
      "?overview=full&geometries=geojson",
    );

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        setState(() => _routeError = "OSRM error: ${response.statusCode}");
        return;
      }

      final data = jsonDecode(response.body);
      final route = data["routes"]?[0];

      if (route == null) {
        setState(() => _routeError = "No route found");
        return;
      }

      final coords = route["geometry"]["coordinates"] as List;

      _routePoints = coords
          .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
          .toList();

      _routeDistanceMeters = (route["distance"] as num).toDouble();
      _routeDurationSeconds = (route["duration"] as num).toDouble();

      _fitRouteBounds();
    } catch (e) {
      setState(() => _routeError = "Route error: $e");
    } finally {
      setState(() => _loadingRoute = false);
    }
  }

  void _moveToLocation(LatLng target, {double zoom = 15}) {
    try {
      if (_mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
      }
    } catch (e) {
      debugPrint('Failed to animate camera: $e');
    }
  }

  void _fitRouteBounds() {
    if (_routePoints.isEmpty || _mapController == null) return;

    var minLat = _routePoints.first.latitude;
    var maxLat = _routePoints.first.latitude;
    var minLng = _routePoints.first.longitude;
    var maxLng = _routePoints.first.longitude;

    for (final point in _routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50,
      ),
    );
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadiusMeters = 6371000.0;
    final dLat = _degreesToRadians(b.latitude - a.latitude);
    final dLng = _degreesToRadians(b.longitude - a.longitude);
    final lat1 = _degreesToRadians(a.latitude);
    final lat2 = _degreesToRadians(b.latitude);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180;
  }

  String _formatDistance(double meters) {
    if (meters > 1000) {
      return "${(meters / 1000).toStringAsFixed(1)} km";
    }
    return "${meters.toStringAsFixed(0)} m";
  }

  String _formatDuration(double sec) {
    final mins = (sec / 60).round();
    if (mins < 60) return "$mins min";
    return "${mins ~/ 60} h ${mins % 60} m";
  }

  @override
  Widget build(BuildContext context) {
    final dest = LatLng(widget.destinationLat, widget.destinationLng);
    final markers = <Marker>{
      if (_current != null)
        Marker(
          markerId: const MarkerId('current'),
          position: _current!,
          infoWindow: const InfoWindow(title: 'Current location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
      Marker(
        markerId: const MarkerId('destination'),
        position: dest,
        infoWindow: const InfoWindow(title: 'Destination'),
      ),
    };

    final polylines = <Polyline>{
      if (_routePoints.isNotEmpty)
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          width: 6,
          color: AppColors.primary,
        ),
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text("Navigate"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchRoute),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _current ?? dest,
              zoom: 14.5,
            ),
            myLocationEnabled: _current != null,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            markers: markers,
            polylines: polylines,
            onMapCreated: (controller) {
              _mapController = controller;
              if (_routePoints.isNotEmpty) {
                _fitRouteBounds();
              } else if (_current != null) {
                _moveToLocation(_current!, zoom: 15);
              }
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    if (_loadingRoute)
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.directions_car),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _routeError != null
                          ? Text(
                              _routeError!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : Text(
                              "${_formatDistance(_routeDistanceMeters)} • "
                              "${_formatDuration(_routeDurationSeconds)}",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
