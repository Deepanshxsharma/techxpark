import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../config/map_config.dart';

class DashboardMapScreen extends StatefulWidget {
  const DashboardMapScreen({super.key});

  @override
  State<DashboardMapScreen> createState() => _DashboardMapScreenState();
}

class _DashboardMapScreenState extends State<DashboardMapScreen> {
  // Theme colors from the provided HTML
  static const Color _primary = Color(0xFF0018AB);
  static const Color _primaryContainer = Color(0xFF1C31D4);
  static const Color _onSurface = Color(0xFF1A1C1D);
  static const Color _onSurfaceVariant = Color(0xFF454655);
  static const Color _surfaceContainerLow = Color(0xFFF3F3F5);
  static const Color _surfaceVariant = Color(0xFFE2E2E4);
  static const Color _error = Color(0xFFBA1A1A);
  static const Color _primaryFixed = Color(0xFFDFE0FF);
  static const Color _white = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surfaceContainerLow,
      body: Stack(
        children: [
          _buildMapBackground(),
          _buildMapControls(),
          _buildBottomSheet(),
          _buildTopHeader(),
        ],
      ),
    );
  }

  Widget _buildMapBackground() {
    return Positioned.fill(
      child: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(12.9716, 77.5946), // Bangalore coordinates
          initialZoom: 14.0,
          interactionOptions: InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: MapConfig.tileUrl,
            userAgentPackageName: MapConfig.userAgent,
            maxZoom: MapConfig.maxZoom.toInt(),
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: const LatLng(12.9716, 77.5946),
                width: 48,
                height: 48,
                child: _buildUserLocationDot(),
              ),
              Marker(
                point: const LatLng(12.9750, 77.5900),
                width: 100,
                height: 50,
                child: _buildParkingPin("₹30", isSelected: false),
                alignment: Alignment.topCenter,
              ),
              Marker(
                point: const LatLng(12.9650, 77.6000),
                width: 100,
                height: 50,
                child: _buildParkingPin("₹45", isSelected: false),
                alignment: Alignment.topCenter,
              ),
              Marker(
                point: const LatLng(12.9800, 77.5980),
                width: 100,
                height: 50,
                child: _buildParkingPin("₹40", isSelected: true),
                alignment: Alignment.topCenter,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserLocationDot() {
    // This widget can be animated further if needed
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _primary,
                shape: BoxShape.circle,
                border: Border.all(color: _white, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParkingPin(String price, {required bool isSelected}) {
    if (isSelected) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _primaryContainer,
              borderRadius: BorderRadius.circular(99),
              boxShadow: [
                BoxShadow(
                  color: _primaryContainer.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                )
              ],
              border: Border.all(color: _white, width: 2),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_parking, color: _white, size: 18),
                const SizedBox(width: 8),
                Text(
                  price,
                  style: GoogleFonts.plusJakartaSans(
                    color: _white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          ClipPath(
            clipper: _TriangleClipper(),
            child: Container(
              color: _white,
              height: 7,
              width: 14,
            ),
          ),
        ],
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _primaryFixed,
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
            )
          ],
          border: Border.all(color: _white.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.local_parking, color: _primary, size: 16),
            const SizedBox(width: 6),
            Text(
              price,
              style: GoogleFonts.plusJakartaSans(
                color: _primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildTopHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 16),
              _buildFilterChips(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: _white.withOpacity(0.4)),
            boxShadow: [
              BoxShadow(
                color: _onSurface.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 8),
              Icon(Icons.search, color: _primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  style: GoogleFonts.manrope(
                    fontWeight: FontWeight.w500,
                    color: _onSurface,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: "Search parking or destination",
                    hintStyle: GoogleFonts.manrope(color: _onSurfaceVariant),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuDuu6Ue-ca06g5wnizAowQNuCSFzPph8xThIhKUY5AHk-qJZIBOA6tby7YVKMdzWZeUSap6Yi7wxVQdO10Sj5xnniJqYIXZAbPWLnYBCFnmIKIgBM1XdUEDI9WisY5-mAFD0thC2VQwbayyxrbRaS7UhhVtUV35uVTu8jmYzoBnpg0zyy1EzMRmteHKKRA64KQYYxIfGiLh0be5gNFVMHbSlnRDse4T-giYkwSwHrQh41FGQjaD_C2p6-LpLZNB3YvsU06KTuWJ-N5y',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        children: [
          _buildChip("All", isSelected: true),
          _buildChip("Nearby"),
          _buildChip("EV Charging", icon: Icons.ev_station),
          _buildChip("Covered"),
          _buildChip("Cheapest"),
        ],
      ),
    );
  }

  Widget _buildChip(String label, {IconData? icon, bool isSelected = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(label),
        avatar: icon != null
            ? Icon(icon, size: 18, color: isSelected ? _white : _onSurface)
            : null,
        selected: isSelected,
        onSelected: (selected) {
          // Handle chip selection logic
        },
        backgroundColor: _white.withOpacity(0.75),
        selectedColor: _primaryContainer,
        labelStyle: GoogleFonts.manrope(
          color: isSelected ? _white : _onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(99),
          side: BorderSide(color: _white.withOpacity(0.5)),
        ),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  Widget _buildMapControls() {
    return Positioned(
      top: 0,
      bottom: 0,
      right: 24,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMapControlButton(Icons.layers),
            const SizedBox(height: 16),
            _buildMapControlButton(Icons.my_location, isPrimary: true),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControlButton(IconData icon, {bool isPrimary = false}) {
    return FloatingActionButton(
      onPressed: () {},
      backgroundColor: _white,
      elevation: 8.0,
      shape: const CircleBorder(),
      child: Icon(
        icon,
        color: isPrimary ? _primary : _onSurface,
        size: 24,
      ),
    );
  }

  Widget _buildBottomSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.15,
      maxChildSize: 0.8,
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: _white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -10),
              )
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _surfaceVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Nearby Spaces",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: _onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "12 parking locations found nearby",
                        style: GoogleFonts.manrope(
                          color: _onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.expand_more, size: 20),
                    label: Text(
                      "Sort by",
                      style: GoogleFonts.manrope(
                        color: _primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Parking Cards
              _buildParkingCardSelected(),
              const SizedBox(height: 16),
              _buildParkingCardSecondary(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParkingCardSelected() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuBOypi7v4Z_HAa4ut5ZFwmXgvFYBxVJMoXg0cRmk-c47X3tLpjASNIoj-XjSkB3y6TOf9Qlv5vZJ_PjeVsUMXXxJUzE8zAEm9BNLohqN7XzZRrQv7Cm_fg8SPF-0XLHKNh8_4CNqO00roDlrl51VDXiEL6h28CG6il5YGN3mvuWpgx8WOqABuDgJsdg3UhLLi_UZtcXeX53reQzgraj94XSMg0usQ4GD1aP4kFGVUaR2552bxBXIOem2MO0lAJ5WiySBEp-42FiNh1g',
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TechHub Premium Lot",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.star, color: _primary, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          "4.8",
                          style: GoogleFonts.manrope(
                            color: _primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "• 0.4 km",
                          style: GoogleFonts.manrope(color: _onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "₹40/hr",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "12 slots left",
                    style: GoogleFonts.manrope(
                      color: _error,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: _white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(99),
                    ),
                    elevation: 4,
                    shadowColor: _primary.withOpacity(0.3),
                  ),
                  child: Text(
                    "View Details",
                    style: GoogleFonts.manrope(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(14),
                  side: BorderSide(color: _surfaceVariant),
                ),
                child: Icon(Icons.directions, color: _onSurface),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParkingCardSecondary() {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                'https://lh3.googleusercontent.com/aida-public/AB6AXuAN9LdGU3UJ-A6Lm62gnMSgnkyRXpLbj1C8LOhETWlerAlN4wBhncSCH6jg35CiM-iEobUZZfohdQlXacrFMUPOJ_jzfdOzo_mmbfn-eWGYwFbRzGee6vNbNETYFoslBYuD_5zEDnxtYCdP6bL3gAztIXaezilCfbyTkZ0mTpufyEzHhh-qdKwpUvliDa5OTphHKiuZi6StA19do_dNKIg679Q35z_JmM7j7coUxYDqRKUTITNeiZZQ-F-fTJVufv6CVMnSPJ7b6kBk',
                width: 56,
                height: 56,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Central Plaza Parking",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.star, color: _onSurfaceVariant, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "4.5",
                        style: GoogleFonts.manrope(
                          color: _onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "• 0.9 km",
                        style: GoogleFonts.manrope(
                          color: _onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "₹30/hr",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "24 slots left",
                  style: GoogleFonts.manrope(
                    color: _primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
