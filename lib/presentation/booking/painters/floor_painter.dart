import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import 'parking_map_config.dart';

class FloorPainter {
  /// Draws the main concrete floor padding bounds
  static void drawFloor(Canvas canvas, Size size) {
    // 1. Concrete Base
    final paint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, ParkingMapConfig.mapW, ParkingMapConfig.mapH),
        const Radius.circular(32),
      ),
      paint,
    );

    // 2. Concrete Tiles Grid Pattern
    final gridLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1;

    const double tileSize = 40.0;

    // Vertical lines
    for (double x = 0; x <= ParkingMapConfig.mapW; x += tileSize) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, ParkingMapConfig.mapH),
        gridLinePaint,
      );
    }
    // Horizontal lines
    for (double y = 0; y <= ParkingMapConfig.mapH; y += tileSize) {
      canvas.drawLine(
        Offset(0, y),
        Offset(ParkingMapConfig.mapW, y),
        gridLinePaint,
      );
    }

    // 3. Central Floor Watermark text
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'BASEMENT 1',
        style: TextStyle(
          color: Color(0x0CFFFFFF), // Very faint watermark
          fontSize: 80,
          fontWeight: FontWeight.w900,
          letterSpacing: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (ParkingMapConfig.mapW - textPainter.width) / 2,
        (ParkingMapConfig.mapH - textPainter.height) / 2,
      ),
    );

    // 4. Overhead Lights (Soft Yellow Rectangles)
    _drawOverheadLights(canvas);

    // 5. Compass Rose (Top Left)
    _drawCompassRose(canvas, const Offset(60, 60));
  }

  /// Draws the physical structural walls
  static void drawWalls(Canvas canvas, Size size) {
    final wallPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeJoin = StrokeJoin.round;

    final wallRect = Rect.fromLTWH(
      10,
      10,
      ParkingMapConfig.mapW - 20,
      ParkingMapConfig.mapH - 20,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(wallRect, const Radius.circular(24)),
      wallPaint,
    );
  }

  /// Draws lane outlines and directional markings painted on concrete
  static void drawLanes(Canvas canvas, Size size) {
    final laneLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    void drawDashedLine(Offset p1, Offset p2) {
      const dashWidth = 8.0;
      const dashSpace = 8.0;
      double distance = (p2 - p1).distance;
      double dashCount = distance / (dashWidth + dashSpace);
      final dx = (p2.dx - p1.dx) / dashCount;
      final dy = (p2.dy - p1.dy) / dashCount;

      for (int i = 0; i < dashCount; i++) {
        canvas.drawLine(
          Offset(p1.dx + dx * i, p1.dy + dy * i),
          Offset(
            p1.dx + dx * i + dx * (dashWidth / (dashWidth + dashSpace)),
            p1.dy + dy * i + dy * (dashWidth / (dashWidth + dashSpace)),
          ),
          laneLinePaint,
        );
      }
    }

    // Top horizontal lane
    drawDashedLine(
      const Offset(
        20,
        ParkingMapConfig.topOffset + ParkingMapConfig.slotH + 30,
      ),
      const Offset(
        ParkingMapConfig.mapW - 20,
        ParkingMapConfig.topOffset + ParkingMapConfig.slotH + 30,
      ),
    );
    _drawPaintedLaneLabel(
      canvas,
      const Offset(
        ParkingMapConfig.mapW / 2,
        ParkingMapConfig.topOffset + ParkingMapConfig.slotH + 30,
      ),
      "LANE A",
    );

    // Bottom horizontal lane
    drawDashedLine(
      const Offset(
        20,
        ParkingMapConfig.topOffset +
            ParkingMapConfig.slotH * 3 +
            ParkingMapConfig.laneH * 2 -
            10,
      ),
      const Offset(
        ParkingMapConfig.mapW - 20,
        ParkingMapConfig.topOffset +
            ParkingMapConfig.slotH * 3 +
            ParkingMapConfig.laneH * 2 -
            10,
      ),
    );
    _drawPaintedLaneLabel(
      canvas,
      const Offset(
        ParkingMapConfig.mapW / 2,
        ParkingMapConfig.topOffset +
            ParkingMapConfig.slotH * 3 +
            ParkingMapConfig.laneH * 2 -
            10,
      ),
      "LANE B",
    );
  }

  /// Draws the hazard zones near wall edges
  static void drawHazardLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color.fromARGB(255, 60, 52, 28).withValues(alpha: 0.5)
      ..strokeWidth = 4;

    for (double i = 0; i < ParkingMapConfig.mapW; i += 30) {
      canvas.drawLine(Offset(i, 20), Offset(i + 15, 30), paint);
      canvas.drawLine(
        Offset(i, ParkingMapConfig.mapH - 20),
        Offset(i + 15, ParkingMapConfig.mapH - 30),
        paint,
      );
    }
  }

  static void drawPillars(Canvas canvas, Size size) {
    final pillarOut = Paint()..color = const Color(0xFF334155);
    final pillarIn = Paint()..color = const Color(0xFF64748B);

    void drawPillar(double cx, double cy) {
      final r = Rect.fromCenter(center: Offset(cx, cy), width: 16, height: 16);
      canvas.drawRect(r, pillarOut);
      canvas.drawRect(r.deflate(3), pillarIn);
    }

    final laneCenter1 =
        ParkingMapConfig.topOffset + ParkingMapConfig.slotH + 30;
    final laneCenter2 =
        ParkingMapConfig.topOffset +
        ParkingMapConfig.slotH * 3 +
        ParkingMapConfig.laneH * 2 -
        10;

    for (double x = 120; x < ParkingMapConfig.mapW - 60; x += 180) {
      drawPillar(x, laneCenter1);
      drawPillar(x, laneCenter2);
    }
  }

  // ── PHASE 2 PRIVATE HELPERS ────────────────────────────────────────────

  static void _drawOverheadLights(Canvas canvas) {
    final lightGlow = Paint()
      ..color = const Color(0xFFFEF08A).withValues(alpha: 0.04)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    final lightFixture = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

    for (double x = 100; x < ParkingMapConfig.mapW; x += 200) {
      for (double y = 80; y < ParkingMapConfig.mapH - 50; y += 150) {
        final rect = Rect.fromCenter(
          center: Offset(x, y),
          width: 60,
          height: 6,
        );
        canvas.drawRect(rect.inflate(8), lightGlow);
        canvas.drawRect(rect, lightFixture);
      }
    }
  }

  static void _drawCompassRose(Canvas canvas, Offset center) {
    // Circle background
    canvas.drawCircle(
      center,
      24,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..style = PaintingStyle.fill,
    );

    // Outer Ring
    canvas.drawCircle(
      center,
      24,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // North Pointer (Red)
    final northPath = Path()
      ..moveTo(center.dx, center.dy - 20)
      ..lineTo(center.dx - 6, center.dy)
      ..lineTo(center.dx + 6, center.dy)
      ..close();
    canvas.drawPath(
      northPath,
      Paint()..color = const Color(0xFFEF4444).withValues(alpha: 0.8),
    );

    // South/East/West Pointers (White)
    final otherPath = Path()
      ..moveTo(center.dx, center.dy + 20)
      ..lineTo(center.dx - 6, center.dy)
      ..lineTo(center.dx + 6, center.dy)
      ..close()
      ..moveTo(center.dx - 20, center.dy)
      ..lineTo(center.dx, center.dy - 6)
      ..lineTo(center.dx, center.dy + 6)
      ..close()
      ..moveTo(center.dx + 20, center.dy)
      ..lineTo(center.dx, center.dy - 6)
      ..lineTo(center.dx, center.dy + 6)
      ..close();
    canvas.drawPath(
      otherPath,
      Paint()..color = Colors.white.withValues(alpha: 0.2),
    );

    // Center Dot
    canvas.drawCircle(
      center,
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );

    // 'N' Label
    final tp = TextPainter(
      text: const TextSpan(
        text: 'N',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - 4, center.dy - 34));
  }

  static void _drawPaintedLaneLabel(Canvas canvas, Offset pos, String label) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.15),
          fontSize: 24,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2),
    );
  }
}
