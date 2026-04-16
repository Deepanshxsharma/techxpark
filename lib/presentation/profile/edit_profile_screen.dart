import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/app_colors.dart';

/// Edit Profile Screen — Stitch design.
/// Premium avatar with camera overlay, grouped form fields,
/// gradient save button, clean read-only email display.
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
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: source, maxWidth: 512, imageQuality: 75);
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
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF9F9FB),
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back,
                color: isDark ? Colors.white : const Color(0xFF0029B9)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Edit Profile',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1A1C1D),
              letterSpacing: -0.3,
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary))
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

                        // ═══════════════════════════════════════
                        // AVATAR
                        // ═══════════════════════════════════════
                        _buildAvatar(isDark),

                        const SizedBox(height: 36),

                        // ═══════════════════════════════════════
                        // FORM FIELDS
                        // ═══════════════════════════════════════
                        _buildSectionLabel('PERSONAL INFORMATION'),
                        const SizedBox(height: 12),

                        // Email (read-only)
                        _buildReadOnlyField(
                          label: 'Email',
                          icon: Icons.email_outlined,
                          value: FirebaseAuth.instance.currentUser?.email ?? '',
                          isDark: isDark,
                        ),
                        const SizedBox(height: 16),

                        // Full Name
                        _buildEditableField(
                          label: 'Full Name',
                          icon: Icons.person_outline_rounded,
                          controller: _nameCtrl,
                          isDark: isDark,
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
                        const SizedBox(height: 16),

                        // Phone
                        _buildEditableField(
                          label: 'Phone Number',
                          icon: Icons.phone_android_rounded,
                          controller: _phoneCtrl,
                          isDark: isDark,
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

                        const SizedBox(height: 48),

                        // ═══════════════════════════════════════
                        // SAVE BUTTON
                        // ═══════════════════════════════════════
                        _buildSaveButton(isDark),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // AVATAR — Gradient border ring with camera fab
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAvatar(bool isDark) {
    return GestureDetector(
      onTap: () => _showPhotoSheet(),
      child: Stack(
        children: [
          // Gradient ring
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(3),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.bgDark : const Color(0xFFF9F9FB),
              ),
              padding: const EdgeInsets.all(3),
              child: ClipOval(
                child: _isUploadingPhoto
                    ? Container(
                        color: isDark ? AppColors.surfaceDark : Colors.white,
                        child: const Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    : _photoUrl != null && _photoUrl!.isNotEmpty
                        ? Image.network(
                            _photoUrl!,
                            fit: BoxFit.cover,
                            width: 110,
                            height: 110,
                            errorBuilder: (_, __, ___) => _buildFallbackAvatar(),
                          )
                        : _buildFallbackAvatar(),
              ),
            ),
          ),
          // Camera button
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppColors.bgDark : const Color(0xFFF9F9FB),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Center(
        child: Text(
          (_nameCtrl.text.isNotEmpty ? _nameCtrl.text[0] : 'U').toUpperCase(),
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  void _showPhotoSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt, color: AppColors.primary),
              title: const Text('Take Photo',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppColors.primary),
              title: const Text('Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SECTION LABEL
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSectionLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
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
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // READ-ONLY FIELD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildReadOnlyField({
    required String label,
    required IconData icon,
    required String value,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, isDark),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.inputBgDark : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextFormField(
            initialValue: value,
            readOnly: true,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon,
                  color: isDark ? Colors.white24 : const Color(0xFF94A3B8),
                  size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              suffixIcon: Icon(Icons.lock_outline_rounded,
                  size: 16,
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // EDITABLE FIELD
  // ═══════════════════════════════════════════════════════════════
  Widget _buildEditableField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label, isDark),
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
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon,
                  color: AppColors.primary.withValues(alpha: 0.7), size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.transparent,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              errorStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text, bool isDark) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white54 : const Color(0xFF64748B),
          ),
        ),
      );

  // ═══════════════════════════════════════════════════════════════
  // SAVE BUTTON — Gradient
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSaveButton(bool isDark) {
    return GestureDetector(
      onTap: _isSaving ? null : _saveProfile,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          gradient: _isSaving ? null : AppColors.primaryGradient,
          color: _isSaving
              ? AppColors.primary.withValues(alpha: 0.4)
              : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isSaving
              ? []
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Center(
          child: _isSaving
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text(
                  'Save Changes',
                  style: TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }
}