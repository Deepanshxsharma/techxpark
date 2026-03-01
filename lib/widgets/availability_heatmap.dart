import 'package:techxpark/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

/// Real-time availability heatmap markers for the parking map.
///
/// Reads `totalSlots`, `availableSlots`, `latitude`, `longitude` from
/// each `parking_locations` document and renders color-coded animated
/// markers that update instantly via Firestore snapshots.
///
/// Color logic:
///   > 60% available → Green
///   30–60% available → Orange
///   < 30% available → Red
///   0 available → Dark Red (pulsing)

class AvailabilityHeatmapLayer extends StatelessWidget {
  final Stream<QuerySnapshot> parkingStream;
  final void Function(String docId, Map<String, dynamic> data)? onMarkerTap;

  const AvailabilityHeatmapLayer({
    super.key,
    required this.parkingStream,
    this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: parkingStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final markers = snapshot.data!.docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>;
          return _buildHeatmapMarker(doc.id, d);
        }).toList();

        return MarkerLayer(markers: markers);
      },
    );
  }

  Marker _buildHeatmapMarker(String docId, Map<String, dynamic> data) {
    final lat = (data['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (data['longitude'] as num?)?.toDouble() ?? 0.0;
    final totalSlots = (data['totalSlots'] as num?)?.toInt() ?? 0;
    final availableSlots =
        ((data['availableSlots'] as num?)?.toInt() ?? 0).clamp(0, totalSlots);
    final name = data['name'] ?? 'Parking';
    final price = data['price_per_hour'] ?? data['pricePerHour'] ?? 50;

    final ratio = totalSlots > 0 ? availableSlots / totalSlots : 0.0;

    return Marker(
      point: LatLng(lat, lng),
      width: 90,
      height: 55,
      child: GestureDetector(
        onTap: () => onMarkerTap?.call(docId, data),
        child: _HeatmapMarkerWidget(
          name: name,
          price: price,
          availableSlots: availableSlots,
          totalSlots: totalSlots,
          ratio: ratio,
          docId: docId,
          data: data,
          onLongPress: onMarkerTap != null
              ? () => onMarkerTap!(docId, data)
              : null,
        ),
      ),
    );
  }
}

// ─── ANIMATED MARKER WIDGET ────────────────────────────────────────────────

class _HeatmapMarkerWidget extends StatefulWidget {
  final String name;
  final dynamic price;
  final int availableSlots;
  final int totalSlots;
  final double ratio;
  final String docId;
  final Map<String, dynamic> data;
  final VoidCallback? onLongPress;

  const _HeatmapMarkerWidget({
    required this.name,
    required this.price,
    required this.availableSlots,
    required this.totalSlots,
    required this.ratio,
    required this.docId,
    required this.data,
    this.onLongPress,
  });

  @override
  State<_HeatmapMarkerWidget> createState() => _HeatmapMarkerWidgetState();
}

class _HeatmapMarkerWidgetState extends State<_HeatmapMarkerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Pulse only when availability is critical (< 30%)
    if (widget.ratio < 0.3 && widget.totalSlots > 0) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _HeatmapMarkerWidget old) {
    super.didUpdateWidget(old);
    if (widget.ratio < 0.3 && widget.totalSlots > 0) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = _availabilityColor(widget.ratio, widget.totalSlots);
    final showBadge = widget.availableSlots <= 5 && widget.totalSlots > 0;

    return Semantics(
      label: widget.availableSlots == 0
          ? '${widget.name}: Full, no slots available'
          : widget.ratio < 0.3
              ? '${widget.name}: Almost full, ${widget.availableSlots} slots left'
              : '${widget.name}: ${widget.availableSlots} of ${widget.totalSlots} slots available',
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: child,
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Main marker chip ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color,
                    color.withOpacity(0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.6),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Availability icon indicator (not color-only)
                  Icon(
                    widget.availableSlots == 0
                        ? Icons.block_rounded
                        : widget.ratio < 0.3
                            ? Icons.warning_amber_rounded
                            : Icons.local_parking_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),

            // ── "Only X Left" badge ───────────────────────────────────
            if (showBadge)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.availableSlots == 0
                      ? 'FULL'
                      : '${widget.availableSlots} left',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Availability → Color mapping.
  static Color _availabilityColor(double ratio, int totalSlots) {
    if (totalSlots == 0) return const Color(0xFF64748B); // gray — no data
    if (ratio > 0.6) return const Color(0xFF16A34A); // green — plenty
    if (ratio >= 0.3) return const Color(0xFFF59E0B); // orange — filling
    if (ratio > 0) return const Color(0xFFEF4444); // red — almost full
    return const Color(0xFF991B1B); // dark red — completely full
  }
}

// ─── AVAILABILITY BOTTOM SHEET ─────────────────────────────────────────────

/// Shows detailed availability info for a parking location.
void showAvailabilityBottomSheet(
  BuildContext context,
  Map<String, dynamic> data,
) {
  final total = (data['totalSlots'] as num?)?.toInt() ?? 0;
  final available =
      ((data['availableSlots'] as num?)?.toInt() ?? 0).clamp(0, total);
  final occupied = total - available;
  final ratio = total > 0 ? available / total : 0.0;
  final percent = (ratio * 100).round();
  final name = data['name'] ?? 'Parking Location';
  final lastUpdated = data['lastUpdated'] as Timestamp?;

  final color = _sheetAvailabilityColor(ratio, total);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          // Availability bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 10,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 20),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatCard(
                icon: Icons.local_parking_rounded,
                label: 'Total',
                value: '$total',
                color: AppColors.primary,
              ),
              _StatCard(
                icon: Icons.check_circle_outline_rounded,
                label: 'Available',
                value: '$available',
                color: const Color(0xFF16A34A),
              ),
              _StatCard(
                icon: Icons.directions_car_rounded,
                label: 'Occupied',
                value: '$occupied',
                color: const Color(0xFFEF4444),
              ),
              _StatCard(
                icon: Icons.percent_rounded,
                label: 'Free',
                value: '$percent%',
                color: color,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Last updated
          if (lastUpdated != null)
            Text(
              'Last updated: ${DateFormat('h:mm a, MMM d').format(lastUpdated.toDate())}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
        ],
      ),
    ),
  );
}

Color _sheetAvailabilityColor(double ratio, int total) {
  if (total == 0) return const Color(0xFF64748B);
  if (ratio > 0.6) return const Color(0xFF16A34A);
  if (ratio >= 0.3) return const Color(0xFFF59E0B);
  if (ratio > 0) return const Color(0xFFEF4444);
  return const Color(0xFF991B1B);
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
