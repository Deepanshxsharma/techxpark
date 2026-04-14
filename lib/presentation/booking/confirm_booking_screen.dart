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
import '../../theme/app_text_styles.dart';
import 'booking_summary_screen.dart';

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

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  NETWORK & BOOKING LOGIC                                               */
  /* ═══════════════════════════════════════════════════════════════════════ */
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

    // ── Validation ────────────────────────────────────────────────────
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

    // ── Network Check ─────────────────────────────────────────────────
    final hasInternet = await _hasInternetConnection();
    if (!hasInternet) {
      _showError('No internet connection. Please check your network and try again.');
      setState(() => _isProcessing = false);
      return;
    }

    try {
      // ── Price Calculation ─────────────────────────────────────────────
      final ratePerHour = (widget.parking['price_per_hour'] as num?)?.toDouble() ?? 0.0;
      final hours = widget.end.difference(widget.start).inMinutes / 60;
      final durationCharge = ratePerHour * hours;
      final baseFee = (widget.parking['base_fee'] as num?)?.toDouble() ?? 0.0;
      final serviceFee = (widget.parking['service_fee'] as num?)?.toDouble() ?? 0.0;
      final subtotal = baseFee + durationCharge + serviceFee;
      final taxAmount = subtotal * 0.0; // No tax for now
      final discountAmount = 0.0;
      final totalPrice = subtotal + taxAmount - discountAmount;

      final vehicleData = <String, dynamic>{
        'number': widget.vehicle['number'],
        'type': widget.vehicle['type'] ?? 'Car',
        'vehicleNumber': widget.vehicle['number'],
        'vehicleType': widget.vehicle['type'] ?? 'Car',
        'color': widget.vehicle['color'] ?? '',
      };

      final parkingName = widget.parking['name']?.toString() ?? 'Parking';
      final parkingAddress = widget.parking['address']?.toString() ?? '';

      // ── Create Booking (same path for free and paid) ────────────────
      await BookingService.instance.createBooking(
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
        paymentMethod: totalPrice == 0 ? 'No Payment Required' : 'Instant Pay',
        paymentStatus: totalPrice == 0 ? 'skipped' : 'simulated_success',
        paymentMode: 'mock',
        paymentGateway: 'test_bypass',
        paymentReference: '',
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Connection timed out. Please try again.'),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _createBooking,
        ),
      ),
    );
  }

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  BUILD                                                                 */
  /* ═══════════════════════════════════════════════════════════════════════ */
  @override
  Widget build(BuildContext context) {
    final parkingName = widget.parking['name'] ?? 'Parking';

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Confirm Booking', style: AppTextStyles.h2),
        centerTitle: true,
        leading: const BackButton(color: AppColors.textPrimaryLight),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  _buildTicket(parkingName),
                ],
              ),
            ),
          ),
          _buildConfirmButton(),
        ],
      ),
    );
  }

  /* ── Ticket Card ───────────────────────────────────────────────────────── */
  Widget _buildTicket(String parkingName) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const Icon(Icons.local_parking_rounded,
                    color: Colors.white, size: 48),
                const SizedBox(height: 16),
                Text(parkingName,
                    style: AppTextStyles.h2.copyWith(color: Colors.white)),
                const SizedBox(height: 8),
                Text(
                  'Slot ${widget.selectedSlot} • Floor ${widget.floorIndex + 1}',
                  style: AppTextStyles.body2.copyWith(color: Colors.white.withOpacity(0.8)),
                ),
              ],
            ),
          ),

          // ── Dashed divider ──────────────────────────────────────────
          _dashedDivider(),

          // ── Details ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _detailItem(
                            'Date',
                            DateFormat('EEE, d MMM yyyy')
                                .format(widget.start))),
                    Expanded(
                        child: _detailItem(
                            'Duration',
                            '${widget.end.difference(widget.start).inMinutes ~/ 60}h ${widget.end.difference(widget.start).inMinutes % 60}m')),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                        child: _detailItem('Check-in',
                            DateFormat('hh:mm a').format(widget.start))),
                    Expanded(
                        child: _detailItem('Check-out',
                            DateFormat('hh:mm a').format(widget.end))),
                  ],
                ),
                const SizedBox(height: 24),
                _dashedDivider(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                        child: _detailItem(
                            'Vehicle',
                            (widget.vehicle['number'] ?? '')
                                .toString()
                                .toUpperCase())),
                    Expanded(
                        child: _detailItem(
                            'Type', widget.vehicle['type'] ?? 'Car')),
                  ],
                ),
                const SizedBox(height: 24),
                _dashedDivider(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: AppTextStyles.h3),
                    Text('FREE', style: AppTextStyles.h2.copyWith(color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.captionBold.copyWith(color: AppColors.textSecondaryLight)),
        const SizedBox(height: 6),
        Text(value, style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _dashedDivider() {
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
                  color: AppColors.borderLight)),
        );
      },
    );
  }

  /* ── Confirm Button ────────────────────────────────────────────────────── */
  Widget _buildConfirmButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, -8)),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isProcessing ? null : () {
              HapticFeedback.mediumImpact();
              _createBooking();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 8,
              shadowColor: AppColors.primary.withOpacity(0.4),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('Confirm Booking', style: AppTextStyles.buttonText),
          ),
        ),
      ),
    );
  }
}
