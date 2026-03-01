// lib/presentation/admin/add_parking_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddParkingScreen extends StatefulWidget {
  const AddParkingScreen({super.key});

  @override
  State<AddParkingScreen> createState() => _AddParkingScreenState();
}

class _AddParkingScreenState extends State<AddParkingScreen> {
  final nameCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final floorsCtrl = TextEditingController(text: "1");
  final latCtrl = TextEditingController();
  final lngCtrl = TextEditingController();

  bool loading = false;

  // ---------------------------------------------------------------------------
  Future<void> _addParking() async {
    if (nameCtrl.text.isEmpty ||
        priceCtrl.text.isEmpty ||
        latCtrl.text.isEmpty ||
        lngCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill all required fields")),
      );
      return;
    }

    setState(() => loading = true);

    await FirebaseFirestore.instance.collection("parking_locations").add({
      // BASIC INFO
      "name": nameCtrl.text.trim(),
      "address": addressCtrl.text.trim(),

      // PRICING
      "price_per_hour": int.parse(priceCtrl.text),

      // STRUCTURE
      "total_floors": int.parse(floorsCtrl.text),

      // LOCATION
      "latitude": double.parse(latCtrl.text),
      "longitude": double.parse(lngCtrl.text),

      // STATUS
      "status": "active",

      // META
      "created_at": FieldValue.serverTimestamp(),
      "updated_at": FieldValue.serverTimestamp(),
    });

    setState(() => loading = false);

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Parking added successfully")),
    );
  }

  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Parking"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: const Color(0xffF4F6FF),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _field("Parking Name *", nameCtrl),
            _field("Address", addressCtrl),

            _field(
              "Price per hour *",
              priceCtrl,
              keyboard: TextInputType.number,
            ),

            _field(
              "Total Floors",
              floorsCtrl,
              keyboard: TextInputType.number,
            ),

            const SizedBox(height: 10),

            // ---------------- LOCATION ----------------
            _field(
              "Latitude *",
              latCtrl,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
            _field(
              "Longitude *",
              lngCtrl,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),

            const SizedBox(height: 8),

            // HELP TEXT
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info, color: Colors.blue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Tip: Open Google Maps → Long press on location → Copy latitude & longitude",
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ---------------- ADD BUTTON ----------------
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _addParking,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Add Parking",
                        style: TextStyle(fontSize: 17),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
