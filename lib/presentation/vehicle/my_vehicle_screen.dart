import 'dart:ui'; // Ensure ImageFilter is available
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

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

class _MyVehicleScreenState extends State<MyVehicleScreen>
    with TickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _fire = FirebaseFirestore.instance;

  // Using GlobalKey for form validation if needed later
  final _formKey = GlobalKey<FormState>();
  final _numberCtrl = TextEditingController();
  final _typeCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();

  bool loading = true;
  List<QueryDocumentSnapshot> vehicles = [];
  String? defaultVehicleId;

  final _bgOffWhite = const Color(0xFFF6F8FF); // Unified bgLight

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _typeCtrl.dispose();
    _brandCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    if (widget.isAddFlow) {
      _typeCtrl.text = "Car";
      setState(() => loading = false);
      return;
    }
    await _loadVehicles();
    if (widget.editVehicleId != null) {
      await _loadVehicleForEdit();
    }
  }

  Future<void> _loadVehicles() async {
    final user = _auth.currentUser;
    if (user == null) return;
    // Ensure mounted before setting state after async
    if (!mounted)
      return;
    else
      setState(() => loading = true);

    final userDoc = await _fire.collection("users").doc(user.uid).get();
    defaultVehicleId = userDoc.data()?["selected_vehicle_id"];
    final snap = await _fire
        .collection("users")
        .doc(user.uid)
        .collection("vehicles")
        .orderBy("created_at", descending: true)
        .get();

    if (mounted) {
      setState(() {
        vehicles = snap.docs;
        loading = false;
      });
    }
  }

  Future<void> _loadVehicleForEdit() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final doc = await _fire
        .collection("users")
        .doc(user.uid)
        .collection("vehicles")
        .doc(widget.editVehicleId)
        .get();
    final data = doc.data();
    if (data == null) return;
    setState(() {
      _numberCtrl.text = data["number"] ?? "";
      _typeCtrl.text = data["type"] ?? "Car";
      _brandCtrl.text = data["brand"] ?? "";
      _colorCtrl.text = data["color"] ?? "";
    });
  }

  Future<void> _saveVehicle() async {
    HapticFeedback.mediumImpact();
    if (_numberCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("License plate is required"),
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
          "type": _typeCtrl.text.trim(),
          "brand": _brandCtrl.text.trim(),
          "color": _colorCtrl.text.trim(),
        });
      } else {
        final doc = await ref.add({
          "number": _numberCtrl.text.trim().toUpperCase(),
          "type": _typeCtrl.text.trim(),
          "brand": _brandCtrl.text.trim(),
          "color": _colorCtrl.text.trim(),
          "created_at": FieldValue.serverTimestamp(),
        });

        if (vehicles.isEmpty) {
          await _fire.collection("users").doc(user.uid).set({
            "selected_vehicle_id": doc.id,
          }, SetOptions(merge: true));
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      // Production app should show user-facing error
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving vehicle: $e")));
    }
  }

  Future<void> _setDefaultVehicle(String id) async {
    HapticFeedback.mediumImpact();
    final user = _auth.currentUser;
    if (user == null) return;
    await _fire.collection("users").doc(user.uid).set({
      "selected_vehicle_id": id,
    }, SetOptions(merge: true));
    setState(() => defaultVehicleId = id);
  }

  Future<void> _deleteVehicle(String id) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _fire
        .collection("users")
        .doc(user.uid)
        .collection("vehicles")
        .doc(id)
        .delete();
    if (defaultVehicleId == id) {
      await _fire.collection("users").doc(user.uid).set({
        "selected_vehicle_id": null,
      }, SetOptions(merge: true));
      setState(() => defaultVehicleId = null);
    }
    _loadVehicles();
  }

  @override
  Widget build(BuildContext context) {
    bool isForm = widget.isAddFlow || widget.editVehicleId != null;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: _buildAppBar(isForm),
      body: Stack(
        children: [
          Positioned.fill(
            // IMPROVEMENT: Smooth transitions between states
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : _buildBody(),
            ),
          ),
        ],
      ),
      floatingActionButton: (!isForm && !loading && vehicles.isNotEmpty)
          ? _buildFloatingAddButton()
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(bool isForm) {
    return AppBar(
      backgroundColor: AppColors.bgLight,
      elevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent, // Disable material 3 tiny tint
      title: Column(
        children: [
          Text(
            isForm
                ? (widget.editVehicleId != null ? "Edit Vehicle" : "Add Vehicle")
                : "My Garage",
            style: AppTextStyles.h2.copyWith(color: AppColors.textPrimaryLight),
          ),
          if (!isForm)
            Text(
              "Manage your registered vehicles",
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondaryLight,
                fontSize: 13,
              ),
            ),
        ],
      ),
      leading: isForm
          ? IconButton(
              icon: _AnimatedScaleButton(
                onPressed: () => Navigator.pop(context),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: const Icon(
                    Icons.chevron_left_rounded,
                    color: AppColors.textPrimaryLight,
                    size: 32,
                  ),
                ),
              ),
              onPressed: () {}, // Handled by gesture detector
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (widget.isAddFlow || widget.editVehicleId != null)
      return _buildVehicleForm();
    if (vehicles.isEmpty) return _buildEmptyDashboard();
    return _buildVehicleList();
  }

  // --- 1. EMPTY STATE ---
  Widget _buildEmptyDashboard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.garage_rounded,
              size: 80,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            "No vehicles added yet",
            style: AppTextStyles.h2.copyWith(color: AppColors.textPrimaryLight),
          ),
          const SizedBox(height: 12),
          Text(
            "Add your car or bike to easily book parking spots on the go.",
            textAlign: TextAlign.center,
            style: AppTextStyles.body1.copyWith(color: AppColors.textSecondaryLight),
          ),
          const SizedBox(height: 48),
          _actionButton(
            "Add Vehicle",
            Icons.add_rounded,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const MyVehicleScreen(isAddFlow: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. THE FORM (IMPROVED) ---
  Widget _buildVehicleForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
        children: [
          _inputLabel("License Plate Number"),
          // IMPROVEMENT: Interactive Input Field
          _buildAnimatedInputField(
            _numberCtrl,
            Icons.pin_outlined,
            "ABC 1234",
            caps: true,
          ),

          const SizedBox(height: 24),
          _inputLabel("Vehicle Type"),
          _buildModernTypeSelector(),

          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _inputLabel("Brand"),
                    _buildAnimatedInputField(
                      _brandCtrl,
                      Icons.branding_watermark_outlined,
                      "e.g. Toyota",
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _inputLabel("Color"),
                    _buildAnimatedInputField(
                      _colorCtrl,
                      Icons.palette_outlined,
                      "e.g. Black",
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),
          _actionButton(
            "Save Vehicle",
            Icons.check_circle_outline_rounded,
            _saveVehicle,
          ),
        ],
      ),
    );
  }

  Widget _buildModernTypeSelector() {
    final types = ["Car", "Bike", "SUV", "EV"];
    return Row(
      children: types.map((type) {
        bool isSelected = _typeCtrl.text == type;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _typeCtrl.text = type);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.grey.shade200,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: Center(
                child: Text(
                  type,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // --- 3. THE LIST (FINTECH TIER) ---
  Widget _buildVehicleList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      itemCount: vehicles.length,
      itemBuilder: (_, i) {
        final v = vehicles[i].data() as Map<String, dynamic>;
        final id = vehicles[i].id;
        final isDefault = id == defaultVehicleId;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 600 + (i * 100)), // Staggered delay
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Transform.translate(
              offset: Offset(0, 50 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Dismissible(
              key: ValueKey(id),
              direction: DismissDirection.endToStart,
              background: _buildDismissBackground(),
              confirmDismiss: (direction) async {
                return await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Delete Vehicle"),
                    content: Text(
                      "Are you sure you want to remove ${v["number"]}?",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text(
                          "Delete",
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (_) => _deleteVehicle(id),
              child: _buildVehicleKeyCard(id, v, isDefault),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVehicleKeyCard(
    String id,
    Map<String, dynamic> v,
    bool isDefault,
  ) {
    return _AnimatedScaleButton(
      onPressed: () {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MyVehicleScreen(editVehicleId: id)),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDefault ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
            if (isDefault)
              BoxShadow(
                color: AppColors.primary.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildVehicleAvatar(v["type"]),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${v["brand"] ?? "Unknown"} ${v["type"] ?? "Car"}",
                          style: AppTextStyles.body1.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              "Default",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Realistic License Plate Styling
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9), // Light Grey
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        (v["number"] ?? "N/A").toUpperCase(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF334155),
                          letterSpacing: 2.0, // Stretched like a plate
                          fontFamily: 'monospace', // Or clear sans-serif
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildPrimaryToggle(id, isDefault),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleAvatar(String? type) {
    IconData icon;
    switch (type) {
      case 'Bike':
        icon = Icons.two_wheeler_rounded;
        break;
      case 'SUV':
        icon = Icons.directions_car_filled_rounded;
        break;
      case 'EV':
        icon = Icons.electric_car_rounded;
        break;
      default:
        icon = Icons.directions_car_rounded;
    }

    return Container(
      height: 54,
      width: 54,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        shape: BoxShape.circle,
      ),
      child: Center(child: Icon(icon, color: AppColors.primary, size: 26)),
    );
  }

  Widget _buildPrimaryToggle(String id, bool isDefault) {
    return GestureDetector(
      onTap: () => _setDefaultVehicle(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDefault
              ? AppColors.primary.withOpacity(0.1)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          isDefault ? Icons.check_circle_rounded : Icons.more_vert_rounded,
          color: isDefault ? AppColors.primary : Colors.grey.shade400,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildFloatingAddButton() {
    return _AnimatedScaleButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const MyVehicleScreen(isAddFlow: true),
        ),
      ),
      child: Container(
        height: 64,
        width: 64,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.add_rounded, size: 32, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildDismissBackground() {
    return Container(
      alignment: Alignment.centerRight,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.only(right: 30),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.delete_outline_rounded,
        color: Colors.white,
        size: 32,
      ),
    );
  }

  Widget _inputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 13,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  // IMPROVEMENT: New Animated Input Field using TextFormField
  Widget _buildAnimatedInputField(
    TextEditingController ctrl,
    IconData icon,
    String hint, {
    bool caps = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: ctrl,
        textCapitalization: caps
            ? TextCapitalization.characters
            : TextCapitalization.words,
        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimaryLight),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontWeight: FontWeight.normal,
          ),
          prefixIcon: Icon(icon, color: Colors.grey.shade500),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String text, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              text,
              style: AppTextStyles.body1.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// -------------------------------------------------------------------------
// �� PREMIUM FINTECH MICRO-INTERACTIONS
// -------------------------------------------------------------------------

/// A button that smoothly scales down when pressed (Apple style)
class _AnimatedScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onPressed;

  const _AnimatedScaleButton({required this.child, required this.onPressed});

  @override
  State<_AnimatedScaleButton> createState() => _AnimatedScaleButtonState();
}

class _AnimatedScaleButtonState extends State<_AnimatedScaleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
