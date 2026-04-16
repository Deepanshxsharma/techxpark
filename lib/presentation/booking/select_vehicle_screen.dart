import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import 'slot_selection_screen.dart';

/// Select Vehicle Screen — Stitch design.
/// Premium vehicle cards with gradient selection, dark mode, and
/// gradient proceed button.
class SelectVehicleScreen extends StatefulWidget {
  final Map<String, dynamic> parking;
  final String parkingId;
  final DateTime start;
  final DateTime end;

  const SelectVehicleScreen({
    super.key,
    required this.parking,
    required this.parkingId,
    required this.start,
    required this.end,
  });

  @override
  State<SelectVehicleScreen> createState() => _SelectVehicleScreenState();
}

class _SelectVehicleScreenState extends State<SelectVehicleScreen> {
  String? selectedVehicleId;
  Map<String, dynamic>? selectedVehicle;

  Stream<QuerySnapshot> _vehicleStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('vehicles')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF9F9FB),
        appBar: AppBar(
          title: Text(
            'Select Vehicle',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _vehicleStream(),
          builder: (_, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primary));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return _noVehicleUI(isDark);
            }

            final vehicles = snapshot.data!.docs;

            return Column(
              children: [
                // Subtitle
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose a vehicle for this booking',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: vehicles.length,
                    itemBuilder: (context, index) {
                      final doc = vehicles[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final isSelected = selectedVehicleId == doc.id;
                      final vehicleType =
                          data['vehicleType']?.toString() ?? 'Car';
                      final isBike =
                          vehicleType.toLowerCase() == 'bike';
                      final number =
                          data['vehicleNumber']?.toString().toUpperCase() ??
                              'UNKNOWN';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              selectedVehicleId = doc.id;
                              selectedVehicle = data;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? (isSelected
                                      ? AppColors.primary
                                          .withValues(alpha: 0.12)
                                      : AppColors.surfaceDark)
                                  : (isSelected
                                      ? AppColors.primary
                                          .withValues(alpha: 0.05)
                                      : Colors.white),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : (isDark
                                        ? Colors.white10
                                        : const Color(0xFFE2E8F0)),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.15),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              children: [
                                // Icon
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    gradient: isSelected
                                        ? AppColors.primaryGradient
                                        : null,
                                    color: isSelected
                                        ? null
                                        : (isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.06)
                                            : const Color(0xFFF1F5F9)),
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      isBike
                                          ? Icons.two_wheeler
                                          : Icons.directions_car,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.primary,
                                      size: 26,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        number,
                                        style: TextStyle(
                                          fontFamily:
                                              'Plus Jakarta Sans',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(
                                                  0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        vehicleType,
                                        style: TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? Colors.white54
                                              : const Color(
                                                  0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Selection indicator
                                AnimatedContainer(
                                  duration: const Duration(
                                      milliseconds: 250),
                                  width: 26,
                                  height: 26,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: isSelected
                                        ? AppColors.primaryGradient
                                        : null,
                                    border: isSelected
                                        ? null
                                        : Border.all(
                                            color: isDark
                                                ? Colors.white24
                                                : const Color(
                                                    0xFFE2E8F0),
                                            width: 2),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 16,
                                        )
                                      : const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                _buildBottomAction(isDark),
              ],
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BOTTOM ACTION — Gradient proceed button
  // ═══════════════════════════════════════════════════════════════
  Widget _buildBottomAction(bool isDark) {
    final enabled = selectedVehicle != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 24,
              offset: const Offset(0, -8)),
        ],
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SlotSelectionScreen(
                        parkingId: widget.parkingId,
                        parking: widget.parking,
                        start: widget.start,
                        end: widget.end,
                        vehicle: {
                          ...selectedVehicle!,
                          'id': selectedVehicleId,
                        },
                      ),
                    ),
                  );
                }
              : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled ? 1.0 : 0.4,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: AppColors.primary
                              .withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: const Center(
                child: Text(
                  'Proceed to Slot Selection',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // EMPTY STATE — No vehicles
  // ═══════════════════════════════════════════════════════════════
  Widget _noVehicleUI(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark
                    : AppColors.primary.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.car_rental,
                  size: 64,
                  color: isDark
                      ? Colors.white24
                      : AppColors.primary.withValues(alpha: 0.4)),
            ),
            const SizedBox(height: 24),
            Text(
              'Your Garage is Empty',
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add a vehicle to your profile before booking a parking spot.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color:
                    isDark ? Colors.white54 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.primary),
                ),
                child: const Text(
                  'Return to Booking',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
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