import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapService {
  MapService._();

  static BitmapDescriptor? _evIcon;
  static BitmapDescriptor? _normalIcon;
  static Future<void>? _markerIconFuture;

  static Future<void> loadMarkerIcons() {
    return _markerIconFuture ??= _loadMarkerIcons();
  }

  static Future<void> _loadMarkerIcons() async {
    try {
      const config = ImageConfiguration(size: Size(48, 48));
      _normalIcon = await BitmapDescriptor.asset(
        config,
        'assets/icons/parking_marker.png',
      );
      _evIcon = await BitmapDescriptor.asset(
        config,
        'assets/icons/ev_marker.png',
      );
    } catch (error) {
      debugPrint('MapService: marker icons unavailable: $error');
      _normalIcon = BitmapDescriptor.defaultMarker;
      _evIcon = BitmapDescriptor.defaultMarkerWithHue(
        BitmapDescriptor.hueGreen,
      );
    }
  }

  // ── Coordinate parsing ────────────────────────────────────────────
  //
  // Firestore sometimes stores numbers as int instead of double.
  // _toDouble handles both types plus string fallback.

  static LatLng? getLatLng(Map<String, dynamic> data) {
    final lat = _toDouble(data['latitude']);
    final lng = _toDouble(data['longitude']);

    if (lat == null || lng == null) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  // ── EV detection ────────────────────────────────────────────────

  /// Returns true if the Firestore document represents an EV-enabled lot.
  static bool isEvLot(Map<String, dynamic> data) {
    if (data.containsKey('has_ev')) {
      return _toBool(data['has_ev']);
    }

    // Check explicit boolean fields
    if (_toBool(
      data['has_ev'] ??
          data['hasEvCharging'] ??
          data['evCharging'] ??
          data['ev_charging'] ??
          data['supportsEv'],
    )) {
      return true;
    }
    // Check if ev_slots > 0
    final evSlots = _toDouble(data['ev_slots'] ?? data['evSlots']);
    if (evSlots != null && evSlots > 0) return true;
    // Check features list
    final features = data['features'];
    if (features is List) {
      final lower = features.map((e) => e.toString().toLowerCase()).toList();
      if (lower.contains('ev') ||
          lower.contains('charging') ||
          lower.contains('evcharging')) {
        return true;
      }
    }
    return false;
  }

  static bool _toBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    if (value is num) return value != 0;
    return false;
  }

  // ── Marker factory ────────────────────────────────────────────────

  static Marker? createMarker({
    required String id,
    required Map<String, dynamic> data,
    required VoidCallback onTap,
    BitmapDescriptor? icon,
  }) {
    final position = getLatLng(data);
    if (position == null) {
      debugPrint('⚠️ MapService: skipped marker "$id" — invalid lat/lng');
      return null;
    }

    return Marker(
      markerId: MarkerId(id),
      position: position,
      icon: icon ?? _normalIcon ?? BitmapDescriptor.defaultMarker,
      infoWindow: InfoWindow(
        title: data['name']?.toString() ?? 'Parking',
        snippet: '₹${readNumber(data['price_per_hour']).toStringAsFixed(0)}/hr',
        onTap: onTap,
      ),
      onTap: onTap,
    );
  }

  /// Creates an EV-styled green marker with ⚡ info snippet.
  static Marker? createEvMarker({
    required String id,
    required Map<String, dynamic> data,
    required VoidCallback onTap,
  }) {
    final position = getLatLng(data);
    if (position == null) {
      debugPrint('⚠️ MapService: skipped EV marker "$id" — invalid lat/lng');
      return null;
    }

    final evSlots = readInt(data['ev_slots'] ?? data['evSlots']);
    final evAvail = readInt(
      data['ev_available'] ?? data['evAvailable'],
      fallback: evSlots,
    );
    final price = readNumber(data['price_per_hour']);

    return Marker(
      markerId: MarkerId(id),
      position: position,
      icon: _evIcon ?? BitmapDescriptor.defaultMarker,
      infoWindow: InfoWindow(
        title: '⚡ EV ${data['name']?.toString() ?? 'Parking'}',
        snippet:
            '⚡ $evAvail/$evSlots EV slots • ₹${price.toStringAsFixed(0)}/hr',
        onTap: onTap,
      ),
      onTap: onTap,
    );
  }

  /// Auto-selects normal or EV marker based on data fields.
  static Marker? createSmartMarker({
    required String id,
    required Map<String, dynamic> data,
    required VoidCallback onTap,
  }) {
    if (isEvLot(data)) {
      return createEvMarker(id: id, data: data, onTap: onTap);
    }
    return createMarker(id: id, data: data, onTap: onTap);
  }

  // ── Location with proper permission handling ─────────────────────

  static Future<MapLocationResult> getUserLocationResult() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('⚠️ MapService: location services disabled');
      return const MapLocationResult(
        message: 'Turn on GPS to sort parking by your current location.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      debugPrint('⚠️ MapService: location permission denied');
      return const MapLocationResult(
        message: 'Location permission is needed to show nearby parking.',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint(
        '⚠️ MapService: location permission permanently denied — '
        'user must enable in Settings',
      );
      return const MapLocationResult(
        message:
            'Location is blocked. Enable it from Settings to use nearby parking.',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      ).timeout(const Duration(seconds: 10));
      return MapLocationResult(
        position: LatLng(position.latitude, position.longitude),
      );
    } catch (e) {
      debugPrint('⚠️ MapService: failed to get location — $e');
      return const MapLocationResult(
        message:
            'Current location is unavailable. Showing available parking lots.',
      );
    }
  }

  static Future<LatLng?> getUserLocation() async {
    final result = await getUserLocationResult();
    return result.position;
  }

  // ── Type-safe number parsers ──────────────────────────────────────
  //
  // Firestore can return int, double, or even String for numeric fields.

  static double readNumber(dynamic value, {double fallback = 0}) {
    return _toDouble(value) ?? fallback;
  }

  static int readInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  /// Safe converter that handles int → double, double, and String.
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class MapLocationResult {
  final LatLng? position;
  final String? message;

  const MapLocationResult({this.position, this.message});

  bool get hasLocation => position != null;
}
