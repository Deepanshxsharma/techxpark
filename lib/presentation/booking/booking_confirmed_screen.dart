import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme/app_colors.dart';
import '../../widgets/main_shell.dart';
import 'parking_ticket_screen.dart';

/// Booking Confirmed Screen — Stitch "Confirmation" design.
/// Animated success icon, live QR code, grid details card, premium actions.
class BookingConfirmedScreen extends StatefulWidget {
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

  @override
  State<BookingConfirmedScreen> createState() => _BookingConfirmedScreenState();
}

class _BookingConfirmedScreenState extends State<BookingConfirmedScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the success icon background
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Entry animation
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

  String _vehicleValue(Object? value, {String fallback = '--'}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final parkingName = widget.parking['name']?.toString() ?? 'Parking';
    final address =
        widget.parking['address']?.toString() ?? 'Address unavailable';
    final vehicleNumber = _vehicleValue(
      widget.vehicle['number'] ??
          widget.vehicle['vehicleNumber'] ??
          widget.vehicle['vehicleNo'],
    ).toUpperCase();

    final duration = widget.end.difference(widget.start);
    final durationStr = duration.inHours >= 1
        ? '${duration.inHours} Hour${duration.inHours > 1 ? 's' : ''}'
        : '${duration.inMinutes} Min';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF9F9FB),
        body: SafeArea(
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
                // ═══════════════════════════════════════
                // TOP APP BAR
                // ═══════════════════════════════════════
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
                    icon: Icon(Icons.arrow_back,
                        color:
                            isDark ? Colors.white : const Color(0xFF0029B9)),
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const MainShell(initialIndex: 2)),
                      (route) => false,
                    ),
                  ),
                  title: Text(
                    'Confirmation',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.share,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF0029B9)),
                      onPressed: () => _shareBooking(parkingName),
                    ),
                  ],
                ),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 24),

                      // ═══════════════════════════════════════
                      // SUCCESS HEADER
                      // ═══════════════════════════════════════
                      _buildSuccessHeader(isDark),

                      const SizedBox(height: 32),

                      // ═══════════════════════════════════════
                      // QR CODE SECTION
                      // ═══════════════════════════════════════
                      _buildQrCodeSection(isDark),

                      const SizedBox(height: 24),

                      // ═══════════════════════════════════════
                      // BOOKING DETAILS CARD
                      // ═══════════════════════════════════════
                      _buildDetailsCard(
                        isDark,
                        parkingName,
                        address,
                        vehicleNumber,
                        durationStr,
                      ),

                      const SizedBox(height: 28),

                      // ═══════════════════════════════════════
                      // PRIMARY ACTIONS
                      // ═══════════════════════════════════════
                      _buildNavigateButton(),
                      const SizedBox(height: 12),
                      _buildViewBookingButton(isDark, parkingName),

                      const SizedBox(height: 24),

                      // ═══════════════════════════════════════
                      // SECONDARY ACTIONS
                      // ═══════════════════════════════════════
                      _buildSecondaryActions(isDark),

                      const SizedBox(height: 32),

                      // ═══════════════════════════════════════
                      // SUPPORT FOOTER
                      // ═══════════════════════════════════════
                      Center(
                        child: Text.rich(
                          TextSpan(
                            text: 'Need help? ',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white54
                                  : const Color(0xFF64748B),
                            ),
                            children: [
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
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SUCCESS HEADER — Animated check icon + text
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSuccessHeader(bool isDark) {
    return Column(
      children: [
        // Animated pulsing ring + check
        Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing ring
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (context, child) => Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary
                      .withValues(alpha: 0.1 * _pulseAnim.value),
                ),
              ),
            ),
            // Solid icon circle
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1C31D4), Color(0xFF3B4FEF)],
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
                Icons.check_circle,
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
            fontFamily: 'Plus Jakarta Sans',
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
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // QR CODE SECTION — White card with QR + "Scan at entry" label
  // ═══════════════════════════════════════════════════════════════
  Widget _buildQrCodeSection(bool isDark) {
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
          // Decorative watermark
          Positioned(
            top: -20,
            right: -20,
            child: Opacity(
              opacity: 0.04,
              child: Icon(Icons.qr_code_2, size: 120,
                  color: isDark ? Colors.white : Colors.black),
            ),
          ),
          Column(
            children: [
              // QR Code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFF1F5F9),
                    width: 1,
                  ),
                ),
                child: QrImageView(
                  data: widget.qrData.isNotEmpty
                      ? widget.qrData
                      : widget.bookingId,
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
              // "Scan at entry" badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'SCAN AT ENTRY',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
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
                  fontFamily: 'Manrope',
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

  // ═══════════════════════════════════════════════════════════════
  // BOOKING DETAILS CARD — Name, address, slot badge, grid info
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDetailsCard(
    bool isDark,
    String parkingName,
    String address,
    String vehicleNumber,
    String durationStr,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Parking name + slot badge row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parkingName,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            size: 14,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(
                              fontFamily: 'Manrope',
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
              // Slot badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'SLOT',
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      widget.selectedSlot,
                      style: const TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
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

          // Details grid — 2x2
          Row(
            children: [
              Expanded(
                child: _DetailCell(
                  label: 'DATE & TIME',
                  value: DateFormat('dd MMM, hh:mm a').format(widget.start),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DetailCell(
                  label: 'DURATION',
                  value: durationStr,
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
                  value: vehicleNumber,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DetailCell(
                  label: 'STATUS',
                  value: 'Paid via ${widget.paymentMethod}',
                  isDark: isDark,
                  valueColor: AppColors.primary,
                  showDot: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // NAVIGATE BUTTON — Gradient primary button
  // ═══════════════════════════════════════════════════════════════
  Widget _buildNavigateButton() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // Navigate to parking lot on map
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell(initialIndex: 0)),
          (route) => false,
        );
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
            Icon(Icons.near_me, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Text(
              'Navigate to Parking',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
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

  // ═══════════════════════════════════════════════════════════════
  // VIEW BOOKING BUTTON — Surface/outline button
  // ═══════════════════════════════════════════════════════════════
  Widget _buildViewBookingButton(bool isDark, String parkingName) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ParkingTicketScreen(
              parking: widget.parking,
              slot: widget.selectedSlot,
              floorIndex: widget.floorIndex,
              start: widget.start,
              end: widget.end,
              vehicle: widget.vehicle,
              bookingId: widget.bookingId,
              parkingId: widget.parkingId,
              status: widget.bookingStatus,
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
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SECONDARY ACTIONS — Add to Calendar | Share Booking
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSecondaryActions(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Calendar integration coming soon'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: const Icon(Icons.calendar_month, size: 18),
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
          onPressed: () => _shareBooking(
              widget.parking['name']?.toString() ?? 'Parking'),
          icon: const Icon(Icons.share, size: 18),
          label: const Text(
            'Share Booking',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ],
    );
  }

  void _shareBooking(String parkingName) {
    HapticFeedback.lightImpact();
    final text = '🅿️ Booking Confirmed!\n'
        '📍 $parkingName\n'
        '🎫 Slot: ${widget.selectedSlot}\n'
        '🕐 ${DateFormat('dd MMM, hh:mm a').format(widget.start)}\n'
        '💰 ₹${widget.amountPaid.toStringAsFixed(0)}\n'
        'Ref: ${widget.bookingId}';
    Share.share(text, subject: 'TechXPark Booking');
  }
}

// ═══════════════════════════════════════════════════════════════
// DETAIL CELL — Label + value in the grid
// ═══════════════════════════════════════════════════════════════
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
            fontFamily: 'Plus Jakarta Sans',
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
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: valueColor ?? AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: vColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}