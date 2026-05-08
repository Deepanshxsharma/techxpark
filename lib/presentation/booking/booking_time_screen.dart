import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import 'select_vehicle_screen.dart';

class BookingTimeScreen extends StatefulWidget {
  final Map<String, dynamic> parking;
  final String parkingId;

  const BookingTimeScreen({
    super.key,
    required this.parking,
    required this.parkingId,
  });

  @override
  State<BookingTimeScreen> createState() => _BookingTimeScreenState();
}

class _BookingTimeScreenState extends State<BookingTimeScreen> {
  bool _isNow = true;
  DateTime _selectedDate = DateTime.now();
  late TimeOfDay _startTime;
  int _durationHours = 1;

  @override
  void initState() {
    super.initState();
    _startTime = _nextRoundedTime();
  }

  /// Returns the next rounded 30-min time slot in the future.
  TimeOfDay _nextRoundedTime() {
    final now = DateTime.now().add(const Duration(minutes: 5));
    final minute = now.minute < 30 ? 30 : 0;
    final hour = now.minute < 30 ? now.hour : now.hour + 1;
    return TimeOfDay(hour: hour % 24, minute: minute);
  }

  String get _parkingName =>
      (widget.parking['name'] ?? 'Parking').toString();
  String get _slotLabel =>
      (widget.parking['slotNumber'] ?? widget.parking['slot'] ?? '').toString();
  double get _pricePerHour {
    final p = widget.parking['pricePerHour'] ??
        widget.parking['price_per_hour'] ??
        widget.parking['price'] ??
        0;
    if (p is num) return p.toDouble();
    return double.tryParse(p.toString()) ?? 0;
  }

  String? get _imageUrl =>
      (widget.parking['imageUrl'] ?? widget.parking['image'] ?? '')
          .toString()
          .isNotEmpty
          ? (widget.parking['imageUrl'] ?? widget.parking['image']).toString()
          : null;

  DateTime get _startDateTime => _isNow
      ? DateTime.now()
      : DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day,
          _startTime.hour, _startTime.minute);

  DateTime get _endDateTime =>
      _startDateTime.add(Duration(hours: _durationHours));

  double get _totalPrice => _pricePerHour * _durationHours;

  Future<void> _pickStartTime() async {
    HapticFeedback.selectionClick();
    final picked =
        await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) {
      // Ensure picked time is not in the past for today
      final now = DateTime.now();
      final pickedDt = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day, picked.hour, picked.minute);
      if (_isToday(_selectedDate) && pickedDt.isBefore(now)) {
        _showError('Please select a future time.');
        return;
      }
      setState(() => _startTime = picked);
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Future<void> _pickDate() async {
    HapticFeedback.selectionClick();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _confirm() {
    final now = DateTime.now();

    // For 'Now' mode, use current time with a small buffer
    if (_isNow) {
      final start = now.add(const Duration(seconds: 30));
      final end = start.add(Duration(hours: _durationHours));
      HapticFeedback.mediumImpact();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SelectVehicleScreen(
            parkingId: widget.parkingId,
            parking: widget.parking,
            start: start,
            end: end,
          ),
        ),
      );
      return;
    }

    // For 'Schedule Later', validate the chosen time
    if (_startDateTime.isBefore(now)) {
      // Auto-correct: bump to next round time
      setState(() {
        _selectedDate = now;
        _startTime = _nextRoundedTime();
      });
      _showError('Time was in the past — updated to the next available slot.');
      return;
    }

    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SelectVehicleScreen(
          parkingId: widget.parkingId,
          parking: widget.parking,
          start: _startDateTime,
          end: _endDateTime,
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      body: Column(
        children: [
          // ─── APP BAR ───
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1A1C1D).withValues(alpha: 0.04),
                  blurRadius: 30,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: SizedBox(
              height: 56,
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Color(0xFF1565C0)),
                  ),
                  const Spacer(),
                  Text(
                    'Select Time',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1565C0),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          // ─── CONTENT ───
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBookingSummary(),
                  const SizedBox(height: 32),
                  _buildStartTimeSection(),
                  const SizedBox(height: 32),
                  _buildDurationSection(),
                  const SizedBox(height: 32),
                  _buildTimeline(),
                  const SizedBox(height: 32),
                  _buildPricing(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomBar(),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BOOKING SUMMARY
  // ═══════════════════════════════════════════════════════════════
  Widget _buildBookingSummary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1C1D).withValues(alpha: 0.04),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _parkingName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1C1D),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (_slotLabel.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBDC2FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Slot $_slotLabel',
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF000964),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('•',
                          style: GoogleFonts.manrope(
                              color: const Color(0xFF454655))),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      '₹${_pricePerHour.toStringAsFixed(0)}/hr',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF454655),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 60,
              height: 60,
              child: _imageUrl != null
                  ? Image.network(_imageUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _imagePlaceholder())
                  : _imagePlaceholder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFEDEEF0),
      child: const Icon(Icons.local_parking_rounded,
          color: AppColors.primary, size: 28),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // START TIME
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStartTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('START TIME'),
        const SizedBox(height: 12),
        // Toggle: Now / Schedule Later
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              _toggleButton('Now', _isNow, () {
                setState(() => _isNow = true);
              }),
              _toggleButton('Schedule Later', !_isNow, () {
                setState(() {
                  _isNow = false;
                  // Ensure start time is in the future when switching
                  _selectedDate = DateTime.now();
                  _startTime = _nextRoundedTime();
                });
              }),
            ],
          ),
        ),
        // Date/Time picker (visible when scheduled)
        if (!_isNow) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DATE',
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 1,
                            )),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('MMM dd, yyyy').format(_selectedDate),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1C1D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                    width: 1, height: 32, color: const Color(0xFFE2E2E4)),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickStartTime,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TIME',
                            style: GoogleFonts.manrope(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF94A3B8),
                              letterSpacing: 1,
                            )),
                        const SizedBox(height: 4),
                        Text(
                          _startTime.format(context),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A1C1D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _toggleButton(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: active
                    ? AppColors.primary
                    : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DURATION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDurationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionLabel('DURATION'),
            Text(
              '$_durationHours Hour${_durationHours > 1 ? 's' : ''}',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Quick chips
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [1, 2, 3, 4].map((h) {
              final selected = _durationHours == h;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _durationHours = h);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : const Color(0xFFF3F3F5),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: AppColors.primary
                                    .withValues(alpha: 0.25),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        '$h Hour${h > 1 ? 's' : ''}',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? Colors.white
                              : const Color(0xFF454655),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        // Custom stepper
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F3F5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stepperButton(Icons.remove_rounded, () {
                if (_durationHours > 1) {
                  setState(() => _durationHours--);
                }
              }),
              Column(
                children: [
                  Text(
                    _durationHours.toString().padLeft(2, '0'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1A1C1D),
                    ),
                  ),
                  Text(
                    'HOURS TOTAL',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              _stepperButton(Icons.add_rounded, () {
                if (_durationHours < 12) {
                  setState(() => _durationHours++);
                }
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepperButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.primary, size: 24),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // VISUAL TIMELINE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildTimeline() {
    final arrivalStr = _isNow
        ? 'Now'
        : DateFormat('hh:mm a').format(_startDateTime);
    final departureStr = DateFormat('hh:mm a').format(_endDateTime);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1C1D).withValues(alpha: 0.02),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Arrival
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ARRIVAL',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 1,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      arrivalStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1C1D),
                      ),
                    ),
                  ],
                ),
              ),
              // Progress bar
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: 0.33,
                      minHeight: 4,
                      backgroundColor: const Color(0xFFE2E2E4),
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              // Departure
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('DEPARTURE',
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF94A3B8),
                          letterSpacing: 1,
                        )),
                    const SizedBox(height: 4),
                    Text(
                      departureStr,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1C1D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(
                'You can extend your parking anytime from the app',
                style: GoogleFonts.manrope(
                  fontSize: 11,
                  color: const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // LIVE PRICING
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPricing() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFC5C5D8),
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          _priceRow('Price per hour',
              '₹${_pricePerHour.toStringAsFixed(2)}'),
          const SizedBox(height: 10),
          _priceRow('Duration',
              '$_durationHours Hour${_durationHours > 1 ? 's' : ''}'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(
                height: 1, color: const Color(0xFFE2E2E4)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Price',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              Text(
                _totalPrice > 0
                    ? '₹${_totalPrice.toStringAsFixed(2)}'
                    : 'FREE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 17,
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

  Widget _priceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: const Color(0xFF454655),
            )),
        Text(value,
            style: GoogleFonts.manrope(
              fontSize: 13,
              color: const Color(0xFF454655),
            )),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BOTTOM BAR
  // ═══════════════════════════════════════════════════════════════
  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1C1D).withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: total cost
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL COST',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      _totalPrice > 0
                          ? '₹${_totalPrice.toStringAsFixed(2)}'
                          : 'FREE',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A1C1D),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• $_durationHours Hr',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Right: confirm button
          GestureDetector(
            onTap: _confirm,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Confirm Booking',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.bolt_rounded,
                      color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF94A3B8),
        letterSpacing: 2,
      ),
    );
  }
}
