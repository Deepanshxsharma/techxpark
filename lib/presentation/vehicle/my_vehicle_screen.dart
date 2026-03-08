import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';

class MyVehicleScreen extends StatefulWidget {
  final bool isAddFlow;
  final String? editVehicleId;

  const MyVehicleScreen({
    super.key,
    this.isAddFlow = false,
    this.editVehicleId,
  });

  @override
  State<MyVehicleScreen> createState() => _MyVehicleScreenState();
}

class _MyVehicleScreenState extends State<MyVehicleScreen> {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  
  final _vehicleNumberCtrl = TextEditingController();
  final _vehicleTypeCtrl = TextEditingController();

  bool _loading = true;
  List<QueryDocumentSnapshot> _vehicles = [];
  String? _defaultVehicleId;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _vehicleNumberCtrl.dispose();
    _vehicleTypeCtrl.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    if (widget.isAddFlow) {
      _vehicleTypeCtrl.text = "Car";
      setState(() => _loading = false);
      return;
    }
    await _loadVehicles();
    if (widget.editVehicleId != null) {
      await _loadVehicleForEdit();
    }
  }

  Future<void> _loadVehicles() async {
    final user = _auth.currentUser;
    if (user == null) {
      // Not authenticated, close screen or return
      return;
    }
    
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final userDoc = await _fire.collection("users").doc(user.uid).get();
      _defaultVehicleId = userDoc.data()?["selected_vehicle_id"];
      
      final snap = await _fire
          .collection("users")
          .doc(user.uid)
          .collection("vehicles")
          .orderBy("createdAt", descending: true)
          .get();

      if (mounted) {
        setState(() {
          _vehicles = snap.docs;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Vehicles load error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _vehicles = [];
        });
      }
    }
  }

  Future<void> _loadVehicleForEdit() async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      final doc = await _fire
          .collection("users")
          .doc(user.uid)
          .collection("vehicles")
          .doc(widget.editVehicleId)
          .get();
          
      final data = doc.data();
      if (data == null) return;
      
      setState(() {
        _vehicleNumberCtrl.text = data["vehicleNumber"] ?? "";
        _vehicleTypeCtrl.text = data["vehicleType"] ?? "Car";
      });
    } catch (e) {
      debugPrint("Error loading vehicle: $e");
    }
  }

  Future<void> _saveVehicle() async {
    HapticFeedback.mediumImpact();
    if (!_formKey.currentState!.validate()) return;
    
    if (_vehicleNumberCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vehicle Number is required"),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;
    
    final ref = _fire.collection("users").doc(user.uid).collection("vehicles");

    try {
      if (widget.editVehicleId != null) {
        await ref.doc(widget.editVehicleId).update({
          "vehicleNumber": _vehicleNumberCtrl.text.trim().toUpperCase(),
          "vehicleType": _vehicleTypeCtrl.text.trim(),
        });
      } else {
        final doc = await ref.add({
          "vehicleNumber": _vehicleNumberCtrl.text.trim().toUpperCase(),
          "vehicleType": _vehicleTypeCtrl.text.trim(),
          "createdAt": FieldValue.serverTimestamp(),
        });

        if (_vehicles.isEmpty) {
          await _fire.collection("users").doc(user.uid).set({
            "selected_vehicle_id": doc.id,
          }, SetOptions(merge: true));
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Vehicle save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save vehicle. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteVehicle(String id) async {
    final user = _auth.currentUser;
    if (user == null) return;
    
    try {
      await _fire
          .collection("users")
          .doc(user.uid)
          .collection("vehicles")
          .doc(id)
          .delete();
          
      if (_defaultVehicleId == id) {
        await _fire.collection("users").doc(user.uid).set({
          "selected_vehicle_id": null,
        }, SetOptions(merge: true));
        setState(() => _defaultVehicleId = null);
      }
      _loadVehicles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error deleting vehicle: $e"), backgroundColor: AppColors.error)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isForm = widget.isAddFlow || widget.editVehicleId != null;
    
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: Text(isForm ? (widget.editVehicleId != null ? "Edit Vehicle" : "Add Vehicle") : "My Garage", style: AppTextStyles.h2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: const BackButton(color: AppColors.textPrimaryLight),
      ),
      body: _loading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : isForm ? _buildVehicleForm() : (_vehicles.isEmpty ? _buildEmptyDashboard() : _buildVehicleList()),
      floatingActionButton: (!isForm && !_loading && _vehicles.isNotEmpty)
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyVehicleScreen(isAddFlow: true)),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildEmptyDashboard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
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
              child: const Icon(Icons.garage_rounded, size: 80, color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 24),
            Text("No vehicles added yet", style: AppTextStyles.h1),
            const SizedBox(height: 12),
            Text(
              "Add your car or bike to easily book parking spots on the go.",
              textAlign: TextAlign.center,
              style: AppTextStyles.body1,
            ),
            const SizedBox(height: 32),
            AppButton(
              label: "Add Vehicle",
              icon: Icons.add,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyVehicleScreen(isAddFlow: true)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("License Plate Number", style: AppTextStyles.body1SemiBold),
            const SizedBox(height: 8),
            TextFormField(
              controller: _vehicleNumberCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: "e.g. DL8CAF1234",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text("Vehicle Type", style: AppTextStyles.body1SemiBold),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    color: _vehicleTypeCtrl.text == "Car" ? AppColors.primary.withOpacity(0.1) : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    onTap: () => setState(() => _vehicleTypeCtrl.text = "Car"),
                    child: Center(
                      child: Text(
                        "Car", 
                        style: TextStyle(
                          color: _vehicleTypeCtrl.text == "Car" ? AppColors.primary : AppColors.textSecondaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: AppCard(
                    color: _vehicleTypeCtrl.text == "Bike" ? AppColors.primary.withOpacity(0.1) : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    onTap: () => setState(() => _vehicleTypeCtrl.text = "Bike"),
                    child: Center(
                      child: Text(
                        "Bike", 
                        style: TextStyle(
                          color: _vehicleTypeCtrl.text == "Bike" ? AppColors.primary : AppColors.textSecondaryLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            AppButton(
              label: widget.editVehicleId != null ? "Update Vehicle" : "Save Vehicle",
              onPressed: _saveVehicle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleList() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      itemCount: _vehicles.length,
      itemBuilder: (context, index) {
        final doc = _vehicles[index];
        final data = doc.data() as Map<String, dynamic>;
        final isDefault = doc.id == _defaultVehicleId;
        final vehicleType = data["vehicleType"] ?? "Car";
        final isBike = vehicleType.toString().toLowerCase() == "bike";

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: AppCard(
            padding: EdgeInsets.zero,
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => MyVehicleScreen(editVehicleId: doc.id)),
                      );
                    },
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(AppSpacing.cardRadius)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isBike ? Icons.two_wheeler : Icons.directions_car,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data["vehicleNumber"]?.toString() ?? "N/A",
                                  style: AppTextStyles.h2,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      vehicleType,
                                      style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    if (isDefault) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Text(
                                          "Default",
                                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ]
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Delete Button
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Delete Vehicle"),
                        content: Text("Remove ${data['vehicleNumber']}?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _deleteVehicle(doc.id);
                            },
                            child: const Text("Delete", style: TextStyle(color: AppColors.error)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
