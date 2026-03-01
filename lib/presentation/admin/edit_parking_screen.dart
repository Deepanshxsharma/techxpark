// lib/presentation/admin/edit_parking_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditParkingScreen extends StatefulWidget {
  final String parkingId;
  final Map<String, dynamic> parkingData;

  const EditParkingScreen({
    super.key,
    required this.parkingId,
    required this.parkingData,
  });

  @override
  State<EditParkingScreen> createState() => _EditParkingScreenState();
}

class _EditParkingScreenState extends State<EditParkingScreen> {
  late TextEditingController nameCtrl;
  late TextEditingController priceCtrl;
  late TextEditingController floorsCtrl;
  late String status;

  bool loading = false;

  @override
  void initState() {
    super.initState();

    nameCtrl =
        TextEditingController(text: widget.parkingData["name"] ?? "");

    priceCtrl = TextEditingController(
      text: "${widget.parkingData["price_per_hour"] ?? 0}",
    );

    floorsCtrl = TextEditingController(
      text: "${widget.parkingData["total_floors"] ?? 1}",
    );

    status = widget.parkingData["status"] ?? "active";
  }

  Future<void> _saveChanges() async {
    if (nameCtrl.text.trim().isEmpty) return;

    setState(() => loading = true);

    await FirebaseFirestore.instance
        .collection("parking_locations")
        .doc(widget.parkingId)
        .update({
      "name": nameCtrl.text.trim(),
      "price_per_hour": int.tryParse(priceCtrl.text) ?? 0,
      "total_floors": int.tryParse(floorsCtrl.text) ?? 1,
      "status": status,
      "updated_at": FieldValue.serverTimestamp(),
    });

    setState(() => loading = false);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Parking updated")),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Parking"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _field("Parking Name", nameCtrl),
            _field("Price per hour (₹)", priceCtrl,
                keyboard: TextInputType.number),
            _field("Total Floors", floorsCtrl,
                keyboard: TextInputType.number),

            const SizedBox(height: 14),

            // STATUS
            DropdownButtonFormField<String>(
              value: status,
              items: const [
                DropdownMenuItem(value: "active", child: Text("Active")),
                DropdownMenuItem(value: "cancelled", child: Text("Cancelled")),
              ],
              onChanged: (v) => setState(() => status = v!),
              decoration: InputDecoration(
                labelText: "Status",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: loading ? null : _saveChanges,
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
                        "Save Changes",
                        style: TextStyle(fontSize: 17),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
