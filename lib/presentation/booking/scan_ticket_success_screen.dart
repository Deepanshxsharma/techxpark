import 'package:flutter/material.dart';
import 'parking_timer_screen.dart';

class ScanTicketSuccessScreen extends StatelessWidget {
  final String bookingId;
  final Map<String, dynamic> parking;
  final String slot;
  final int floorIndex;
  final DateTime start;
  final DateTime end;

  const ScanTicketSuccessScreen({
    super.key,
    required this.bookingId,
    required this.parking,
    required this.slot,
    required this.floorIndex,
    required this.start,
    required this.end,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3FF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ SUCCESS ICON
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.shade50,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Colors.blue.shade600,
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                "Scan Ticket Success!",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                "Your vehicle is parked and the timer has started.",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 30),

              // ✅ OK BUTTON → TIMER
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ParkingTimerScreen(
                          bookingId: bookingId,
                          parking: parking,
                          slot: slot,
                          floorIndex: floorIndex,
                          start: start,
                          end: end,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    "OK",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
