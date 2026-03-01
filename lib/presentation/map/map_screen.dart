import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../parking_details/parking_details_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Find Parking",
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("parking_locations")
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator());
          }

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No parking spots found.",
                style:
                    TextStyle(color: Colors.black54),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          final first =
              docs.first.data() as Map<String, dynamic>;

          final double initialLat =
              (first["latitude"] as num).toDouble();
          final double initialLng =
              (first["longitude"] as num).toDouble();

          List<Marker> markers = docs.map((doc) {
            final data =
                doc.data() as Map<String, dynamic>;

            final double? lat =
                (data["latitude"] as num?)?.toDouble();
            final double? lng =
                (data["longitude"] as num?)?.toDouble();

            if (lat == null || lng == null) {
              return Marker(
                width: 0,
                height: 0,
                point: const LatLng(0, 0),
                child: const SizedBox(),
              );
            }

            return Marker(
              width: 50,
              height: 50,
              point: LatLng(lat, lng),
              child: GestureDetector(
                onTap: () =>
                    _openParkingBottomSheet(
                        doc.id, data),
                child: const Icon(
                  Icons.location_on,
                  size: 40,
                  color: Colors.red,
                ),
              ),
            );
          }).toList();

          return FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter:
                  LatLng(initialLat, initialLng),
              initialZoom: 14,
            ),
            children: [
              // ✅ FREE + SAFE CARTO TILE (NO 403)
              TileLayer(
                urlTemplate:
                    "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
                subdomains: const [
                  'a',
                  'b',
                  'c',
                  'd'
                ],
              ),

              MarkerLayer(markers: markers),
            ],
          );
        },
      ),
    );
  }

  void _openParkingBottomSheet(
      String id, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
                top: Radius.circular(22)),
      ),
      builder: (context) {
        return Padding(
          padding:
              const EdgeInsets.all(20),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                data["name"] ??
                    "Parking Spot",
                style:
                    const TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
              const SizedBox(
                  height: 8),
              Text(
                data["address"] ??
                    "--",
                style: const TextStyle(
                    color:
                        Colors.black54),
              ),
              const SizedBox(
                  height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(
                      context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ParkingDetailsScreen(
                        id: id,
                        data: data,
                      ),
                    ),
                  );
                },
                style: ElevatedButton
                    .styleFrom(
                  backgroundColor:
                      const Color(
                          0xff4D6FFF),
                  minimumSize:
                      const Size(
                          double.infinity,
                          48),
                ),
                child:
                    const Text(
                  "View Details",
                  style: TextStyle(
                      color: Colors
                          .white,
                      fontSize:
                          16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}