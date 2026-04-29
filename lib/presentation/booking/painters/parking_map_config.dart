import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Centralized configuration for the Indoor Navigation Map layout and styling.
class ParkingMapConfig {
  static const double mapW = 800;
  static const double mapH = 600;

  static const double wallPad = 20;
  static const double slotW = 48;
  static const double slotH = 72;
  static const double laneH = 60;
  static const double gapBetweenSlots = 4;
  static const double topOffset = 40;
}

/// Computes slot positions relative to the realistic parking layout bounds.
class SlotLayoutHelper {
  final int totalSlots;

  // Cache to avoid recalculating Rects every frame for massive slot lists
  final Map<int, Rect> _slotCache = {};

  SlotLayoutHelper(this.totalSlots);

  int get slotsPerRow => math.max((totalSlots / 4).ceil(), 2);

  Rect slotRect(int index) {
    if (_slotCache.containsKey(index)) return _slotCache[index]!;

    final row = index ~/ slotsPerRow;
    final col = index % slotsPerRow;

    final rowAreaH = ParkingMapConfig.slotH;
    final totalLaneAreaH =
        ParkingMapConfig.mapH -
        ParkingMapConfig.wallPad * 2 -
        rowAreaH * 4 -
        ParkingMapConfig.laneH * 2;
    final extraPad = totalLaneAreaH > 0 ? totalLaneAreaH / 3 : 0;

    double x, y;

    switch (row) {
      case 0: // Top row — slots face down
        x =
            ParkingMapConfig.wallPad +
            col * (ParkingMapConfig.slotW + ParkingMapConfig.gapBetweenSlots);
        y = ParkingMapConfig.topOffset;
        break;
      case 1: // Upper-middle row — slots face up
        x =
            ParkingMapConfig.wallPad +
            col * (ParkingMapConfig.slotW + ParkingMapConfig.gapBetweenSlots);
        y =
            ParkingMapConfig.topOffset +
            rowAreaH +
            ParkingMapConfig.laneH +
            extraPad;
        break;
      case 2: // Lower-middle row — slots face down
        x =
            ParkingMapConfig.wallPad +
            col * (ParkingMapConfig.slotW + ParkingMapConfig.gapBetweenSlots);
        y =
            ParkingMapConfig.topOffset +
            (rowAreaH + ParkingMapConfig.laneH + extraPad) * 2;
        break;
      default: // Bottom row — slots face up
        x =
            ParkingMapConfig.wallPad +
            col * (ParkingMapConfig.slotW + ParkingMapConfig.gapBetweenSlots);
        y =
            ParkingMapConfig.topOffset +
            (rowAreaH + ParkingMapConfig.laneH + extraPad) * 3;
        break;
    }

    // Clamp within bounds
    x = x.clamp(
      ParkingMapConfig.wallPad,
      ParkingMapConfig.mapW - ParkingMapConfig.wallPad - ParkingMapConfig.slotW,
    );
    y = y.clamp(
      ParkingMapConfig.topOffset,
      ParkingMapConfig.mapH - ParkingMapConfig.wallPad - ParkingMapConfig.slotH,
    );

    final rect = Rect.fromLTWH(
      x,
      y,
      ParkingMapConfig.slotW,
      ParkingMapConfig.slotH,
    );
    _slotCache[index] = rect; // Cache the physical layout coordinates
    return rect;
  }

  Offset entryPoint() =>
      const Offset(ParkingMapConfig.mapW / 2, ParkingMapConfig.mapH - 8);

  Offset slotCenter(int index) {
    final r = slotRect(index);
    return r.center;
  }
}
