import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import 'parking_map_config.dart';

class InfrastructurePainter {
  /// Draws gates, boom barriers, and elevators
  static void drawInfrastructure(Canvas canvas, Size size) {
    // Boom Barriers
    _drawBoomBarrier(canvas, const Offset(ParkingMapConfig.mapW / 2 - 40, ParkingMapConfig.mapH - 25), true); // Entry
    _drawBoomBarrier(canvas, const Offset(ParkingMapConfig.mapW - 60, ParkingMapConfig.mapH - 25), false); // Exit

    // Zebra Crossing near entry
    _drawZebraCrossing(canvas, const Offset(ParkingMapConfig.mapW / 2 - 20, ParkingMapConfig.mapH - 60));

    // Elevator
    _drawElevator(canvas, const Offset(40, 40));
  }

  static void _drawBoomBarrier(Canvas canvas, Offset center, bool isEntry) {
    final basePaint = Paint()..color = Colors.grey.shade800;
    final armPaint = Paint()
      ..color = isEntry ? AppColors.success : AppColors.error
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    // The motor base
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: 12, height: 12), const Radius.circular(2)),
      basePaint,
    );

    // The arm (raised slightly)
    canvas.drawLine(
      center,
      Offset(center.dx + 40, center.dy - 10),
      armPaint,
    );
  }

  static void _drawZebraCrossing(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 6;
      
    for (int i = 0; i < 5; i++) {
       canvas.drawLine(
         Offset(center.dx - 15 + (i * 10), center.dy),
         Offset(center.dx - 15 + (i * 10), center.dy - 30),
         paint
       );
    }
  }

  static void _drawElevator(Canvas canvas, Offset center) {
    final framePaint = Paint()..color = Colors.grey.shade700;
    final doorPaint = Paint()..color = Colors.grey.shade400;

    final rect = Rect.fromCenter(center: center, width: 40, height: 40);
    canvas.drawRect(rect, framePaint);
    
    // Split doors
    canvas.drawRect(Rect.fromLTWH(rect.left + 2, rect.top + 2, 17, 36), doorPaint);
    canvas.drawRect(Rect.fromLTWH(rect.left + 21, rect.top + 2, 17, 36), doorPaint);
  }
}
