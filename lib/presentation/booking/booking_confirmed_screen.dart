import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:techxpark/presentation/booking/parking_ticket_screen.dart';
import 'package:techxpark/theme/app_colors.dart';
import 'package:techxpark/theme/app_spacing.dart';
import 'package:techxpark/theme/theme_extensions.dart';
import 'package:techxpark/widgets/app_button.dart';
import 'package:techxpark/widgets/app_card.dart';
import 'package:techxpark/widgets/main_shell.dart';

class BookingConfirmedScreen extends StatelessWidget {
  final String bookingId;
  final Map<String, dynamic> parking;
  final String parkingId;
  final String selectedSlot;
  final int floorIndex;
  final DateTime start;
  final DateTime end;
  final double amountPaid;
  final Map<String, dynamic> vehicle;
  final String bookingStatus;
  final String paymentMethod;
  final String paymentStatus;
  final String entryCode;
  final String qrData;

  const BookingConfirmedScreen({
    super.key,
    required this.bookingId,
    required this.parking,
    required this.parkingId,
    required this.selectedSlot,
    required this.floorIndex,
    required this.start,
    required this.end,
    required this.amountPaid,
    required this.vehicle,
    required this.bookingStatus,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.entryCode,
    required this.qrData,
  });

  String _vehicleValue(Object? value, {String fallback = '--'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    final parkingName = parking['name']?.toString() ?? context.tr('Parking');
    final address =
        parking['address']?.toString() ?? context.tr('Address unavailable');
    final vehicleNumber = _vehicleValue(
      vehicle['number'] ?? vehicle['vehicleNumber'] ?? vehicle['vehicleNo'],
    ).toUpperCase();
    final vehicleType = _vehicleValue(
      vehicle['type'] ?? vehicle['vehicleType'],
      fallback: context.tr('Car'),
    );

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(context.tr('Booking Confirmed'), style: context.typographyH1),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screen,
            8,
            AppSpacing.screen,
            24,
          ),
          children: [
            AppCard(
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 44,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('Your parking is confirmed'),
                    style: context.typographyH2,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.tr(
                      'Your ticket is ready. Use it to enter and manage this parking session.',
                    ),
                    style: context.typographyBodySub,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.tr('Booking Details'), style: context.typographyH3),
                  const SizedBox(height: 14),
                  _DetailRow(label: 'Parking', value: parkingName),
                  _DetailRow(label: 'Address', value: address),
                  _DetailRow(label: 'Slot', value: selectedSlot),
                  _DetailRow(
                    label: 'Floor',
                    value: floorIndex == 0
                        ? context.tr('Ground Floor')
                        : context.tr('Floor {floor}', args: {'floor': floorIndex + 1}),
                  ),
                  _DetailRow(
                    label: 'Vehicle',
                    value: '$vehicleType • $vehicleNumber',
                  ),
                  _DetailRow(
                    label: 'Entry',
                    value: DateFormat(
                      'dd MMM yyyy, hh:mm a',
                      context.localeTag,
                    ).format(start),
                  ),
                  _DetailRow(
                    label: 'Exit',
                    value: DateFormat(
                      'dd MMM yyyy, hh:mm a',
                      context.localeTag,
                    ).format(end),
                  ),
                  _DetailRow(label: 'Booking ID', value: bookingId),
                  _DetailRow(label: 'Entry Code', value: entryCode),
                  _DetailRow(label: 'Payment', value: paymentMethod),
                  _DetailRow(label: 'Payment Status', value: paymentStatus),
                  _DetailRow(
                    label: 'Amount Paid',
                    value: '₹${amountPaid.toStringAsFixed(0)}',
                    isLast: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.section),
            AppButton(
              label: 'View Ticket',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ParkingTicketScreen(
                      parking: parking,
                      slot: selectedSlot,
                      floorIndex: floorIndex,
                      start: start,
                      end: end,
                      vehicle: vehicle,
                      bookingId: bookingId,
                      parkingId: parkingId,
                      status: bookingStatus,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            AppButtonOutline(
              label: 'Go to My Bookings',
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const MainShell(initialIndex: 2),
                  ),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              context.tr(label),
              style: context.typographyCaptionSemiBold,
            ),
          ),
          Expanded(
            child: Text(value, style: context.typographyBody),
          ),
        ],
      ),
    );
  }
}