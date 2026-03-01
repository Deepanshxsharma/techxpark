import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:firebase_auth/firebase_auth.dart';
import '../../services/booking_service.dart';
import '../../services/booking_exceptions.dart';
import '../../services/notification_service.dart';
import '../../services/booking_helper.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'booking_summary_screen.dart';
import 'my_bookings_screen.dart';

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

    try {
      final limitReached = await hasReachedBookingLimit(userId);
      if (limitReached) {
        setState(() => _isProcessing = false);
        _showLimitDialog();
        return;
      }
    } catch (e) {
      _showError('Could not verify booking limit.');
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
      // ── Create booking via BookingService (transaction-safe) ─────────
      await BookingService.instance.createBooking(
        parkingId: widget.parkingId,
        parkingName: widget.parking['name'] ?? 'Parking',
        slotId: widget.selectedSlot,
        floorIndex: widget.floorIndex,
        startTime: widget.start,
        endTime: widget.end,
        vehicle: {
          'number': widget.vehicle['number'],
          'type': widget.vehicle['type'],
        },
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Connection timed out. Please try again.'),
      );

      // ── Notifications ────────────────────────────────────────────────
      await notifyBookingConfirmed(
        slotName: widget.selectedSlot,
        parkingName: widget.parking['name'] ?? 'Parking',
        startTime: widget.start,
        endTime: widget.end,
      );

      if (!mounted) return;
      HapticFeedback.heavyImpact(); // Success cue

      // ── Smooth Navigation ────────────────────────────────────────────
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, animation, __) => FadeTransition(
            opacity: animation,
            child: BookingSummaryScreen(
              parking: widget.parking,
              docId: widget.parkingId, // Note: BookingSummaryScreen originally expected docId as parkingId. BookingService doesn't return the docId easily here so we pass parkingId for now. The original implementation did the same.
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
      setState(() => _isProcessing = false);
      _showError(e.userMessage);
    } on TimeoutException {
      setState(() => _isProcessing = false);
      _showError('Request timed out. Please try again.');
    } catch (e) {
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

  void _showLimitDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B),
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Booking Limit Reached',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'You already have 3 active or upcoming bookings. '
              'Please complete or cancel an existing booking '
              'before making a new one.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.local_parking_rounded,
                      color: Color(0xFF2563EB), size: 18),
                  SizedBox(width: 8),
                  Text(
                    '3/3 booking slots used',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyBookingsScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'View My Bookings',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Go Back',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          ),
        ],
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
