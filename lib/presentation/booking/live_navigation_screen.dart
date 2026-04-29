import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:http/http.dart' as http;

import '../../theme/app_colors.dart';

/// Live in-app navigation screen with auto-follow camera,
/// route polyline, ETA + distance display. Uber-style feel.
class LiveNavigationScreen extends StatefulWidget {
  final double destLat;
  final double destLng;
  final String parkingName;
  final String? slotLabel;

  const LiveNavigationScreen({
    super.key,
    required this.destLat,
    required this.destLng,
    required this.parkingName,
    this.slotLabel,
  });

  @override
  State<LiveNavigationScreen> createState() => _LiveNavigationScreenState();
}

class _LiveNavigationScreenState extends State<LiveNavigationScreen>
    with TickerProviderStateMixin {
  // ── Constants ──────────────────────────────────────────────────────
  static const _kApiKey = 'AIzaSyC1s15SNBpRhFp5NGBeH63rKB2yKVV6gyU';
  static const Color _blue = AppColors.primary;
  static const Color _dark = Color(0xFF0F172A);

  // ── Map ────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  LatLng? _userPosition;
  LatLng get _destination => LatLng(widget.destLat, widget.destLng);

  // ── Route ──────────────────────────────────────────────────────────
  final List<LatLng> _polylineCoords = [];
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  // ── Tracking ───────────────────────────────────────────────────────
  StreamSubscription<Position>? _positionSub;
  bool _autoFollow = true;
  bool _isLoading = true;
  bool _arrived = false;

  // ── ETA / Distance ─────────────────────────────────────────────────
  String _eta = '--';
  String _distance = '--';

  // ── Route refresh throttle ─────────────────────────────────────────
  DateTime _lastRouteUpdate = DateTime(2000);
  static const _routeRefreshInterval = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _initNavigation();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════
  //  INIT
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _initNavigation() async {
    // 1. Get current position
    final pos = await _getCurrentPosition();
    if (pos == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unable to get location')));
        Navigator.pop(context);
      }
      return;
    }

    setState(() {
      _userPosition = LatLng(pos.latitude, pos.longitude);
      _isLoading = false;
    });

    // 2. Fetch route
    await _fetchRoute();

    // 3. Build markers
    _updateMarkers();

    // 4. Start live tracking
    _startLocationStream();
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  ROUTE FETCHING
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _fetchRoute() async {
    if (_userPosition == null) return;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${_userPosition!.latitude},${_userPosition!.longitude}'
        '&destination=${_destination.latitude},${_destination.longitude}'
        '&mode=driving'
        '&key=$_kApiKey',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final data = json.decode(response.body);
      if (data['status'] != 'OK') return;

      final route = data['routes'][0];
      final leg = route['legs'][0];

      // Decode polyline
      final points = PolylinePoints.decodePolyline(
        route['overview_polyline']['points'],
      );

      final coords = points
          .map((p) => LatLng(p.latitude, p.longitude))
          .toList();

      if (!mounted) return;
      setState(() {
        _polylineCoords
          ..clear()
          ..addAll(coords);

        _eta = leg['duration']['text'] ?? '--';
        _distance = leg['distance']['text'] ?? '--';

        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: _polylineCoords,
            color: _blue,
            width: 5,
            patterns: [PatternItem.dot, PatternItem.gap(10)],
          ),
        };
        _lastRouteUpdate = DateTime.now();
      });
    } catch (e) {
      debugPrint('⚠️ Route fetch error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  LIVE LOCATION STREAM
  // ═══════════════════════════════════════════════════════════════════
  void _startLocationStream() {
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 8,
      ),
    ).listen(_onPositionUpdate);
  }

  void _onPositionUpdate(Position pos) {
    final newPos = LatLng(pos.latitude, pos.longitude);

    setState(() => _userPosition = newPos);
    _updateMarkers();

    // Auto-follow camera
    if (_autoFollow && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: newPos,
            zoom: 16.5,
            bearing: pos.heading,
            tilt: 45,
          ),
        ),
      );
    }

    // Check arrival (within 50m)
    final dist = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      _destination.latitude,
      _destination.longitude,
    );
    if (dist < 50 && !_arrived) {
      setState(() => _arrived = true);
      HapticFeedback.heavyImpact();
      _showArrivalSheet();
    }

    // Refresh route periodically
    if (DateTime.now().difference(_lastRouteUpdate) > _routeRefreshInterval) {
      _fetchRoute();
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  MARKERS
  // ═══════════════════════════════════════════════════════════════════
  void _updateMarkers() {
    final markers = <Marker>{};

    // Destination marker
    markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: _destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: InfoWindow(title: widget.parkingName),
      ),
    );

    setState(() => _markers = markers);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  ARRIVAL
  // ═══════════════════════════════════════════════════════════════════
  void _showArrivalSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF00C853),
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You\'ve Arrived!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _dark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.parkingName,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // close sheet
                  Navigator.pop(context); // back to timer
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Continue to Parking',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (_isLoading || _userPosition == null) {
      return Scaffold(
        backgroundColor: _dark,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _blue),
              const SizedBox(height: 20),
              Text(
                'Getting your location...',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ──────────────────────────────────────────────
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _userPosition!,
              zoom: 16,
              tilt: 45,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) {
              _mapController = controller;
              // Fit bounds to show both user and destination
              _fitBounds();
            },
            onCameraMoveStarted: () {
              // User manually moved — disable auto-follow
              setState(() => _autoFollow = false);
            },
          ),

          // ── Top Bar ────────────────────────────────────────────────
          _buildTopBar(),

          // ── Re-center FAB ──────────────────────────────────────────
          if (!_autoFollow)
            Positioned(
              right: 16,
              bottom: 200,
              child: FloatingActionButton.small(
                heroTag: 'recenter',
                backgroundColor: Colors.white,
                onPressed: () {
                  setState(() => _autoFollow = true);
                  if (_userPosition != null && _mapController != null) {
                    _mapController!.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: _userPosition!,
                          zoom: 16.5,
                          tilt: 45,
                        ),
                      ),
                    );
                  }
                },
                child: const Icon(Icons.my_location, color: _blue, size: 20),
              ),
            ),

          // ── Bottom Info Card ────────────────────────────────────────
          _buildBottomCard(),
        ],
      ),
    );
  }

  void _fitBounds() {
    if (_userPosition == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        _userPosition!.latitude < _destination.latitude
            ? _userPosition!.latitude
            : _destination.latitude,
        _userPosition!.longitude < _destination.longitude
            ? _userPosition!.longitude
            : _destination.longitude,
      ),
      northeast: LatLng(
        _userPosition!.latitude > _destination.latitude
            ? _userPosition!.latitude
            : _destination.latitude,
        _userPosition!.longitude > _destination.longitude
            ? _userPosition!.longitude
            : _destination.longitude,
      ),
    );
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  // ═══════════════════════════════════════════════════════════════════
  //  TOP BAR
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          8,
          MediaQuery.of(context).padding.top + 8,
          16,
          14,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _dark.withValues(alpha: 0.95),
              _dark.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Navigating to',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    widget.parkingName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Live indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Color(0xFF00C853), size: 7),
                  SizedBox(width: 5),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Color(0xFF00C853),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BOTTOM CARD
  // ═══════════════════════════════════════════════════════════════════
  Widget _buildBottomCard() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(context).padding.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),

            // ETA + Distance row
            Row(
              children: [
                // ETA
                Expanded(
                  child: _infoTile(
                    icon: Icons.access_time_filled_rounded,
                    label: 'ETA',
                    value: _eta,
                    color: _blue,
                  ),
                ),
                Container(width: 1, height: 44, color: Colors.grey.shade200),
                // Distance
                Expanded(
                  child: _infoTile(
                    icon: Icons.route_rounded,
                    label: 'Distance',
                    value: _distance,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Destination bar
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: _blue,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.parkingName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _dark,
                          ),
                        ),
                        if (widget.slotLabel != null)
                          Text(
                            widget.slotLabel!,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_arrived)
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF00C853),
                      size: 22,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // End Navigation button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text(
                  'End Navigation',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: _dark,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
