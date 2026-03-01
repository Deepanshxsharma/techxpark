import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../config/map_config.dart';

class ParkingMapScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final LatLng position = LatLng(lat, lng);

    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),

      body: FlutterMap(
        options: MapOptions(
          initialCenter: position,
          initialZoom: 16.0,
        ),
        children: [
          // MAP LAYER
          TileLayer(
            urlTemplate: MapConfig.tileUrl,
            maxZoom: MapConfig.maxZoom,
            userAgentPackageName: MapConfig.userAgent,
          ),

          // MARKER
          MarkerLayer(
            markers: [
              Marker(
                point: position,
                width: 80,
                height: 80,
                child: Icon(
                  Icons.location_pin,
                  size: 50,
                  color: Colors.red.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
