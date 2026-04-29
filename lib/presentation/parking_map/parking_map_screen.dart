import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ParkingMapScreen extends StatefulWidget {
  final double lat;
  final double lng;
  final String name;

  const ParkingMapScreen({
    super.key,
    required this.lat,
    required this.lng,
    required this.name,
  });

  @override
  State<ParkingMapScreen> createState() => _ParkingMapScreenState();
}

class _ParkingMapScreenState extends State<ParkingMapScreen> {
  GoogleMapController? _mapController;

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = LatLng(widget.lat, widget.lng);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: position, zoom: 16),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        zoomControlsEnabled: false,
        markers: {
          Marker(
            markerId: const MarkerId('parking'),
            position: position,
            infoWindow: InfoWindow(title: widget.name),
          ),
        },
        onMapCreated: (controller) {
          _mapController = controller;
        },
      ),
    );
  }
}
