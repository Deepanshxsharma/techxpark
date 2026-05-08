import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';

class MyVehiclesScreen extends StatelessWidget {
  const MyVehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in again.')));
    }

    final vehicles = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('vehicles')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FC),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Vehicles',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Vehicle'),
        onPressed: () => _showVehicleSheet(context, user.uid),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: vehicles,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.directions_car_filled_rounded,
                    size: 56,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No vehicles yet',
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add a vehicle to make booking faster.',
                    style: GoogleFonts.poppins(color: const Color(0xFF757686)),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return _VehicleCard(uid: user.uid, id: doc.id, data: data);
            },
          );
        },
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final String uid;
  final String id;
  final Map<String, dynamic> data;

  const _VehicleCard({required this.uid, required this.id, required this.data});

  @override
  Widget build(BuildContext context) {
    final type =
        data['vehicleType']?.toString() ?? data['type']?.toString() ?? 'Car';
    final number =
        data['vehicleNumber']?.toString() ??
        data['number']?.toString() ??
        'UNKNOWN';
    final make = data['make']?.toString() ?? '';
    final model = data['model']?.toString() ?? '';
    final isDefault = data['isDefault'] == true;

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _delete(uid, id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(_iconFor(type), color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          number,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'Default',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF2E7D32),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      make,
                      model,
                      type,
                    ].where((v) => v.trim().isNotEmpty).join(' · '),
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF757686),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFBA1A1A),
              ),
              onPressed: () async {
                final ok = await _confirmDelete(context);
                if (ok == true) await _delete(uid, id);
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    final t = type.toLowerCase();
    if (t.contains('bike')) return Icons.two_wheeler_rounded;
    if (t.contains('auto')) return Icons.electric_rickshaw_rounded;
    return Icons.directions_car_rounded;
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete vehicle?'),
      content: const Text('This vehicle will be removed from your profile.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ),
  );

  Future<void> _delete(String uid, String id) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('vehicles')
        .doc(id)
        .delete();
  }
}

void _showVehicleSheet(BuildContext context, String uid) {
  final formKey = GlobalKey<FormState>();
  final number = TextEditingController();
  final make = TextEditingController();
  final model = TextEditingController();
  String type = 'Car';
  String color = 'White';
  bool isDefault = false;
  bool saving = false;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (context, setSheetState) {
        Future<void> save() async {
          if (!formKey.currentState!.validate()) return;
          setSheetState(() => saving = true);
          final vehicles = FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('vehicles');
          final doc = vehicles.doc();
          final batch = FirebaseFirestore.instance.batch();
          if (isDefault) {
            final existing = await vehicles.get();
            for (final v in existing.docs) {
              batch.set(v.reference, {
                'isDefault': false,
              }, SetOptions(merge: true));
            }
          }
          batch.set(doc, {
            'vehicleNumber': number.text.trim().toUpperCase(),
            'vehicleType': type,
            'make': make.text.trim(),
            'model': model.text.trim(),
            'color': color,
            'isDefault': isDefault,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          await batch.commit();
          if (ctx.mounted) Navigator.pop(ctx);
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Vehicle',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: number,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Vehicle number required'
                          : null,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [UpperCaseTextFormatter()],
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Number',
                        prefixIcon: Icon(Icons.pin_rounded),
                      ),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(
                        labelText: 'Vehicle Type',
                        prefixIcon: Icon(Icons.category_rounded),
                      ),
                      items: const ['Car', 'Bike', 'Auto']
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => setSheetState(() => type = v ?? 'Car'),
                    ),
                    TextField(
                      controller: make,
                      decoration: const InputDecoration(
                        labelText: 'Make',
                        prefixIcon: Icon(Icons.business_rounded),
                      ),
                    ),
                    TextField(
                      controller: model,
                      decoration: const InputDecoration(
                        labelText: 'Model',
                        prefixIcon: Icon(Icons.car_rental_rounded),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      children: ['White', 'Black', 'Silver', 'Blue', 'Red'].map(
                        (c) {
                          return ChoiceChip(
                            label: Text(c),
                            selected: color == c,
                            onSelected: (_) => setSheetState(() => color = c),
                          );
                        },
                      ).toList(),
                    ),
                    SwitchListTile.adaptive(
                      value: isDefault,
                      title: const Text('Set as Default'),
                      onChanged: (v) => setSheetState(() => isDefault = v),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: saving ? null : save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                        ),
                        child: Text(
                          'Save Vehicle',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
