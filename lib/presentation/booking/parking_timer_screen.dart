import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../services/booking_repository.dart';
import 'cctv_preview_screen.dart';

class ParkingTimerScreen extends StatefulWidget {
  final String bookingId;
  final Map<String, dynamic> parking;
  final String slot;
  final int floorIndex;
  final DateTime start;
  final DateTime end;

  const ParkingTimerScreen({
    super.key,
    required this.bookingId,
    required this.parking,
    required this.slot,
    required this.floorIndex,
    required this.start,
    required this.end,
  });

  @override
  State<ParkingTimerScreen> createState() => _ParkingTimerScreenState();
}

class _ParkingTimerScreenState extends State<ParkingTimerScreen> {
  late Timer _timer;
  Duration _remaining = Duration.zero;
  late DateTime _end;
  bool _wasExtended = false;
  bool _isCancelled = false;

  final _repo = BookingRepository.instance;

  // Theme
  static const Color _techBlue = Color(0xFF2563EB);
  static const Color _alertRed = Color(0xFFEF4444);
  static const Color _success = Color(0xFF00C853);
  static const Color _darkGrey = Color(0xFF1E293B);

  @override
  void initState() {
    super.initState();
    _end = widget.end.toUtc();
    _updateRemainingTime();
    _startTimer();
  }

  void _updateRemainingTime() {
    final now = DateTime.now().toUtc();
    final diff = _end.difference(now);
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _updateRemainingTime();
      if (_remaining.inSeconds == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  EXTEND (transaction-safe via repository)                              */
  /* ═══════════════════════════════════════════════════════════════════════ */
  Future<void> _showExtendSheet() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Extend Session",
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text("Choose how long to extend your parking.",
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 24),
                  _extendOption(ctx, "15 Minutes", 15),
                  const SizedBox(height: 10),
                  _extendOption(ctx, "30 Minutes", 30),
                  const SizedBox(height: 10),
                  _extendOption(ctx, "1 Hour", 60),
                  const SizedBox(height: 10),
                  _extendOption(ctx, "2 Hours", 120),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _extendOption(BuildContext ctx, String label, int minutes) {
    final newTime = _end.add(Duration(minutes: minutes)).toLocal();
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        _extendTime(minutes);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _techBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.update, color: _techBlue, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  Text("New end: ${DateFormat('hh:mm a').format(newTime)}",
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            const Text("FREE",
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: _success,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Future<void> _extendTime(int minutes) async {
    HapticFeedback.mediumImpact();

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: _techBlue)),
    );

    try {
      final newEnd = await _repo.extendBooking(
        bookingId: widget.bookingId,
        extraMinutes: minutes,
      );

      if (mounted) Navigator.pop(context); // dismiss loading

      setState(() {
        _end = newEnd.toUtc();
        _wasExtended = true;
        _updateRemainingTime();
        if (!_timer.isActive) _startTimer();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Parking time extended ✓"),
              backgroundColor: _success),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // dismiss loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$e"), backgroundColor: _alertRed),
        );
      }
    }
  }

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  CANCEL (smart 15-min window)                                          */
  /* ═══════════════════════════════════════════════════════════════════════ */
  void _showCancelDialog() {
    final canCancel = _repo.canCancel(widget.start);

    if (!canCancel) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Cannot Cancel',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: const Text(
              'Cancellation is not allowed within 15 minutes of booking start time.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK',
                  style: TextStyle(
                      color: _techBlue, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Booking?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'Your booking will be cancelled and the parking slot will be released. Full refund will be applied.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep Booking',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _performCancel();
            },
            child: const Text('Cancel Booking',
                style: TextStyle(
                    color: _alertRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _performCancel() async {
    HapticFeedback.mediumImpact();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(color: _techBlue)),
    );

    try {
      final msg =
          await _repo.cancelBooking(bookingId: widget.bookingId);
      if (mounted) Navigator.pop(context); // dismiss loading

      setState(() => _isCancelled = true);
      _timer.cancel();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: _success),
        );
        // Go back after short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // dismiss loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$e"), backgroundColor: _alertRed),
        );
      }
    }
  }

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  BUILD                                                                 */
  /* ═══════════════════════════════════════════════════════════════════════ */
  @override
  Widget build(BuildContext context) {
    final isExpired = _remaining.inSeconds == 0 && !_isCancelled;
    final displayColor =
        _isCancelled ? Colors.grey : (isExpired ? _alertRed : _techBlue);

    final hh = _remaining.inHours.toString().padLeft(2, '0');
    final mm = (_remaining.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (_remaining.inSeconds % 60).toString().padLeft(2, '0');

    final totalDuration =
        _end.difference(widget.start.toUtc()).inSeconds;
    final progress = totalDuration > 0
        ? (1 - (_remaining.inSeconds / totalDuration)).clamp(0.0, 1.0)
        : 1.0;

    final isUpcoming = DateTime.now().isBefore(widget.start);
    final canCancelNow = _repo.canCancel(widget.start) && !_isCancelled;

    return Scaffold(
      backgroundColor: displayColor,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
            // ── App Bar ──────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Text("Parking Session",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // ── Badges ──────────────────────────────────────────
                  if (_wasExtended)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.update_rounded,
                              color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Extended',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  if (_isCancelled)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Cancelled',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),

            const Spacer(),

            // ── Timer Circle ─────────────────────────────────────────────
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: CircularProgressIndicator(
                    value: _isCancelled ? 0 : (isExpired ? 1 : progress),
                    strokeWidth: 12,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.9)),
                  ),
                ),
                Column(
                  children: [
                    Text(
                      _isCancelled ? "-- : -- : --" : "$hh:$mm:$ss",
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _isCancelled
                            ? "CANCELLED"
                            : (isExpired ? "TIME EXPIRED" : "REMAINING"),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const Spacer(),

            // ── Bottom Card ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(Icons.location_on_outlined, "Location",
                      widget.parking["name"] ?? "—"),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _infoRow(
                          Icons.local_parking_rounded,
                          "Spot",
                          "Floor ${widget.floorIndex + 1} • ${widget.slot}",
                        ),
                      ),
                      Expanded(
                        child: _infoRow(
                          Icons.access_time_rounded,
                          "End Time",
                          DateFormat('hh:mm a').format(_end.toLocal()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── CCTV Preview ────────────────────────────────────────
                  if (!_isCancelled && !isExpired) ...[
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (_, __, ___) => CCTVPreviewScreen(
                              parkingName: widget.parking['name'] ?? '',
                              slotId: widget.slot,
                              floorIndex: widget.floorIndex,
                            ),
                            transitionsBuilder: (_, anim, __, child) =>
                                FadeTransition(opacity: anim, child: child),
                            transitionDuration:
                                const Duration(milliseconds: 300),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0A1A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.06)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _techBlue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.videocam_rounded,
                                  color: _techBlue, size: 20),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Live Parking Camera',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14)),
                                  SizedBox(height: 2),
                                  Text('Tap to view live CCTV feed',
                                      style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B30).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle,
                                      color: Color(0xFFFF3B30), size: 6),
                                  SizedBox(width: 4),
                                  Text('LIVE',
                                      style: TextStyle(
                                          color: Color(0xFFFF3B30),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Action Buttons ──────────────────────────────────────
                  if (!_isCancelled) ...[
                    Row(
                      children: [
                        // Cancel — only if eligible
                        if (canCancelNow || isUpcoming)
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: OutlinedButton(
                                onPressed: _showCancelDialog,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _alertRed,
                                  side: const BorderSide(color: _alertRed),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text("Cancel",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15)),
                              ),
                            ),
                          ),
                        if (canCancelNow || isUpcoming)
                          const SizedBox(width: 12),

                        // Extend — always available when not expired
                        if (!isExpired)
                          Expanded(
                            child: SizedBox(
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _showExtendSheet,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _techBlue,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text("Extend Time",
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade400),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              Text(value,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _darkGrey)),
            ],
          ),
        ),
      ],
    );
  }
}
