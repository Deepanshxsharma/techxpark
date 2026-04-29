import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/map_service.dart';

/// Real-time availability heatmap markers for parking maps.
///
/// Reads `totalSlots`, `available_slots`, `latitude`, and `longitude` from
/// each `parking_locations` document and renders Google Maps markers that
/// update instantly via Firestore snapshots.
class AvailabilityHeatmapLayer extends StatefulWidget {
  final Stream<QuerySnapshot> parkingStream;
  final void Function(String docId, Map<String, dynamic> data)? onMarkerTap;
  final LatLng initialCenter;

  const AvailabilityHeatmapLayer({
    super.key,
    required this.parkingStream,
    this.onMarkerTap,
    this.initialCenter = const LatLng(19.0760, 72.8777),
  });

  @override
  State<AvailabilityHeatmapLayer> createState() =>
      _AvailabilityHeatmapLayerState();
}

class _AvailabilityHeatmapLayerState extends State<AvailabilityHeatmapLayer> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: widget.parkingStream,
      builder: (context, snapshot) {
        final markers = (snapshot.data?.docs ?? const [])
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final total = MapService.readInt(data['totalSlots']);
              final available = MapService.readInt(
                data['available_slots'],
              ).clamp(0, total).toInt();
              final hue = _markerHue(available, total);

              return MapService.createMarker(
                id: doc.id,
                data: data,
                icon: BitmapDescriptor.defaultMarkerWithHue(hue),
                onTap: () => widget.onMarkerTap?.call(doc.id, data),
              );
            })
            .whereType<Marker>()
            .toSet();

        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.initialCenter,
            zoom: 13,
          ),
          zoomControlsEnabled: false,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          markers: markers,
          onMapCreated: (controller) {
            _mapController = controller;
          },
        );
      },
    );
  }

  double _markerHue(int available, int total) {
    if (available <= 0) return BitmapDescriptor.hueRed;
    if (total <= 0) return BitmapDescriptor.hueOrange;

    final ratio = available / total;
    if (ratio > 0.6) return BitmapDescriptor.hueGreen;
    if (ratio >= 0.3) return BitmapDescriptor.hueOrange;
    return BitmapDescriptor.hueRed;
  }
}
