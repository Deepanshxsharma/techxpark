import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import 'parking_map_config.dart';

class PathPainter {
  /// Draws the glowing animated path with directional chevrons
  static void drawPath(
    Canvas canvas,
    int bookedIdx,
    double pathProgress,
    double vehiclePhase,
    SlotLayoutHelper layout,
  ) {
    if (bookedIdx < 0) return;

    final entry = layout.entryPoint();
    final dest = layout.slotCenter(bookedIdx);
    final rect = layout.slotRect(bookedIdx);

    // Build the waypoint path (entry -> lane center -> slot)
    final path = Path();
    path.moveTo(entry.dx, entry.dy);

    final midY = (entry.dy > rect.bottom)
        ? rect.bottom + ParkingMapConfig.laneH / 2
        : rect.top - ParkingMapConfig.laneH / 2;

    path.lineTo(entry.dx, midY); // Drive up/down to lane
    path.lineTo(dest.dx, midY);  // Turn left/right to align with slot
    path.lineTo(dest.dx, dest.dy); // Pull into slot

    // Create PathMetrics to animate along the curve
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    
    final currentDistance = metric.length * pathProgress;
    
    // Gradient Blue to Green Path
    final gradient = ui.Gradient.linear(
      entry,
      dest,
      [AppColors.info, AppColors.success],
      [0.0, 1.0],
    );

    // 1. Wide Soft Glow
    final glowPaint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    
    // 2. Bright Core
    final corePaint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    if (currentDistance > 0) {
      final drawnPath = metric.extractPath(0, currentDistance);
      canvas.drawPath(drawnPath, glowPaint);
      canvas.drawPath(drawnPath, corePaint);
      
      // Chevrons (Animated)
      _drawChevrons(canvas, metric, currentDistance, vehiclePhase);
    }

    // Vehicle Vector Dot
    if (currentDistance > 0 && currentDistance <= metric.length) {
      final isArrived = pathProgress >= 0.98;
      
      // Get tangent for rotation
      final tangent = metric.getTangentForOffset(currentDistance);
      if (tangent != null) {
        _drawVehicleVector(canvas, tangent.position, tangent.angle);
      }
      
      // Ripple effect upon arrival
      if (isArrived) {
         _drawArrivalRipples(canvas, dest, vehiclePhase);
      }
    }
  }

  static void _drawChevrons(Canvas canvas, ui.PathMetric metric, double maxDist, double phase) {
    final chevronPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final chevronShadow = Paint()
      ..color = AppColors.info.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    final dashDist = 40.0;
    // Animate offset backward so they look like they flow forward
    final offset = dashDist * (1.0 - phase);
    
    for (double d = offset; d < maxDist; d += dashDist) {
        final t = metric.getTangentForOffset(d);
        if (t != null) {
          canvas.save();
          canvas.translate(t.position.dx, t.position.dy);
          canvas.rotate(t.angle);
          // Draw `>` shape shadow
          final path = Path()
            ..moveTo(-5, -7)
            ..lineTo(4, 0)
            ..lineTo(-5, 7);
          canvas.drawPath(path, chevronShadow);
          // Draw `>` shape core
          canvas.drawPath(path, chevronPaint);
          canvas.restore();
        }
    }
  }

  static void _drawVehicleVector(Canvas canvas, Offset pos, double angle) {
    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);
    
    final carRect = Rect.fromCenter(center: Offset.zero, width: 20, height: 10);

    // Top-down car vector shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(RRect.fromRectAndRadius(carRect.shift(const Offset(0, 4)), const Radius.circular(4)), shadowPaint);

    // Top-down car vector (facing right natively)
    final paint = Paint()..color = Colors.white; // White car body for contrast
    canvas.drawRRect(RRect.fromRectAndRadius(carRect, const Radius.circular(4)), paint);
    
    // Windshield (dark)
    final glassPaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawRect(Rect.fromCenter(center: const Offset(2, 0), width: 6, height: 10), glassPaint);
    
    // Headlights (Beam effect)
    final lightPaint = Paint()
      ..shader = ui.Gradient.radial(
        const Offset(12, 0), 
        15, 
        [Colors.yellow.withValues(alpha: 0.6), Colors.yellow.withValues(alpha: 0.0)],
      );
    canvas.drawArc(Rect.fromCenter(center: const Offset(12, 0), width: 30, height: 40), -math.pi/4, math.pi/2, true, lightPaint);
    
    // Core headlights
    final coreLightPaint = Paint()..color = Colors.yellow;
    canvas.drawCircle(const Offset(11, -4), 1.5, coreLightPaint);
    canvas.drawCircle(const Offset(11, 4), 1.5, coreLightPaint);
    
    canvas.restore();
  }

  static void _drawArrivalRipples(Canvas canvas, Offset pos, double phase) {
     final paint = Paint()
       ..color = AppColors.success.withValues(alpha: 1.0 - phase)
       ..style = PaintingStyle.stroke
       ..strokeWidth = 2;
     
     canvas.drawCircle(pos, 5 + (20 * phase), paint);
     
     final phase2 = (phase + 0.5) % 1.0;
     final paint2 = Paint()
       ..color = AppColors.success.withValues(alpha: 1.0 - phase2)
       ..style = PaintingStyle.stroke
       ..strokeWidth = 2;
     canvas.drawCircle(pos, 5 + (20 * phase2), paint2);
  }
}
