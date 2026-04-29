// lib/presentation/map/all_parking_map_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:techxpark/presentation/parking_details/lot_detail_navigation.dart';

import '../../services/map_service.dart';
import '../../services/parking_filter_service.dart';
import '../../theme/app_colors.dart';

class AllParkingMapScreen extends StatefulWidget {
  const AllParkingMapScreen({super.key});

  @override
  State<AllParkingMapScreen> createState() => _AllParkingMapScreenState();
}

class _AllParkingMapScreenState extends State<AllParkingMapScreen> {
  GoogleMapController? _mapController;

  LatLng? userLocation;
  bool locationLoaded = false;

  static const LatLng fallbackCenter = LatLng(19.0760, 72.8777);

  @override
  void initState() {
    super.initState();
    MapService.loadMarkerIcons().then((_) {
      if (mounted) setState(() {});
    });
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    try {
      final location = await MapService.getUserLocation();
      if (!mounted || location == null) return;

      setState(() {
        userLocation = location;
        locationLoaded = true;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && userLocation != null) {
          _moveToLocation(userLocation!);
        }
      });
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF6F2FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Parkings Map",
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () {
          if (userLocation != null) {
            _moveToLocation(userLocation!);
          } else {
            _getUserLocation();
          }
        },
        child: const Icon(Icons.my_location),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: ParkingFilterService.streamParking(
          ParkingFilterService.allFilterLabel,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          debugPrint('TOTAL DOCS: ${docs.length}');
          if (docs.isNotEmpty) {
            debugPrint("Docs count: ${docs.length}");
            debugPrint("FIRST DOC: ${docs.first.data()}");
          }

          final markers = docs
              .map((doc) {
                final data = {
                  ...(doc.data() as Map<String, dynamic>? ?? {}),
                  'id': doc.id,
                };

                return MapService.createSmartMarker(
                  id: doc.id,
                  data: data,
                  onTap: () => _openBottomSheet(data),
                );
              })
              .whereType<Marker>()
              .toSet();
          debugPrint("Markers count: ${markers.length}");

          return GoogleMap(
            initialCameraPosition: CameraPosition(
              target: userLocation ?? fallbackCenter,
              zoom: 13,
            ),
            myLocationEnabled: userLocation != null,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
            markers: markers,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          );
        },
      ),
    );
  }

  void _moveToLocation(LatLng target) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
  }

  void _openBottomSheet(Map<String, dynamic> data) {
    final name = data['name'] ?? "Parking Spot";
    final price = MapService.readNumber(data['price_per_hour']);
    final rating = MapService.readNumber(
      data['ratingAverage'] ?? data['rating_average'],
    );
    final isEv = MapService.isEvLot(data);
    final evSlots = MapService.readInt(data['ev_slots'] ?? data['evSlots']);
    final evAvail = MapService.readInt(
      data['ev_available'] ?? data['evAvailable'],
      fallback: evSlots,
    );
    final accentColor = isEv ? const Color(0xFF00C853) : AppColors.primary;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    isEv ? Icons.ev_station_rounded : Icons.local_parking,
                    size: 40,
                    color: accentColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isEv)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F7E9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.bolt_rounded,
                                    size: 14,
                                    color: Color(0xFF00C853),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    '$evAvail/$evSlots EV slots',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF00C853),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.star, size: 18, color: Colors.amber),
                  const SizedBox(width: 6),
                  Text(rating.toStringAsFixed(1)),
                  const Spacer(),
                  Text(
                    "₹${price.toStringAsFixed(0)} / hr",
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  openLotDetail(context, data['id']?.toString() ?? '', data);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text("View Details"),
              ),
            ],
          ),
        );
      },
    );
  }
}
