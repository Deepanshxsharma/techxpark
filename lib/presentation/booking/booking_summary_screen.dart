import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

import '../map/osrm_navigation_screen.dart';
import 'parking_ticket_screen.dart';
import 'indoor_navigation_screen.dart';

class BookingSummaryScreen extends StatelessWidget {
  final Map<String, dynamic> parking;
  final String selectedSlot;
  final int floorIndex;
  final String docId;
  final DateTime start;
  final DateTime end;
  final Map<String, dynamic> vehicle;

  const BookingSummaryScreen({
    super.key,
    required this.parking,
    required this.selectedSlot,
    required this.floorIndex,
    required this.docId,
    required this.start,
    required this.end,
    required this.vehicle,
  });

  int _calculateHours() {
    final diff = end.difference(start);
    if (diff.inMinutes <= 0) return 0;
    return (diff.inMinutes / 60).ceil();
  }

  @override
  Widget build(BuildContext context) {
    final hours = _calculateHours();

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
               Navigator.of(context).popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.close_rounded, color: AppColors.textSecondaryLight, size: 28),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            // -----------------------------------------------------------------
            // 1. SUCCESS ANIMATION HEADER
            // -----------------------------------------------------------------
            _buildSuccessHeader(),

            const SizedBox(height: 32),

            // -----------------------------------------------------------------
            // 2. THE PREMIUM TICKET CARD
            // -----------------------------------------------------------------
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Top Half: Location & Slot
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(
                          parking["name"] ?? "Parking Location",
                          textAlign: TextAlign.center,
                          style: AppTextStyles.h2,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          parking["address"] ?? "TechXPark Smart Zone",
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body2,
                        ),
                        const SizedBox(height: 24),

                        // 🌟 HERO STAT: THE SLOT
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                          decoration: BoxDecoration(
                            color: AppColors.bgLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "YOUR BAY",
                                style: AppTextStyles.captionBold.copyWith(
                                  color: AppColors.textSecondaryLight,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                selectedSlot,
                                style: AppTextStyles.h1.copyWith(
                                  fontSize: 40,
                                  color: AppColors.primary,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Level ${floorIndex + 1}",
                                style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  _buildDashedDivider(),

                  // Bottom Half: Details
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        // Left: Vehicle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label("VEHICLE"),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    vehicle["type"] == "bike" ? Icons.two_wheeler : Icons.directions_car_filled,
                                    size: 20,
                                    color: AppColors.textPrimaryLight,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    vehicle["number"] ?? "Unknown",
                                    style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                        
                        // Right: Time
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _label("DURATION"),
                              const SizedBox(height: 6),
                              Text(
                                "$hours Hours",
                                style: AppTextStyles.body1.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${DateFormat('h:mm a').format(start)} - ${DateFormat('h:mm a').format(end)}",
                                style: AppTextStyles.captionBold.copyWith(color: AppColors.textSecondaryLight),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // -----------------------------------------------------------------
            // 3. ACTION BUTTONS
            // -----------------------------------------------------------------
            
            // Primary: Navigate
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OsrmNavigationScreen(
                        destinationLat: parking["latitude"],
                        destinationLng: parking["longitude"],
                        bookingId: docId,
                        parking: parking,
                        slot: selectedSlot,
                        floorIndex: floorIndex,
                        start: start,
                        end: end,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.near_me_rounded, color: Colors.white),
                label: const Text("Start Navigation"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Indoor Navigation
            OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => IndoorNavigationScreen(
                      parkingId: docId,
                      parkingName: parking['name'] ?? 'Parking',
                      bookedSlotId: selectedSlot,
                      bookedFloor: floorIndex,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.map_rounded),
              label: const Text('Navigate to Slot'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
            const SizedBox(height: 16),

            // Secondary: View Ticket
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ParkingTicketScreen(
                      parking: parking,
                      slot: selectedSlot,
                      floorIndex: floorIndex,
                      start: start,
                      end: end,
                      vehicle: vehicle,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_rounded, color: AppColors.textPrimaryLight),
              label: Text("View Ticket Details", style: AppTextStyles.buttonText.copyWith(color: AppColors.textPrimaryLight)),
              style: TextButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.borderLight)
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI HELPERS
  // ---------------------------------------------------------------------------

  Widget _buildSuccessHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: AppColors.success.withOpacity(0.2), blurRadius: 24, spreadRadius: 4)
            ]
          ),
          child: const Icon(Icons.check_rounded, color: AppColors.success, size: 48),
        ),
        const SizedBox(height: 20),
        Text(
          "Confirmed!",
          style: AppTextStyles.h1,
        ),
        const SizedBox(height: 8),
        Text(
          "Your parking space has been reserved.",
          style: AppTextStyles.body1,
        ),
      ],
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: AppTextStyles.captionBold.copyWith(
        color: AppColors.textSecondaryLight,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildDashedDivider() {
    return SizedBox(
      height: 1,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boxWidth = constraints.constrainWidth();
          const dashWidth = 6.0;
          const dashHeight = 1.0;
          final dashCount = (boxWidth / (2 * dashWidth)).floor();
          return Flex(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            direction: Axis.horizontal,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: dashHeight,
                child: const DecoratedBox(
                  decoration: BoxDecoration(color: AppColors.borderLight),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}