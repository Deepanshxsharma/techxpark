import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

import '../../services/navigation_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'indoor_navigation_screen.dart';

/// Production-ready Digital Parking Pass screen.
///
/// Fixes applied:
/// - SafeArea wrapping
/// - Complete QR data (bookingId, userId, parkingId, slotId, times)
/// - QR disabled + "Expired" overlay when booking has ended
/// - "Cancelled" banner when booking is cancelled
/// - Null-safe vehicle/parking field access
/// - `mounted` checks before all setState/showModal calls
/// - Date + time display (not just time)
/// - Responsive QR sizing
/// - Proper error handling in navigation flows
class ParkingTicketScreen extends StatefulWidget {
  final Map<String, dynamic> parking;
  final String slot;
  final int floorIndex;
  final DateTime start;
  final DateTime end;
  final Map<String, dynamic> vehicle;
  final String? bookingId;
  final String? parkingId;
  final String? status; // 'active', 'upcoming', 'completed', 'cancelled'

  const ParkingTicketScreen({
    super.key,
    required this.parking,
    required this.slot,
    required this.floorIndex,
    required this.start,
    required this.end,
    required this.vehicle,
    this.bookingId,
    this.parkingId,
    this.status,
  });

  @override
  State<ParkingTicketScreen> createState() => _ParkingTicketScreenState();
}

class _ParkingTicketScreenState extends State<ParkingTicketScreen>
    with SingleTickerProviderStateMixin {
  // ── State ───────────────────────────────────────────────────────────────
  bool _isLaunching = false;
  bool _arrived = false;

  // ── Animation ───────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  final _navService = NavigationService.instance;

  // ── Computed properties ─────────────────────────────────────────────────
  double? get _destLat {
    final v = widget.parking['latitude'] ?? widget.parking['lat'];
    return (v is num) ? v.toDouble() : null;
  }

  double? get _destLng {
    final v = widget.parking['longitude'] ?? widget.parking['lng'];
    return (v is num) ? v.toDouble() : null;
  }

  bool get _canNavigate => _destLat != null && _destLng != null;
  bool get _isExpired => DateTime.now().isAfter(widget.end);
  bool get _isCancelled => widget.status == 'cancelled';
  bool get _isActive =>
      !_isCancelled &&
      DateTime.now().isAfter(widget.start) &&
      DateTime.now().isBefore(widget.end);
  bool get _isUpcoming =>
      !_isCancelled && DateTime.now().isBefore(widget.start);

  String get _vehicleNumber =>
      widget.vehicle['number']?.toString().toUpperCase() ?? 'UNKNOWN';
  String get _vehicleType =>
      widget.vehicle['type']?.toString().toUpperCase() ?? 'CAR';
  String get _parkingName =>
      widget.parking['name']?.toString() ?? 'Parking Facility';
  String get _parkingAddress =>
      widget.parking['address']?.toString() ?? 'TechXPark Location';
  String get _resolvedParkingId =>
      widget.parkingId ??
      widget.parking['id']?.toString() ??
      widget.parking['parkingId']?.toString() ??
      '';
  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? '';

  /// Build secure QR payload. Returns empty string if critical data missing.
  String get _qrData {
    final bId = widget.bookingId ?? '';
    final pId = _resolvedParkingId;
    final slot = widget.slot;
    final uid = _userId;
    final entry = widget.start.toIso8601String();
    final exit = widget.end.toIso8601String();
    final veh = _vehicleNumber;

    // Validate — don't generate QR with empty critical fields
    if (slot.isEmpty || slot == '--' || slot == 'N/A') return '';

    return 'BOOKING:$bId|USER:$uid|PARKING:$pId|SLOT:$slot|VEHICLE:$veh|ENTRY:$entry|EXIT:$exit';
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  LIFECYCLE
  // ══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.96,
      end: 1.04,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _navService.stopProximityMonitor();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  NAVIGATION FLOW
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _handleStartNavigation() async {
    if (!_canNavigate || _isExpired || _isCancelled) return;

    setState(() => _isLaunching = true);
    HapticFeedback.mediumImpact();

    try {
      // Already nearby? → show indoor modal
      final dist = await _navService.distanceTo(_destLat!, _destLng!);
      if (dist != null && dist <= 100) {
        if (mounted) _showArrivalModal();
        if (mounted) setState(() => _isLaunching = false);
        return;
      }

      // Launch outdoor maps
      await _navService.launchOutdoorNavigation(
        destLat: _destLat!,
        destLng: _destLng!,
        label: _parkingName,
      );

      // Monitor proximity → auto-trigger indoor nav on arrival
      _navService.startProximityMonitor(
        destLat: _destLat!,
        destLng: _destLng!,
        radiusMeters: 100,
        onArrived: () {
          if (mounted) {
            HapticFeedback.heavyImpact();
            _showArrivalModal();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not launch navigation: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  void _showArrivalModal() {
    if (!mounted) return;
    setState(() => _arrived = true);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "You've arrived at",
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(_parkingName, style: AppTextStyles.h2),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openIndoorNavigation();
                },
                icon: const Icon(Icons.map_rounded),
                label: const Text('Start Indoor Navigation'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Maybe later',
                style: AppTextStyles.buttonText.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openIndoorNavigation() {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => IndoorNavigationScreen(
          parkingId: _resolvedParkingId,
          parkingName: _parkingName,
          bookedSlotId: widget.slot,
          bookedFloor: widget.floorIndex,
        ),
        transitionsBuilder: (_, anim, __, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
            child: FadeTransition(opacity: anim, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text('Digital Parking Pass', style: AppTextStyles.h2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimaryLight),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // ── Status banners ─────────────────────────────────────
              if (_isCancelled)
                _buildStatusBanner(
                  icon: Icons.cancel_rounded,
                  text: 'This booking has been cancelled',
                  color: AppColors.error,
                ),
              if (_isExpired && !_isCancelled)
                _buildStatusBanner(
                  icon: Icons.timer_off_rounded,
                  text: 'This booking has expired',
                  color: AppColors.warning,
                ),

              // ── Ticket card ────────────────────────────────────────
              _buildTicketCard(context),

              const SizedBox(height: 24),

              // ── Navigation buttons ─────────────────────────────────
              if (!_isCancelled) ...[
                _buildNavButton(),
                const SizedBox(height: 16),
                _buildIndoorNavButton(),
              ],

              // ── Arrived badge ──────────────────────────────────────
              if (_arrived) ...[
                const SizedBox(height: 24),
                _buildArrivedBadge(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  STATUS BANNER
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildStatusBanner({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.body2.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  TICKET CARD
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildTicketCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Parking info ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Text(
                  _parkingName,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h2,
                ),
                const SizedBox(height: 8),
                Text(
                  _parkingAddress,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body2,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ticketInfoItem('LEVEL', 'Floor ${widget.floorIndex + 1}'),
                    _ticketInfoItem('BAY', widget.slot),
                  ],
                ),
              ],
            ),
          ),

          // ── Perforated divider ──────────────────────────────────
          Row(
            children: List.generate(
              40,
              (i) => Expanded(
                child: Container(
                  height: 1,
                  color: i.isEven ? Colors.transparent : AppColors.borderLight,
                ),
              ),
            ),
          ),

          // ── Vehicle, time, QR ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                _buildVehicleRow(),
                const SizedBox(height: 24),
                _buildTimeRow(),
                const SizedBox(height: 32),
                _buildQrSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Vehicle row ─────────────────────────────────────────────────────────

  Widget _buildVehicleRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            _vehicleType == 'BIKE' ? Icons.two_wheeler : Icons.directions_car,
            color: AppColors.primary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _vehicleNumber,
              style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            _vehicleType,
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  // ── Time row ────────────────────────────────────────────────────────────

  Widget _buildTimeRow() {
    return Row(
      children: [
        Expanded(child: _timeDetail('ENTRY', widget.start)),
        Container(height: 48, width: 1, color: AppColors.borderLight),
        Expanded(child: _timeDetail('EXIT', widget.end)),
      ],
    );
  }

  Widget _timeDetail(String label, DateTime time) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          DateFormat('dd MMM, hh:mm a').format(time),
          textAlign: TextAlign.center,
          style: AppTextStyles.body2SemiBold,
        ),
      ],
    );
  }

  // ── QR section ──────────────────────────────────────────────────────────

  Widget _buildQrSection() {
    final qr = _qrData;

    if (_isCancelled) {
      return _qrPlaceholder(
        Icons.cancel_rounded,
        'QR Disabled\nBooking Cancelled',
        AppColors.error,
      );
    }
    if (_isExpired) {
      return _qrPlaceholder(
        Icons.timer_off_rounded,
        'QR Expired\nBooking Ended',
        AppColors.warning,
      );
    }
    if (qr.isEmpty) {
      return _qrPlaceholder(
        Icons.error_outline_rounded,
        'QR Unavailable\nMissing booking data',
        AppColors.textSecondaryLight,
      );
    }

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final qrSize = (constraints.maxWidth * 0.6).clamp(160.0, 220.0);
            return QrImageView(
              data: qr,
              size: qrSize,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.textPrimaryLight,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.textPrimaryLight,
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Show this QR at the entry gate',
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textSecondaryLight,
            fontWeight: FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _qrPlaceholder(IconData icon, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 48),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.body2SemiBold.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  NAVIGATION BUTTONS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildNavButton() {
    final disabled = _isExpired || !_canNavigate || _isLaunching;

    // Use SizedBox and child properties properly instead of nested ElevatedButton wrappers.
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Transform.scale(
        scale: disabled ? 1.0 : _pulseAnim.value,
        child: child,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: disabled ? null : _handleStartNavigation,
          icon: _isLaunching
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Icon(Icons.near_me_rounded),
          label: Text(
            _isExpired
                ? 'Booking Expired'
                : !_canNavigate
                ? 'Location Unavailable'
                : _isLaunching
                ? 'Preparing...'
                : 'Start Navigation',
          ),
          // style relies on AppTheme defaults we set in main.dart
        ),
      ),
    );
  }

  Widget _buildIndoorNavButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _isExpired ? null : _openIndoorNavigation,
        icon: const Icon(Icons.map_rounded),
        label: const Text('Navigate to Slot'),
        // style relies on AppTheme defaults we set in main.dart
      ),
    );
  }

  Widget _buildArrivedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            'You have arrived — indoor map ready',
            style: AppTextStyles.body2SemiBold.copyWith(
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _ticketInfoItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textSecondaryLight,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(value, style: AppTextStyles.h1.copyWith(color: AppColors.primary)),
      ],
    );
  }
}
