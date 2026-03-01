import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

import 'slot_selection_screen.dart';

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
        .collection("users")
        .doc(user.uid)
        .collection("vehicles")
        .orderBy("created_at", descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text("Select Vehicle", style: AppTextStyles.h2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: AppColors.textPrimaryLight),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _vehicleStream(),
        builder: (_, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _noVehicleUI();
          }

          final vehicles = snapshot.data!.docs;

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: vehicles.length,
                  itemBuilder: (context, index) {
                    final doc = vehicles[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isSelected = selectedVehicleId == doc.id;
                    final isBike = data["type"] == "bike";

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            selectedVehicleId = doc.id;
                            selectedVehicle = data;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary.withOpacity(0.05) : AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.borderLight,
                              width: 2,
                            ),
                            boxShadow: isSelected ? [] : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 4)
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : AppColors.bgLight,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  isBike ? Icons.two_wheeler : Icons.directions_car,
                                  color: isSelected ? Colors.white : AppColors.primary,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data["number"]?.toString().toUpperCase() ?? "UNKNOWN",
                                      style: AppTextStyles.h2,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${data['brand'] ?? ''} ${data['model'] ?? ''}".trim(),
                                      style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                isSelected ? Icons.check_circle : Icons.radio_button_off,
                                color: isSelected ? AppColors.primary : AppColors.borderDark,
                                size: 28,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _buildBottomAction(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 24,
              offset: const Offset(0, -8)),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: selectedVehicle == null
              ? null
              : () {
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
                          "id": selectedVehicleId,
                        },
                      ),
                    ),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.borderLight,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            shadowColor: AppColors.primary.withOpacity(0.4),
          ),
          child: Text(
            "Proceed to Slot Selection",
            style: AppTextStyles.buttonText.copyWith(
              color: selectedVehicle == null ? AppColors.textSecondaryLight : Colors.white
            ),
          ),
        ),
      ),
    );
  }

  Widget _noVehicleUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight, 
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.borderLight),
              ),
              child: const Icon(Icons.car_rental, size: 80, color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 24),
            Text("Your Garage is Empty", style: AppTextStyles.h1),
            const SizedBox(height: 12),
            Text(
              "You need to add a vehicle to your profile before you can book a parking spot.",
              textAlign: TextAlign.center,
              style: AppTextStyles.body1,
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 2),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text("Return to Booking", style: AppTextStyles.buttonText.copyWith(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}