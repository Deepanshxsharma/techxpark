import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';

/// My Vehicle / Garage Screen — Stitch design.
/// Premium vehicle cards with type icons, gradient default badge,
/// swipe-to-delete, animated add form with vehicle type selector.
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
  String _selectedType = 'Car';

  bool _loading = true;
  bool _saving = false;
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
    super.dispose();
  }

  Future<void> _initData() async {
    if (widget.isAddFlow) {
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
    if (user == null) return;
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final userDoc = await _fire.collection('users').doc(user.uid).get();
      _defaultVehicleId = userDoc.data()?['selected_vehicle_id'];
      final snap = await _fire
          .collection('users')
          .doc(user.uid)
          .collection('vehicles')
          .orderBy('createdAt', descending: true)
          .get();
      if (mounted) {
        setState(() {
          _vehicles = snap.docs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadVehicleForEdit() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      final doc = await _fire
          .collection('users')
          .doc(user.uid)
          .collection('vehicles')
          .doc(widget.editVehicleId)
          .get();
      final data = doc.data();
      if (data == null) return;
      setState(() {
        _vehicleNumberCtrl.text = data['vehicleNumber'] ?? '';
        _selectedType = data['vehicleType'] ?? 'Car';
      });
    } catch (e) {
      debugPrint('Load vehicle error: $e');
    }
  }

  Future<void> _saveVehicle() async {
    HapticFeedback.mediumImpact();
    if (!_formKey.currentState!.validate()) return;
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    final ref =
        _fire.collection('users').doc(user.uid).collection('vehicles');

    try {
      if (widget.editVehicleId != null) {
        await ref.doc(widget.editVehicleId).update({
          'vehicleNumber':
              _vehicleNumberCtrl.text.trim().toUpperCase(),
          'vehicleType': _selectedType,
        });
      } else {
        final doc = await ref.add({
          'vehicleNumber':
              _vehicleNumberCtrl.text.trim().toUpperCase(),
          'vehicleType': _selectedType,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (_vehicles.isEmpty) {
          await _fire
              .collection('users')
              .doc(user.uid)
              .set({'selected_vehicle_id': doc.id},
                  SetOptions(merge: true));
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save vehicle'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteVehicle(String id) async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await _fire
          .collection('users')
          .doc(user.uid)
          .collection('vehicles')
          .doc(id)
          .delete();
      if (_defaultVehicleId == id) {
        await _fire
            .collection('users')
            .doc(user.uid)
            .set({'selected_vehicle_id': null},
                SetOptions(merge: true));
        setState(() => _defaultVehicleId = null);
      }
      _loadVehicles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _setDefault(String id) async {
    HapticFeedback.selectionClick();
    final user = _auth.currentUser;
    if (user == null) return;
    await _fire
        .collection('users')
        .doc(user.uid)
        .set({'selected_vehicle_id': id}, SetOptions(merge: true));
    setState(() => _defaultVehicleId = id);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isForm = widget.isAddFlow || widget.editVehicleId != null;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.bgDark : const Color(0xFFF9F9FB),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor:
                  (isDark ? AppColors.bgDark : const Color(0xFFF9F9FB))
                      .withValues(alpha: 0.85),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back,
                    color:
                        isDark ? Colors.white : const Color(0xFF0029B9)),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                isForm
                    ? (widget.editVehicleId != null
                        ? 'Edit Vehicle'
                        : 'Add Vehicle')
                    : 'My Garage',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color:
                      isDark ? Colors.white : const Color(0xFF1A1C1D),
                  letterSpacing: -0.3,
                ),
              ),
              actions: [
                if (!isForm && !_loading && _vehicles.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 18),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const MyVehicleScreen(isAddFlow: true)),
                      ),
                    ),
                  ),
              ],
            ),
            if (_loading)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary)),
              )
            else if (isForm)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                      [_buildVehicleForm(isDark)]),
                ),
              )
            else if (_vehicles.isEmpty)
              SliverFillRemaining(
                  child: _buildEmptyState(isDark))
            else
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(
                              top: 8, bottom: 16, left: 4),
                          child: Text(
                            '${_vehicles.length} vehicle${_vehicles.length > 1 ? 's' : ''}',
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.white54
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        );
                      }
                      final doc = _vehicles[index - 1];
                      final data =
                          doc.data() as Map<String, dynamic>;
                      final isDefault = doc.id == _defaultVehicleId;
                      return _buildVehicleCard(
                          doc.id, data, isDefault, isDark);
                    },
                    childCount: _vehicles.length + 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // EMPTY STATE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceDark
                  : AppColors.primary.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.garage_rounded,
                size: 56,
                color: isDark
                    ? Colors.white38
                    : AppColors.primary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 20),
          Text(
            'No vehicles added yet',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add your car or bike to easily\nbook parking spots.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              color:
                  isDark ? Colors.white54 : const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      const MyVehicleScreen(isAddFlow: true)),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Add Vehicle',
                    style: TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // VEHICLE FORM — Add / Edit
  // ═══════════════════════════════════════════════════════════════
  Widget _buildVehicleForm(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // Vehicle type selector
          _sectionLabel('VEHICLE TYPE'),
          const SizedBox(height: 12),
          Row(
            children: [
              _typeChip('Car', Icons.directions_car, isDark),
              const SizedBox(width: 12),
              _typeChip('Bike', Icons.two_wheeler, isDark),
              const SizedBox(width: 12),
              _typeChip('SUV', Icons.local_shipping_outlined, isDark),
            ],
          ),

          const SizedBox(height: 32),

          // License plate
          _sectionLabel('LICENSE PLATE'),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextFormField(
              controller: _vehicleNumberCtrl,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w700,
                fontSize: 16,
                letterSpacing: 1.5,
                color:
                    isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Vehicle number is required';
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: 'e.g. DL8CAF1234',
                hintStyle: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white24
                      : const Color(0xFF94A3B8),
                  letterSpacing: 1,
                ),
                prefixIcon: Icon(
                  Icons.confirmation_number_outlined,
                  color: AppColors.primary.withValues(alpha: 0.7),
                  size: 20,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.transparent,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 18),
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Save button
          GestureDetector(
            onTap: _saving ? null : _saveVehicle,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient:
                    _saving ? null : AppColors.primaryGradient,
                color: _saving
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : null,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _saving
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.primary
                              .withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Center(
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        widget.editVehicleId != null
                            ? 'Update Vehicle'
                            : 'Save Vehicle',
                        style: const TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _typeChip(String label, IconData icon, bool isDark) {
    final isSelected = _selectedType == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedType = label);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.primaryGradient : null,
            color: isSelected
                ? null
                : (isDark
                    ? AppColors.surfaceDark
                    : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: isSelected
                ? null
                : Border.all(
                    color: isDark
                        ? Colors.white12
                        : const Color(0xFFE2E8F0),
                  ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary
                          .withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                          ? Colors.white54
                          : const Color(0xFF64748B)),
                  size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                          ? Colors.white70
                          : const Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF94A3B8),
            letterSpacing: 1.5,
          ),
        ),
      );

  // ═══════════════════════════════════════════════════════════════
  // VEHICLE CARD — With type icon, default badge, actions
  // ═══════════════════════════════════════════════════════════════
  Widget _buildVehicleCard(
      String docId, Map<String, dynamic> data, bool isDefault, bool isDark) {
    final vehicleType = data['vehicleType'] ?? 'Car';
    final isBike =
        vehicleType.toString().toLowerCase() == 'bike';
    final number = data['vehicleNumber']?.toString() ?? 'N/A';

    return Dismissible(
      key: ValueKey(docId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline,
            color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Text('Delete Vehicle',
                style: TextStyle(fontWeight: FontWeight.w800)),
            content: Text('Remove $number from your garage?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete',
                      style: TextStyle(color: AppColors.error))),
            ],
          ),
        );
      },
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        _deleteVehicle(docId);
      },
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  MyVehicleScreen(editVehicleId: docId)),
        ),
        onLongPress: () => _setDefault(docId),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isDefault
                ? Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: isDefault
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Vehicle icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: isDefault
                      ? AppColors.primaryGradient
                      : null,
                  color: isDefault
                      ? null
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : AppColors.primary
                              .withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isBike
                      ? Icons.two_wheeler
                      : Icons.directions_car,
                  color: isDefault
                      ? Colors.white
                      : AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      number,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          vehicleType,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white54
                                : const Color(0xFF64748B),
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius:
                                  BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'DEFAULT',
                              style: TextStyle(
                                fontFamily: 'Plus Jakarta Sans',
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Chevron
              Icon(Icons.chevron_right,
                  color: isDark
                      ? Colors.white24
                      : const Color(0xFFC5C5D8),
                  size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
