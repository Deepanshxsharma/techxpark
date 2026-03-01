import 'package:flutter/material.dart';
import 'parking_map_config.dart';
import 'floor_painter.dart';
import 'slot_painter.dart';
import 'path_painter.dart';
import 'infrastructure_painter.dart';

/// The root painter that composes the 6-phase Modular Map rendering process.
class ParkingBasementPainter extends CustomPainter {
  final List<Map<String, dynamic>> slots;
  final String bookedSlotId;
  final bool isBookedFloor;
  final double pulseValue;
  final double pathProgress;
  final double vehiclePhase;
  final bool skipStaticLayers;

  // Cached layout helper
  late final SlotLayoutHelper _layout;

  ParkingBasementPainter({
    required this.slots,
    required this.bookedSlotId,
    required this.isBookedFloor,
    required this.pulseValue,
    required this.pathProgress,
    required this.vehiclePhase,
    this.skipStaticLayers = false,
  }) {
    _layout = SlotLayoutHelper(slots.length);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (!skipStaticLayers) {
      // Phase 1 + 2: Background / Visuals
      FloorPainter.drawFloor(canvas, size);
      FloorPainter.drawWalls(canvas, size);
      FloorPainter.drawLanes(canvas, size);
      FloorPainter.drawPillars(canvas, size);
      FloorPainter.drawHazardLines(canvas, size);
      InfrastructurePainter.drawInfrastructure(canvas, size);
    }

    // Phase 2: Slots
    SlotPainter.drawSlots(
      canvas, 
      slots, 
      bookedSlotId, 
      isBookedFloor, 
      pulseValue, 
      _layout
    );

    // Phase 3: Path and Animation
    if (isBookedFloor) {
      final bookedIdx = slots.indexWhere((s) => s['id'] == bookedSlotId);
      if (bookedIdx >= 0) {
        PathPainter.drawPath(
          canvas, 
          bookedIdx, 
          pathProgress, 
          vehiclePhase, 
          _layout
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant ParkingBasementPainter oldDelegate) {
    // Only repaint if critical properties change (pulse/path handled via Listenable merge on parent)
    return oldDelegate.isBookedFloor != isBookedFloor ||
           oldDelegate.pulseValue != pulseValue ||
           oldDelegate.pathProgress != pathProgress ||
           oldDelegate.vehiclePhase != vehiclePhase ||
           oldDelegate.slots.length != slots.length;
  }
}
