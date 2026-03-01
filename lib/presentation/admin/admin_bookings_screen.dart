import 'package:flutter/material.dart';

import 'admin_live_bookings_screen.dart';
import 'admin_completed_bookings_screen.dart';

class AdminBookingsScreen extends StatelessWidget {
  const AdminBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Bookings"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.black,
            tabs: [
              Tab(text: "Live"),
              Tab(text: "Completed"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AdminLiveBookingsScreen(),
            AdminCompletedBookingsScreen(),
          ],
        ),
      ),
    );
  }
}
