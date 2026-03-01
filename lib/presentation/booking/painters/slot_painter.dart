import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import 'parking_map_config.dart';

class SlotPainter {
  /// Draws the individual parking slots, numbers, statuses, and icons
  static void drawSlots(
    Canvas canvas, 
    List<Map<String, dynamic>> slots,
    String bookedSlotId,
    bool isBookedFloor,
    double pulseValue,
    SlotLayoutHelper layout,
  ) {
    for (int i = 0; i < slots.length; i++) {
        final slot = slots[i];
        final id = slot['id'];
        final isBooked = id == bookedSlotId && isBookedFloor;
        final status = slot['status'] as String? ?? 'available';
        
        final r = layout.slotRect(i);
        _drawSingleSlot(canvas, r, status, isBooked, pulseValue, slot);
    }
  }

  static void _drawSingleSlot(
    Canvas canvas, 
    Rect rect, 
    String status, 
    bool isBooked, 
    double pulseValue,
    Map<String, dynamic> slotData
  ) {
    Color baseColor;
    bool isOccupied = status == 'occupied';

    if (isBooked) {
      baseColor = AppColors.info;
    } else if (isOccupied) {
      baseColor = AppColors.error;
    } else if (status == 'reserved') {
      baseColor = AppColors.warning;
    } else if (status == 'blocked') {
      baseColor = AppColors.textSecondaryDark;
    } else {
      baseColor = AppColors.success;
    }

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

    // Outer glow for booked or available slots
    if (isBooked) {
      canvas.drawRRect(
        rrect.inflate(6 * pulseValue),
        Paint()
          ..color = AppColors.info.withOpacity(0.25 * pulseValue)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawRRect(rrect.inflate(2), Paint()..color = AppColors.info.withOpacity(0.4));
    } else if (status == 'available') {
      // NEW: Subtle breathing green glow for available
      canvas.drawRRect(
        rrect.inflate(3 * pulseValue),
        Paint()
          ..color = AppColors.success.withOpacity(0.15 * pulseValue)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Fill
    final fillOpacity = isBooked ? (0.7 + 0.3 * pulseValue) : (isOccupied ? 0.9 : 0.6);
    canvas.drawRRect(rrect, Paint()..color = baseColor.withOpacity(fillOpacity));

    // Boundary Lines
    canvas.drawRRect(rrect, Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);

    // Reserved Stamp
    if (status == 'reserved') {
      _drawReservedStamp(canvas, rect);
    }

    // Occupied Car Silhouette
    if (isOccupied) {
      _drawCarSilhouette(canvas, rect);
    }

    // EV / Disabled Badges
    final slotType = slotData['type'] as String? ?? 'normal';
    if (slotType == 'ev') {
      _drawIconBadge(canvas, rect, Icons.bolt_rounded, AppColors.success);
    } else if (slotType == 'disabled') {
      _drawIconBadge(canvas, rect, Icons.accessible_rounded, AppColors.info);
    }
  }

  static void _drawReservedStamp(Canvas canvas, Rect rect) {
     final textPainter = TextPainter(
      text: TextSpan(
        text: 'RESERVED',
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 6,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(-0.5); // Diagonal
    textPainter.paint(canvas, Offset(-textPainter.width / 2, -textPainter.height / 2));
    canvas.restore();
  }

  static void _drawIconBadge(Canvas canvas, Rect rect, IconData icon, Color color) {
    // Top Right small badge
    final badgeRect = Rect.fromLTWH(rect.right - 14, rect.top + 4, 10, 10);
    canvas.drawCircle(badgeRect.center, 6, Paint()..color = color);

    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      fontFamily: icon.fontFamily,
      fontSize: 8,
    ))
      ..pushStyle(ui.TextStyle(color: Colors.white))
      ..addText(String.fromCharCode(icon.codePoint));
    
    final paragraph = builder.build();
    paragraph.layout(const ui.ParagraphConstraints(width: 10));
    canvas.drawParagraph(paragraph, Offset(badgeRect.center.dx - 4, badgeRect.center.dy - 4));
  }

  static void _drawCarSilhouette(Canvas canvas, Rect rect) {
    final bodyPaint = Paint()..color = Colors.white.withOpacity(0.8);
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    
    // Draw top-down car shape (scaled to fit slot)
    final w = rect.width * 0.6;
    final h = rect.height * 0.7;
    final cx = rect.center.dx;
    final cy = rect.center.dy;

    final carRect = Rect.fromCenter(center: Offset(cx, cy), width: w, height: h);
    final rrect = RRect.fromRectAndRadius(carRect, const Radius.circular(6));

    // Shadow
    canvas.drawRRect(rrect.shift(const Offset(0, 3)), shadowPaint);
    // Body
    canvas.drawRRect(rrect, bodyPaint);
    // Windshields (dark)
    final glassPaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy - h*0.25), width: w*0.8, height: h*0.15), glassPaint); // Front
    canvas.drawRect(Rect.fromCenter(center: Offset(cx, cy + h*0.25), width: w*0.8, height: h*0.1), glassPaint);  // Back
  }
}
