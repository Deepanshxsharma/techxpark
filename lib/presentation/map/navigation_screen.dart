import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class NavigationScreen extends StatefulWidget {
  final double destinationLat;
  final double destinationLng;

  const NavigationScreen({
    super.key,
    required this.destinationLat,
    required this.destinationLng,
  });

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  GoogleMapController? mapController;
  Location location = Location();

  LatLng? currentLocation;
  List<LatLng> polylineCoordinates = [];
  bool isRouteLoaded = false;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    final hasPermission = await location.requestPermission();
    if (hasPermission != PermissionStatus.granted) return;

    final loc = await location.getLocation();
    setState(() {
      currentLocation = LatLng(loc.latitude!, loc.longitude!);
    });

    _getPolylineRoute();
  }

  Future<void> _getPolylineRoute() async {
    PolylinePoints polylinePoints = PolylinePoints();

    const googleApiKey = "YOUR_GOOGLE_MAPS_API_KEY"; // Insert key here

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey,
      PointLatLng(currentLocation!.latitude, currentLocation!.longitude),
      PointLatLng(widget.destinationLat, widget.destinationLng),
    );

    if (result.points.isNotEmpty) {
      polylineCoordinates = result.points
          .map((e) => LatLng(e.latitude, e.longitude))
          .toList();

      setState(() {
        isRouteLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentLocation == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Navigation"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: currentLocation!,
          zoom: 15.5,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: (controller) {
          mapController = controller;
        },
        markers: {
          Marker(
            markerId: const MarkerId("destination"),
            position: LatLng(widget.destinationLat, widget.destinationLng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
          ),
        },
        polylines: isRouteLoaded
            ? {
                Polyline(
                  polylineId: const PolylineId("route"),
                  points: polylineCoordinates,
                  color: Colors.blue,
                  width: 6,
                )
              }
            : {},
      ),
    );
  }
}
