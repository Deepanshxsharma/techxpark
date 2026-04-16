import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../services/booking_service.dart';
import '../../services/booking_exceptions.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import 'booking_summary_screen.dart';

/// Confirm Booking Screen — Stitch design.
/// Premium ticket-style card with gradient header, dashed dividers,
/// detail grid, price summary, and gradient confirm CTA.
class ConfirmBookingScreen extends StatefulWidget {
  final Map<String, dynamic> parking;
  final String parkingId;
  final String selectedSlot;
  final int floorIndex;
  final DateTime start;
  final DateTime end;
  final Map<String, dynamic> vehicle;

  const ConfirmBookingScreen({
    super.key,
    required this.parking,
    required this.parkingId,
    required this.selectedSlot,
    required this.floorIndex,
    required this.start,
    required this.end,
    required this.vehicle,
  });

  @override
  State<ConfirmBookingScreen> createState() => _ConfirmBookingScreenState();
}

class _ConfirmBookingScreenState extends State<ConfirmBookingScreen> {
  bool _isProcessing = false;

  // ═══════════════════════════════════════════════════════════════
  // NETWORK & BOOKING LOGIC
  // ═══════════════════════════════════════════════════════════════
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _createBooking() async {
    if (_isProcessing) return;

    if (widget.start.isBefore(DateTime.now())) {
      _showError('Start time is in the past. Please go back and adjust.');
      return;
    }
    if (!widget.end.isAfter(widget.start)) {
      _showError('End time must be after start time.');
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _showError('User not authenticated.');
      setState(() => _isProcessing = false);
      return;
    }

    final hasInternet = await _hasInternetConnection();
    if (!hasInternet) {
      _showError(
          'No internet connection. Please check your network and try again.');
      setState(() => _isProcessing = false);
      return;
    }

    try {
      final ratePerHour =
          (widget.parking['price_per_hour'] as num?)?.toDouble() ?? 0.0;
      final hours = widget.end.difference(widget.start).inMinutes / 60;
      final durationCharge = ratePerHour * hours;
      final baseFee =
          (widget.parking['base_fee'] as num?)?.toDouble() ?? 0.0;
      final serviceFee =
          (widget.parking['service_fee'] as num?)?.toDouble() ?? 0.0;
      final subtotal = baseFee + durationCharge + serviceFee;
      final taxAmount = subtotal * 0.0;
      const discountAmount = 0.0;
      final totalPrice = subtotal + taxAmount - discountAmount;

      final vehicleData = <String, dynamic>{
        'number': widget.vehicle['number'],
        'type': widget.vehicle['type'] ?? 'Car',
        'vehicleNumber': widget.vehicle['number'],
        'vehicleType': widget.vehicle['type'] ?? 'Car',
        'color': widget.vehicle['color'] ?? '',
      };

      final parkingName =
          widget.parking['name']?.toString() ?? 'Parking';
      final parkingAddress =
          widget.parking['address']?.toString() ?? '';

      await BookingService.instance
          .createBooking(
            parkingId: widget.parkingId,
            parkingName: parkingName,
            parkingAddress: parkingAddress,
            slotId: widget.selectedSlot,
            slotNumber: widget.selectedSlot,
            floorIndex: widget.floorIndex,
            startTime: widget.start,
            endTime: widget.end,
            ratePerHour: ratePerHour,
            baseFee: baseFee,
            durationCharge: durationCharge,
            serviceFee: serviceFee,
            taxAmount: taxAmount,
            discountAmount: discountAmount,
            totalAmount: totalPrice,
            bookingType: 'Standard',
            vehicle: vehicleData,
            paymentMethod:
                totalPrice == 0 ? 'No Payment Required' : 'Instant Pay',
            paymentStatus:
                totalPrice == 0 ? 'skipped' : 'simulated_success',
            paymentMode: 'mock',
            paymentGateway: 'test_bypass',
            paymentReference: '',
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException(
                'Connection timed out. Please try again.'),
          );

      await notifyBookingConfirmed(
        slotName: widget.selectedSlot,
        parkingName: parkingName,
        startTime: widget.start,
        endTime: widget.end,
      );

      if (!mounted) return;
      HapticFeedback.heavyImpact();

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: BookingSummaryScreen(
              parking: widget.parking,
              docId: widget.parkingId,
              selectedSlot: widget.selectedSlot,
              floorIndex: widget.floorIndex,
              start: widget.start,
              end: widget.end,
              vehicle: widget.vehicle,
            ),
          ),
        ),
      );
    } on BookingException catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError(e.userMessage);
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError('Request timed out. Please try again.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _createBooking,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parkingName = widget.parking['name'] ?? 'Parking';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF9F9FB),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Confirm Booking',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          centerTitle: true,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  children: [_buildTicket(parkingName, isDark)],
                ),
              ),
            ),
            _buildConfirmButton(isDark),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TICKET CARD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTicket(String parkingName, bool isDark) {
    final duration = widget.end.difference(widget.start);
    final hours = duration.inMinutes ~/ 60;
    final minutes = duration.inMinutes % 60;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_parking_rounded,
                      color: Colors.white, size: 32),
                ),
                const SizedBox(height: 14),
                Text(
                  parkingName,
                  style: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Slot ${widget.selectedSlot} • Floor ${widget.floorIndex + 1}',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Dashed divider ──────────────────────────────
          _DashedDivider(isDark: isDark),

          // ── Details ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 28),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _detailItem(
                            'Date',
                            DateFormat('EEE, d MMM yyyy')
                                .format(widget.start),
                            isDark)),
                    Expanded(
                        child: _detailItem(
                            'Duration', '${hours}h ${minutes}m', isDark)),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                        child: _detailItem(
                            'Check-in',
                            DateFormat('hh:mm a').format(widget.start),
                            isDark)),
                    Expanded(
                        child: _detailItem(
                            'Check-out',
                            DateFormat('hh:mm a').format(widget.end),
                            isDark)),
                  ],
                ),
                const SizedBox(height: 20),
                _DashedDivider(isDark: isDark),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                        child: _detailItem(
                            'Vehicle',
                            (widget.vehicle['number'] ?? '')
                                .toString()
                                .toUpperCase(),
                            isDark)),
                    Expanded(
                        child: _detailItem(
                            'Type',
                            widget.vehicle['type'] ?? 'Car',
                            isDark)),
                  ],
                ),
                const SizedBox(height: 20),
                _DashedDivider(isDark: isDark),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppColors.primaryGradient
                              .createShader(bounds),
                      child: const Text(
                        'FREE',
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CONFIRM BUTTON
  // ═══════════════════════════════════════════════════════════════
  Widget _buildConfirmButton(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, -8)),
        ],
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: _isProcessing
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  _createBooking();
                },
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: _isProcessing ? null : AppColors.primaryGradient,
              color: _isProcessing
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : null,
              borderRadius: BorderRadius.circular(16),
              boxShadow: _isProcessing
                  ? []
                  : [
                      BoxShadow(
                        color:
                            AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Center(
              child: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'Confirm Booking',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// DASHED DIVIDER
// ═══════════════════════════════════════════════════════════════
class _DashedDivider extends StatelessWidget {
  final bool isDark;
  const _DashedDivider({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final dashes = (constraints.maxWidth / 10).floor();
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(
            dashes,
            (_) => Container(
              width: 5,
              height: 1,
              color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
            ),
          ),
        );
      },
    );
  }
}
