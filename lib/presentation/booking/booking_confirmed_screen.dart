import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../widgets/main_shell.dart';
import 'package:techxpark/utils/navigation_utils.dart';
import 'parking_ticket_screen.dart';

class BookingConfirmedScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> bookingData;

  const BookingConfirmedScreen({
    super.key,
    required this.bookingId,
    required this.bookingData,
  });

  @override
  State<BookingConfirmedScreen> createState() => _BookingConfirmedScreenState();
}

class _BookingConfirmedScreenState extends State<BookingConfirmedScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    debugPrint('Booking ID: ${widget.bookingId}');

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOutCubic);
    _slideAnim = Tween<double>(begin: 30, end: 0).animate(_fadeAnim);

    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF9F9FB),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .doc(widget.bookingId)
              .snapshots(),
          builder: (context, snapshot) {
            final merged = <String, dynamic>{
              ...widget.bookingData,
              if (snapshot.data?.data() != null) ...snapshot.data!.data()!,
            };

            if (merged.isEmpty) {
              return _buildUnavailableState(isDark);
            }

            final booking = _BookingViewData.fromMap(widget.bookingId, merged);

            return SafeArea(
              child: AnimatedBuilder(
                animation: _fadeCtrl,
                builder: (context, child) => Opacity(
                  opacity: _fadeAnim.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideAnim.value),
                    child: child,
                  ),
                ),
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      pinned: true,
                      floating: false,
                      backgroundColor:
                          (isDark ? AppColors.bgDark : const Color(0xFFF9F9FB))
                              .withValues(alpha: 0.7),
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      automaticallyImplyLeading: false,
                      leading: IconButton(
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: isDark ? Colors.white : AppColors.primary,
                        ),
                        onPressed: () => safePushAndRemoveUntil(
                          context,
                          const MainShell(initialIndex: 2),
                        ),
                      ),
                      title: Text(
                        'Confirmation',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      actions: [
                        IconButton(
                          icon: Icon(
                            Icons.share_rounded,
                            color: isDark ? Colors.white70 : AppColors.primary,
                          ),
                          onPressed: () => _shareBooking(booking),
                        ),
                      ],
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: 24),
                          _buildSuccessHeader(isDark),
                          const SizedBox(height: 32),
                          _buildQrCodeSection(isDark, booking),
                          const SizedBox(height: 24),
                          _buildDetailsCard(isDark, booking),
                          const SizedBox(height: 28),
                          _buildNavigateButton(booking),
                          const SizedBox(height: 12),
                          _buildViewBookingButton(isDark, booking),
                          const SizedBox(height: 24),
                          _buildSecondaryActions(isDark, booking),
                          const SizedBox(height: 32),
                          Center(
                            child: Text.rich(
                              TextSpan(
                                text: 'Need help? ',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white54
                                      : const Color(0xFF64748B),
                                ),
                                children: const [
                                  TextSpan(
                                    text: 'Contact Support',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildUnavailableState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_rounded,
                size: 48,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to load booking',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The booking confirmation is not available right now.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessHeader(bool isDark) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) => Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(
                    alpha: 0.1 * _pulseAnim.value,
                  ),
                ),
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryLight, AppColors.primaryLight],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Booking Confirmed!',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Your parking spot has been reserved',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildQrCodeSection(bool isDark, _BookingViewData booking) {
    final qrData = booking.slotId.isEmpty
        ? ''
        : jsonEncode({'bookingId': widget.bookingId, 'slotId': booking.slotId});

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -20,
            right: -20,
            child: Opacity(
              opacity: 0.04,
              child: Icon(
                Icons.qr_code_2,
                size: 120,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
                ),
                child: qrData.isEmpty
                    ? SizedBox(
                        width: 180,
                        height: 180,
                        child: Center(
                          child: Text(
                            'QR unavailable',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      )
                    : QrImageView(
                        data: qrData,
                        version: QrVersions.auto,
                        size: 180,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF0F172A),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF0F172A),
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'SCAN AT ENTRY',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Use this QR code at the parking gate',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(bool isDark, _BookingViewData booking) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.lotName,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: isDark
                              ? Colors.white54
                              : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            booking.address,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white54
                                  : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'SLOT',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      booking.slotId,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _DetailCell(
                  label: 'DATE & TIME',
                  value: DateFormat(
                    'dd MMM, hh:mm a',
                  ).format(booking.startTime),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DetailCell(
                  label: 'DURATION',
                  value: booking.durationLabel,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DetailCell(
                  label: 'VEHICLE',
                  value: booking.vehicleNumber,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DetailCell(
                  label: 'STATUS',
                  value: booking.paymentStatusLabel,
                  isDark: isDark,
                  valueColor: booking.paymentAccent,
                  showDot: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigateButton(_BookingViewData booking) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final lat = booking.latitude;
        final lng = booking.longitude;
        if (lat == null || lng == null) {
          _showInlineMessage('Parking location unavailable.');
          return;
        }
        final uri = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.near_me_rounded, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              'Navigate to Parking',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewBookingButton(bool isDark, _BookingViewData booking) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ParkingTicketScreen(
              parking: booking.toParkingPayload(),
              slot: booking.slotId,
              floorIndex: booking.floorIndex,
              start: booking.startTime,
              end: booking.endTime,
              vehicle: booking.toVehiclePayload(),
              bookingId: widget.bookingId,
              parkingId: booking.parkingId,
              status: booking.bookingStatus,
            ),
          ),
        );
      },
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          child: Text(
            'View Booking',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryActions(bool isDark, _BookingViewData booking) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            _showInlineMessage('Calendar integration coming soon');
          },
          icon: const Icon(Icons.calendar_month_rounded, size: 18),
          label: const Text(
            'Add to Calendar',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
        Container(
          width: 1,
          height: 16,
          color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
          margin: const EdgeInsets.symmetric(horizontal: 8),
        ),
        TextButton.icon(
          onPressed: () => _shareBooking(booking),
          icon: const Icon(Icons.share_rounded, size: 18),
          label: const Text(
            'Share Booking',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ],
    );
  }

  void _shareBooking(_BookingViewData booking) {
    HapticFeedback.lightImpact();
    final text =
        'My parking booking at ${booking.lotName}, Slot ${booking.slotId}';
    SharePlus.instance.share(
      ShareParams(text: text, subject: 'TechXPark Booking'),
    );
  }

  void _showInlineMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

class _BookingViewData {
  final String bookingId;
  final String parkingId;
  final String lotName;
  final String address;
  final String slotId;
  final int floorIndex;
  final DateTime startTime;
  final DateTime endTime;
  final String vehicleNumber;
  final String vehicleType;
  final String paymentMethod;
  final String paymentStatus;
  final String bookingStatus;
  final double amount;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> raw;

  const _BookingViewData({
    required this.bookingId,
    required this.parkingId,
    required this.lotName,
    required this.address,
    required this.slotId,
    required this.floorIndex,
    required this.startTime,
    required this.endTime,
    required this.vehicleNumber,
    required this.vehicleType,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.bookingStatus,
    required this.amount,
    required this.latitude,
    required this.longitude,
    required this.raw,
  });

  factory _BookingViewData.fromMap(
    String bookingId,
    Map<String, dynamic> data,
  ) {
    return _BookingViewData(
      bookingId: bookingId,
      parkingId: _string(data['parkingId'] ?? data['lotId'], fallback: ''),
      lotName: _string(
        data['parkingName'] ?? data['lotName'],
        fallback: 'Parking',
      ),
      address: _string(
        data['parkingAddress'] ?? data['address'],
        fallback: 'Address unavailable',
      ),
      slotId: _string(data['slotNumber'] ?? data['slotId'], fallback: '--'),
      floorIndex: _int(data['floor']),
      startTime: _date(data['startTime'], fallback: DateTime.now()),
      endTime: _date(data['endTime'], fallback: DateTime.now()),
      vehicleNumber: _string(
        data['vehicleNumber'] ??
            data['vehicle']?['number'] ??
            data['vehicle']?['vehicleNumber'],
        fallback: '--',
      ).toUpperCase(),
      vehicleType: _string(
        data['vehicleType'] ??
            data['vehicle']?['type'] ??
            data['vehicle']?['vehicleType'],
        fallback: 'Car',
      ),
      paymentMethod: _string(data['paymentMethod'], fallback: 'Payment'),
      paymentStatus: _string(data['paymentStatus'], fallback: 'pending'),
      bookingStatus: _string(data['status'], fallback: 'active'),
      amount: _double(data['amount'] ?? data['totalAmount']),
      latitude: _doubleOrNull(
        data['parkingLatitude'] ?? data['latitude'] ?? data['lat'],
      ),
      longitude: _doubleOrNull(
        data['parkingLongitude'] ?? data['longitude'] ?? data['lng'],
      ),
      raw: Map<String, dynamic>.from(data),
    );
  }

  String get durationLabel {
    final duration = endTime.difference(startTime);
    if (duration.inHours >= 1) {
      return '${duration.inHours} Hour${duration.inHours > 1 ? 's' : ''}';
    }
    return '${duration.inMinutes} Min';
  }

  String get paymentStatusLabel {
    final normalized = paymentStatus.trim().toLowerCase();
    if (normalized == 'paid' ||
        normalized == 'success' ||
        normalized == 'simulated_success') {
      return 'Paid via $paymentMethod';
    }
    return 'Pay at parking';
  }

  Color get paymentAccent {
    final normalized = paymentStatus.trim().toLowerCase();
    if (normalized == 'paid' ||
        normalized == 'success' ||
        normalized == 'simulated_success') {
      return AppColors.primary;
    }
    return AppColors.warning;
  }

  Map<String, dynamic> toParkingPayload() {
    return {
      'id': parkingId,
      'name': lotName,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      ...raw,
    };
  }

  Map<String, dynamic> toVehiclePayload() {
    return {
      if (raw['vehicle'] is Map) ...Map<String, dynamic>.from(raw['vehicle']),
      'number': vehicleNumber,
      'vehicleNumber': vehicleNumber,
      'type': vehicleType,
      'vehicleType': vehicleType,
    };
  }

  static String _string(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return fallback;
    return text;
  }

  static int _int(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static double? _doubleOrNull(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime _date(dynamic value, {required DateTime fallback}) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? fallback;
    return fallback;
  }
}

class _DetailCell extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;
  final bool showDot;

  const _DetailCell({
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final vColor =
        valueColor ?? (isDark ? Colors.white : const Color(0xFF0F172A));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            if (showDot) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: vColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: vColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
