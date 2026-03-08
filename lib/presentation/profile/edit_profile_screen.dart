import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _photoUrl;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  static const Color _techBlue = Color(0xFF2563EB);
  static const Color _dark = Color(0xFF0F172A);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _success = Color(0xFF10B981);
  static const Color _danger = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();

    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);

    _loadUserData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (doc.exists) {
      final data = doc.data()!;
      _nameCtrl.text = data['name'] ?? '';
      _phoneCtrl.text = data['phone'] ?? '';
      _photoUrl = data['photoUrl'];
    }
    if (mounted) {
      setState(() => _isLoading = false);
      _animCtrl.forward();
    }
  }

  /* ── Save Profile ──────────────────────────────────────────────────────── */
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      });

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Profile updated successfully'),
            ]),
            backgroundColor: _success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /* ── Pick & Upload Photo ───────────────────────────────────────────────── */
  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 512, imageQuality: 75);
    if (picked == null) return;

    setState(() => _isUploadingPhoto = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos/${user!.uid}.jpg');
      await ref.putFile(File(picked.path));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'photoUrl': url});
      setState(() => _photoUrl = url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo updated!'),
            backgroundColor: _success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: _danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  /* ═══════════════════════════════════════════════════════════════════════ */
  /*  BUILD                                                                 */
  /* ═══════════════════════════════════════════════════════════════════════ */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: const Icon(Icons.arrow_back_rounded,
                color: _dark, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Profile',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                color: _dark,
                letterSpacing: -0.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      _buildAvatar(),
                      const SizedBox(height: 32),

                      // --- Email (read-only) ---
                      _buildField(
                        label: 'Email',
                        icon: Icons.email_outlined,
                        value: FirebaseAuth.instance.currentUser?.email ?? '',
                        readOnly: true,
                      ),
                      const SizedBox(height: 20),

                      // --- Full Name ---
                      _buildEditableField(
                        label: 'Full Name',
                        icon: Icons.person_outline_rounded,
                        controller: _nameCtrl,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Name cannot be empty';
                          }
                          if (val.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // --- Phone ---
                      _buildEditableField(
                        label: 'Phone Number',
                        icon: Icons.phone_android_rounded,
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        validator: (val) {
                          if (val != null && val.isNotEmpty) {
                            final cleaned =
                                val.replaceAll(RegExp(r'[^0-9+]'), '');
                            if (cleaned.length < 10) {
                              return 'Enter a valid phone number';
                            }
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 40),

                      // --- Save Button ---
                      _buildSaveButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  /* ── Avatar ────────────────────────────────────────────────────────────── */
  Widget _buildAvatar() {
    return GestureDetector(
      onTap: _pickPhoto,
      child: Stack(
        children: [
          Hero(
            tag: 'profile-avatar',
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _techBlue.withOpacity(0.2), width: 3),
                boxShadow: [
                  BoxShadow(
                      color: _techBlue.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: ClipOval(
                child: _isUploadingPhoto
                    ? Container(
                        color: _surface,
                        child: const Center(
                            child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))))
                    : _photoUrl != null && _photoUrl!.isNotEmpty
                        ? Image.network(
                            _photoUrl!,
                            fit: BoxFit.cover,
                            width: 110,
                            height: 110,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: _techBlue.withOpacity(0.1),
                              child: Center(
                                child: Text(
                                  (_nameCtrl.text.isNotEmpty ? _nameCtrl.text[0] : 'U').toUpperCase(),
                                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: _techBlue),
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: _techBlue.withOpacity(0.1),
                            child: Center(
                              child: Text(
                                (_nameCtrl.text.isNotEmpty
                                        ? _nameCtrl.text[0]
                                        : 'U')
                                    .toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w900,
                                    color: _techBlue),
                              ),
                            ),
                          ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _techBlue,
                shape: BoxShape.circle,
                border: Border.all(color: _surface, width: 3),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  /* ── Read-only Field ───────────────────────────────────────────────────── */
  Widget _buildField(
      {required String label,
      required IconData icon,
      required String value,
      bool readOnly = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        Container(
          decoration: BoxDecoration(
            color: readOnly ? const Color(0xFFF1F5F9) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: readOnly
                ? []
                : [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
          ),
          child: TextFormField(
            initialValue: value,
            readOnly: true,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: readOnly ? const Color(0xFF94A3B8) : _dark),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              suffixIcon: readOnly
                  ? const Icon(Icons.lock_outline_rounded,
                      size: 16, color: Color(0xFFCBD5E1))
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  /* ── Editable Field ────────────────────────────────────────────────────── */
  Widget _buildEditableField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            decoration: InputDecoration(
              prefixIcon:
                  Icon(icon, color: _techBlue.withOpacity(0.7), size: 20),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              errorStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600)),
      );

  /* ── Save Button ───────────────────────────────────────────────────────── */
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _techBlue,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        onPressed: _isSaving ? null : _saveProfile,
        child: _isSaving
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Text('Save Changes',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3)),
      ),
    );
  }
}