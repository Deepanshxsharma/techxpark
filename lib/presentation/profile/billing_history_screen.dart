import 'package:flutter/material.dart';

class BillingHistoryScreen extends StatelessWidget {
  const BillingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Billing History")),
      body: const Center(child: Text("Invoices & payments")),
    );
  }
}
