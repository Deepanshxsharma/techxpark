import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';

class PersonalInfoScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const PersonalInfoScreen({super.key, this.initialData});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  DateTime? _dob;
  String _gender = 'Other';
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _applyData(widget.initialData ?? const {});
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    _applyData(doc.data() ?? const {});
    if (mounted) setState(() => _loaded = true);
  }

  void _applyData(Map<String, dynamic> data) {
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = data['name']?.toString() ?? user?.displayName ?? '';
    _emailController.text = data['email']?.toString() ?? user?.email ?? '';
    _phoneController.text =
        data['phone']?.toString() ?? user?.phoneNumber ?? '';
    _addressController.text = data['address']?.toString() ?? '';
    _gender = data['gender']?.toString() ?? 'Other';
    final rawDob = data['dob'];
    if (rawDob is Timestamp) _dob = rawDob.toDate();
    if (rawDob is String) _dob = DateTime.tryParse(rawDob);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'dob': _dob == null ? null : Timestamp.fromDate(_dob!),
        'gender': _gender,
        'address': _addressController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await user.updateDisplayName(_nameController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Personal Info',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: !_loaded && widget.initialData == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Form(
              key: _formKey,
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  _field(
                    'Full Name',
                    _nameController,
                    Icons.person_rounded,
                    validator: _required,
                  ),
                  _field(
                    'Email',
                    _emailController,
                    Icons.email_rounded,
                    keyboardType: TextInputType.emailAddress,
                    validator: _required,
                  ),
                  _field(
                    'Phone Number',
                    _phoneController,
                    Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  _dateTile(),
                  _genderDropdown(),
                  _field(
                    'Address',
                    _addressController,
                    Icons.home_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _saving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'Save Changes',
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
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Required' : null;

  Widget _field(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _dateTile() {
    final label = _dob == null
        ? 'Date of Birth'
        : DateFormat('dd MMM yyyy').format(_dob!);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        tileColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: const Icon(Icons.cake_rounded, color: AppColors.primary),
        title: Text(label),
        trailing: const Icon(Icons.calendar_month_rounded),
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _dob ?? DateTime(2000),
            firstDate: DateTime(1940),
            lastDate: DateTime.now(),
          );
          if (picked != null) setState(() => _dob = picked);
        },
      ),
    );
  }

  Widget _genderDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        initialValue: _gender,
        decoration: InputDecoration(
          labelText: 'Gender',
          prefixIcon: const Icon(Icons.wc_rounded, color: AppColors.primary),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        items: const [
          'Male',
          'Female',
          'Other',
        ].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
        onChanged: (value) => setState(() => _gender = value ?? 'Other'),
      ),
    );
  }
}
