import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Handles outdoor navigation launch (Google Maps / Apple Maps) and
/// proximity detection for seamless outdoor → indoor handoff.
class NavigationService {
  NavigationService._();
  static final instance = NavigationService._();

  StreamSubscription<Position>? _proximitySub;

  // ═══════════════════════════════════════════════════════════════════════════
  //  LAUNCH OUTDOOR NAVIGATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Opens turn-by-turn navigation in Google Maps (Android/iOS) or
  /// Apple Maps (iOS fallback). Falls back to browser if neither is installed.
  Future<bool> launchOutdoorNavigation({
    required double destLat,
    required double destLng,
    String? label,
  }) async {
    HapticFeedback.mediumImpact();

    // 1. Try Google Maps deep link (turn-by-turn)
    final gMapsUri = Uri.parse(
      'google.navigation:q=$destLat,$destLng&mode=d',
    );
    if (await canLaunchUrl(gMapsUri)) {
      return launchUrl(gMapsUri);
    }

    // 2. iOS → try Apple Maps
    if (Platform.isIOS) {
      final appleMapsUri = Uri.parse(
        'https://maps.apple.com/?daddr=$destLat,$destLng&dirflg=d',
      );
      if (await canLaunchUrl(appleMapsUri)) {
        return launchUrl(appleMapsUri, mode: LaunchMode.externalApplication);
      }
    }

    // 3. Fallback → Google Maps web (works everywhere)
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&travelmode=driving',
    );
    return launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PROXIMITY DETECTION — outdoor → indoor handoff
  // ═══════════════════════════════════════════════════════════════════════════

  /// Starts monitoring user position. When within [radiusMeters] of the
  /// destination, calls [onArrived]. Auto-cancels after first trigger.
  Future<void> startProximityMonitor({
    required double destLat,
    required double destLng,
    double radiusMeters = 100,
    required VoidCallback onArrived,
  }) async {
    await stopProximityMonitor();

    // Ensure permission
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
    }

    _proximitySub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) {
      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        destLat,
        destLng,
      );

      debugPrint('📍 Distance to parking: ${distance.round()}m');

      if (distance <= radiusMeters) {
        onArrived();
        stopProximityMonitor();
      }
    });
  }

  Future<void> stopProximityMonitor() async {
    await _proximitySub?.cancel();
    _proximitySub = null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Check if location services are available.
  Future<bool> isLocationAvailable() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final perm = await Geolocator.checkPermission();
    return perm != LocationPermission.denied &&
        perm != LocationPermission.deniedForever;
  }

  /// Get current distance to a point (meters). Returns null if unavailable.
  Future<double?> distanceTo(double lat, double lng) async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        lat,
        lng,
      );
    } catch (_) {
      return null;
    }
  }
}
