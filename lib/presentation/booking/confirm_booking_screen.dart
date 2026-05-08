import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../services/booking_exceptions.dart';
import '../../services/booking_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import 'booking_confirmed_screen.dart';
import 'package:techxpark/utils/navigation_utils.dart';

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
  static const String _payAtParking = 'pay_at_parking';

  String _selectedPaymentMethod = _payAtParking;
  bool _isProcessing = false;

  double get _pricePerHour => _readDouble(
    widget.parking['price_per_hour'] ??
        widget.parking['pricePerHour'] ??
        widget.parking['price'],
  );

  int get _durationMinutes => widget.end.difference(widget.start).inMinutes;
  double get _durationHours =>
      _durationMinutes <= 0 ? 0 : _durationMinutes / 60;
  double get _basePrice => _pricePerHour * _durationHours;
  double get _gst => _basePrice * 0.18;
  double get _total => _basePrice + _gst;
  String get _vehicleNumber {
    final raw =
        widget.vehicle['number'] ??
        widget.vehicle['vehicleNumber'] ??
        widget.vehicle['vehicleNo'];
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? 'Vehicle not added' : value.toUpperCase();
  }

  String get _vehicleType {
    final raw =
        widget.vehicle['type'] ?? widget.vehicle['vehicleType'] ?? 'Car';
    final value = raw.toString().trim();
    return value.isEmpty ? 'Car' : value;
  }

  String get _paymentButtonLabel => 'Reserve Slot';

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _recheckSlotAvailability() async {
    final slotDoc = await FirebaseFirestore.instance
        .collection('parking_locations')
        .doc(widget.parkingId)
        .collection('slots')
        .doc(widget.selectedSlot)
        .get();

    if (!slotDoc.exists) {
      _showSnack('This slot is no longer available.');
      return false;
    }

    final data = slotDoc.data() ?? <String, dynamic>{};
    final status = data['status']?.toString().trim().toLowerCase() ?? '';
    final unavailable =
        data['taken'] == true ||
        data['occupied'] == true ||
        data['isOccupied'] == true ||
        data['isReserved'] == true ||
        status == 'reserved' ||
        status == 'occupied' ||
        status == 'taken' ||
        status == 'disabled' ||
        status == 'blocked';

    if (unavailable) {
      _showSnack('Slot already taken. Please choose another slot.');
      return false;
    }

    return true;
  }

  Future<void> _handlePayment() async {
    if (_isProcessing) return;

    if (widget.start.isBefore(DateTime.now())) {
      _showSnack('Start time is in the past. Please go back and adjust.');
      return;
    }
    if (!widget.end.isAfter(widget.start)) {
      _showSnack('End time must be after start time.');
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      _showSnack('User not authenticated.');
      setState(() => _isProcessing = false);
      return;
    }

    final hasInternet = await _hasInternetConnection();
    if (!hasInternet) {
      _showSnack(
        'No internet connection. Please try again.',
        retry: _handlePayment,
      );
      setState(() => _isProcessing = false);
      return;
    }

    final slotAvailable = await _recheckSlotAvailability();
    if (!slotAvailable) {
      setState(() => _isProcessing = false);
      return;
    }

    try {
      final result = await BookingService.instance
          .createBooking(
            parkingId: widget.parkingId,
            parkingName: widget.parking['name']?.toString() ?? 'Parking',
            parkingAddress: widget.parking['address']?.toString() ?? '',
            slotId: widget.selectedSlot,
            slotNumber: widget.selectedSlot,
            floorIndex: widget.floorIndex,
            startTime: widget.start,
            endTime: widget.end,
            ratePerHour: _pricePerHour,
            baseFee: 0,
            durationCharge: _basePrice,
            serviceFee: 0,
            taxAmount: _gst,
            discountAmount: 0,
            totalAmount: _total,
            bookingType: 'Standard',
            vehicle: _bookingVehiclePayload(),
            paymentMethod: _paymentMethodLabel(_selectedPaymentMethod),
            paymentStatus: 'pending',
            paymentMode: 'offline',
            paymentGateway: 'manual_collection',
            paymentReference: '',
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException(
              'Connection timed out. Please try again.',
            ),
          );

      await notifyBookingConfirmed(
        slotName: widget.selectedSlot,
        parkingName: widget.parking['name']?.toString() ?? 'Parking',
        startTime: widget.start,
        endTime: widget.end,
      );

      if (!mounted) return;
      HapticFeedback.heavyImpact();

      safePushReplacement(
        context,
        BookingConfirmedScreen(
          bookingId: result.bookingId,
          bookingData: {
            'parkingId': widget.parkingId,
            'parkingName': widget.parking['name'],
            'parkingAddress': widget.parking['address'],
            'parkingLatitude':
                widget.parking['latitude'] ?? widget.parking['lat'],
            'parkingLongitude':
                widget.parking['longitude'] ?? widget.parking['lng'],
            'slotId': widget.selectedSlot,
            'slotNumber': widget.selectedSlot,
            'floor': widget.floorIndex,
            'startTime': widget.start,
            'endTime': widget.end,
            'paymentStatus': result.paymentStatus,
            'paymentMethod': result.paymentMethod,
            'status': result.bookingStatus,
            'amount': _total,
            'totalAmount': _total,
            'vehicleNumber': _vehicleNumber,
            'vehicleType': _vehicleType,
            'vehicle': _bookingVehiclePayload(),
            'entryCode': result.entryCode,
            'qrData': result.qrData,
          },
        ),
      );
    } on BookingException catch (error) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showSnack(error.userMessage, retry: _handlePayment);
    } on TimeoutException catch (_) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showSnack('Reservation failed. Try again.', retry: _handlePayment);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showSnack('Reservation failed. Try again.', retry: _handlePayment);
    }
  }

  Map<String, dynamic> _bookingVehiclePayload() {
    return <String, dynamic>{
      ...widget.vehicle,
      'number': _vehicleNumber,
      'vehicleNumber': _vehicleNumber,
      'type': _vehicleType,
      'vehicleType': _vehicleType,
      'color': widget.vehicle['color'] ?? '',
    };
  }

  void _showSnack(String message, {VoidCallback? retry}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        action: retry == null
            ? null
            : SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: retry,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFFF9F9FB),
        body: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: topInset + 84)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCard(),
                        const SizedBox(height: 20),
                        _buildBillingCard(),
                        const SizedBox(height: 20),
                        _buildOfflineSection(),
                        const SizedBox(height: 18),
                        _buildTrustBadge(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _TopBar(onBack: () => Navigator.of(context).maybePop()),
          ],
        ),
        bottomNavigationBar: _BottomBar(
          amountLabel: _currency(_total),
          buttonLabel: _paymentButtonLabel,
          isProcessing: _isProcessing,
          onTap: _handlePayment,
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.cardShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -32,
            right: -32,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.parking['name']?.toString() ?? 'Parking',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1A1C1D),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.selectedSlot} · ${_levelLabel(widget.floorIndex)}',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF4955B3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Reserve at Gate',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 18),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0x30C5C5D8), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _SummaryInfo(
                        label: 'Duration',
                        value:
                            '${_durationLabel()} (${DateFormat('HH:mm').format(widget.start)} - ${DateFormat('HH:mm').format(widget.end)})',
                        icon: Icons.schedule_rounded,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _SummaryInfo(
                        label: 'Vehicle',
                        value: _vehicleNumber,
                        icon: _vehicleType.toLowerCase().contains('bike')
                            ? Icons.two_wheeler_rounded
                            : Icons.directions_car_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBillingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Billing Details',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: const Color(0xFF757687),
            ),
          ),
          const SizedBox(height: 16),
          _BillRow(
            label:
                'Base price (${_currency(_pricePerHour)} x ${_durationLabel()})',
            value: _currency(_basePrice),
          ),
          const SizedBox(height: 10),
          _BillRow(label: 'Platform Taxes (GST)', value: _currency(_gst)),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0x30C5C5D8)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total Amount',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1C1D),
                  ),
                ),
              ),
              Text(
                _currency(_total),
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineSection() {
    final selected = _selectedPaymentMethod == _payAtParking;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Pay at Parking',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1C1D),
                ),
              ),
            ),
            const _SectionPill(label: 'Gate payment'),
          ],
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => _selectPaymentMethod(_payAtParking),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFF1F4FF)
                  : const Color(0xFFF3F3F5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected ? AppColors.primary : const Color(0x00FFFFFF),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.12)
                            : const Color(0xFFE2E2E4),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.payments_rounded,
                        color: selected
                            ? AppColors.primary
                            : const Color(0xFF454655),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FASTag, Cash or Card',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1A1C1D),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pay directly at the gate or automated stall',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF757687),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _RadioIndicator(selected: selected),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(14),
                      border: const Border(
                        left: BorderSide(color: AppColors.primary, width: 4),
                      ),
                    ),
                    child: Text(
                      'Your slot will be reserved. Payment will be collected at parking.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A1C1D),
                        height: 1.5,
                      ),
                    ),
                  ),
                  crossFadeState: selected
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 180),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrustBadge() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_rounded, size: 16, color: Color(0x66757687)),
          const SizedBox(width: 8),
          Text(
            'SECURE RESERVATION',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: const Color(0x66757687),
            ),
          ),
        ],
      ),
    );
  }

  void _selectPaymentMethod(String method) {
    HapticFeedback.selectionClick();
    setState(() => _selectedPaymentMethod = method);
  }

  String _paymentMethodLabel(String method) {
    switch (method) {
      case _payAtParking:
      default:
        return 'Pay at Parking';
    }
  }

  String _durationLabel() {
    final hours = _durationMinutes ~/ 60;
    final minutes = _durationMinutes % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  String _levelLabel(int floorIndex) =>
      'Level ${(floorIndex + 1).toString().padLeft(2, '0')}';

  static double _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static String _currency(double value) => '₹${value.toStringAsFixed(2)}';
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;

  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, topInset + 8, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.primary,
            ),
          ),
          Expanded(
            child: Text(
              'Payment',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1A1C1D),
              ),
            ),
          ),
          Text(
            'TechXPark',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryInfo extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryInfo({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: const Color(0xFF757687),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF4955B3)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1C1D),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;

  const _BillRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF757687),
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1C1D),
          ),
        ),
      ],
    );
  }
}

class _SectionPill extends StatelessWidget {
  final String label;

  const _SectionPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFDDE3FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: const Color(0xFF303C9A),
        ),
      ),
    );
  }
}

class _RadioIndicator extends StatelessWidget {
  final bool selected;

  const _RadioIndicator({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? AppColors.primary : Colors.transparent,
        shape: BoxShape.circle,
        border: selected
            ? null
            : Border.all(color: const Color(0xFFC5C5D8), width: 2),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

class _BottomBar extends StatelessWidget {
  final String amountLabel;
  final String buttonLabel;
  final bool isProcessing;
  final VoidCallback onTap;

  const _BottomBar({
    required this.amountLabel,
    required this.buttonLabel,
    required this.isProcessing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.84),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payable Amount',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: const Color(0xFF757687),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        amountLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1C1D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: isProcessing ? null : AppColors.primaryGradient,
                  color: isProcessing ? const Color(0xFFBCC2FF) : null,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: ElevatedButton.icon(
                  onPressed: isProcessing ? null : onTap,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  icon: isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  label: Text(
                    isProcessing ? 'Processing...' : buttonLabel,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
