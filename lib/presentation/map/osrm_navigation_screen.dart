// lib/presentation/map/osrm_navigation_screen.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;

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
  State<OsrmNavigationScreen> createState() =>
      _OsrmNavigationScreenState();
}

class _OsrmNavigationScreenState
    extends State<OsrmNavigationScreen> {
  final MapController _mapController = MapController();
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
    super.dispose();
  }

  // ================= LOCATION =================

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
    _current = LatLng(loc.latitude!, loc.longitude!);

    _mapController.move(_current!, 15);

    await _fetchRoute();

    _locSub = _location.onLocationChanged.listen((loc) async {
      final newPos = LatLng(loc.latitude!, loc.longitude!);
      _current = newPos;

      if (mounted) setState(() {});
      _mapController.move(newPos, _mapController.zoom);

      final dest =
          LatLng(widget.destinationLat, widget.destinationLng);

      final dist =
          Distance().as(LengthUnit.Meter, newPos, dest);

      // Auto open timer when arrived
      if (dist < 30 &&
          !_timerOpened &&
          widget.bookingId != null &&
          widget.start != null &&
          widget.end != null) {
        _timerOpened = true;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ParkingTimerScreen(
              bookingId: widget.bookingId!,
              parking: widget.parking!,
              slot: widget.slot!,
              floorIndex: widget.floorIndex!,
              start: widget.start!,
              end: widget.end!,
            ),
          ),
        );
      }

      // Refresh route if user deviates
      if (_routePoints.isNotEmpty) {
        final moved = Distance().as(
          LengthUnit.Meter,
          _routePoints.first,
          newPos,
        );

        if (moved > 40) {
          _fetchRoute();
        }
      }
    });
  }

  // ================= ROUTE =================

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
        setState(() =>
            _routeError = "OSRM error: ${response.statusCode}");
        return;
      }

      final data = jsonDecode(response.body);
      final route = data["routes"]?[0];

      if (route == null) {
        setState(() => _routeError = "No route found");
        return;
      }

      final coords =
          (route["geometry"]["coordinates"] as List);

      _routePoints = coords
          .map((c) =>
              LatLng(c[1].toDouble(), c[0].toDouble()))
          .toList();

      _routeDistanceMeters =
          (route["distance"] as num).toDouble();
      _routeDurationSeconds =
          (route["duration"] as num).toDouble();

      _mapController.fitBounds(
        LatLngBounds.fromPoints(_routePoints),
        options:
            const FitBoundsOptions(padding: EdgeInsets.all(50)),
      );
    } catch (e) {
      setState(() => _routeError = "Route error: $e");
    } finally {
      setState(() => _loadingRoute = false);
    }
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

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final dest =
        LatLng(widget.destinationLat, widget.destinationLng);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Navigate"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRoute,
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _current ?? dest,
              zoom: 14.5,
            ),
            children: [
              // ✅ FREE + SAFE CARTO TILE (NO 403)
              TileLayer(
                urlTemplate:
                    "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
                subdomains: const ['a', 'b', 'c', 'd'],
              ),

              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 6,
                      color: Colors.blue,
                    ),
                  ],
                ),

              MarkerLayer(
                markers: [
                  if (_current != null)
                    Marker(
                      width: 40,
                      height: 40,
                      point: _current!,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 28,
                      ),
                    ),
                  Marker(
                    width: 50,
                    height: 50,
                    point: dest,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 36,
                    ),
                  ),
                ],
              ),
            ],
          ),

          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Card(
              elevation: 4,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    if (_loadingRoute)
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child:
                            CircularProgressIndicator(
                                strokeWidth: 2),
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
                                  fontWeight:
                                      FontWeight.bold),
                            )
                          : Text(
                              "${_formatDistance(_routeDistanceMeters)} • "
                              "${_formatDuration(_routeDurationSeconds)}",
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.w600),
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