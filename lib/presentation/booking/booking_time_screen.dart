import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

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
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  double _durationHours = 2;

  DateTime get _startDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _startTime.hour,
        _startTime.minute,
      );

  DateTime get _endDateTime =>
      _startDateTime.add(Duration(minutes: (_durationHours * 60).toInt()));

  Future<void> _pickStartTime() async {
    HapticFeedback.selectionClick();
    final picked =
        await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) setState(() => _startTime = picked);
  }

  void _continue() {
    final now = DateTime.now();

    // ── Validate: start must be in the future ─────────────────────────
    if (_startDateTime.isBefore(now)) {
      _showError('Start time must be in the future.');
      return;
    }

    // ── Validate: booking must be at least 30 min ─────────────────────
    if (_durationHours < 0.5) {
      _showError('Minimum booking duration is 30 minutes.');
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
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text('Select Time', style: AppTextStyles.h2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: const BackButton(color: AppColors.textPrimaryLight),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHorizontalCalendar(),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle('Start Time'),
                  _buildTimeCard(),
                  const SizedBox(height: 32),
                  _sectionTitle('Parking Duration'),
                  _buildDurationSlider(),
                  const SizedBox(height: 32),
                  _buildSummaryCard(),
                ],
              ),
            ),
          ),
          _buildBottomAction(),
        ],
      ),
    );
  }

  /* ── Horizontal Calendar ───────────────────────────────────────────────── */
  Widget _buildHorizontalCalendar() {
    return Container(
      height: 100,
      color: AppColors.surfaceLight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = date.day == _selectedDate.day &&
              date.month == _selectedDate.month;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedDate = date);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 64,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.borderLight),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date),
                    style: AppTextStyles.captionBold.copyWith(
                      color: isSelected ? Colors.white70 : AppColors.textSecondaryLight,
                    )
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: AppTextStyles.h1.copyWith(
                      color: isSelected ? Colors.white : AppColors.textPrimaryLight,
                      fontSize: 20,
                    )
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /* ── Time Card ─────────────────────────────────────────────────────────── */
  Widget _buildTimeCard() {
    return GestureDetector(
      onTap: _pickStartTime,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.access_time_rounded,
                  color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Arriving At', style: AppTextStyles.caption),
                const SizedBox(height: 4),
                Text(
                  _startTime.format(context),
                  style: AppTextStyles.h1.copyWith(fontSize: 20),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.edit_rounded, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }

  /* ── Duration Slider ───────────────────────────────────────────────────── */
  Widget _buildDurationSlider() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Stay Length', style: AppTextStyles.body1),
              Text(
                '${_durationHours.toInt()} Hours',
                style: AppTextStyles.body1.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.primary.withOpacity(0.1),
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withOpacity(0.1),
            ),
            child: Slider(
              value: _durationHours,
              min: 1,
              max: 12,
              divisions: 11,
              onChanged: (v) => setState(() => _durationHours = v),
            ),
          ),
        ],
      ),
    );
  }

  /* ── Summary Card ──────────────────────────────────────────────────────── */
  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Leaving At',
                  style: AppTextStyles.captionBold.copyWith(
                    color: Colors.white60,
                  )),
              const SizedBox(height: 6),
              Text(
                DateFormat('hh:mm a').format(_endDateTime),
                style: AppTextStyles.h2.copyWith(color: Colors.white),
              ),
            ],
          ),
          Container(height: 40, width: 1, color: AppColors.borderDark),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Parking Fee',
                  style: AppTextStyles.captionBold.copyWith(
                    color: Colors.white60,
                  )),
              const SizedBox(height: 6),
              Text(
                'FREE',
                style: AppTextStyles.h2.copyWith(color: AppColors.success),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /* ── Bottom Action ─────────────────────────────────────────────────────── */
  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, -8)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _continue,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)
              ),
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.4),
            ),
            child: const Text('Next Step', style: AppTextStyles.buttonText),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(title, style: AppTextStyles.h2),
    );
  }
}
