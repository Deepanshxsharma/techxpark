import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/review_repository.dart';

/// Shows a premium Uber/Airbnb-style rating bottom sheet.
/// Returns `true` if the review was submitted, `false` otherwise.
Future<bool> showRatingBottomSheet({
  required BuildContext context,
  required String parkingId,
  required String parkingName,
  required String bookingId,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _RatingSheet(
      parkingId: parkingId,
      parkingName: parkingName,
      bookingId: bookingId,
    ),
  );
  return result ?? false;
}

class _RatingSheet extends StatefulWidget {
  final String parkingId;
  final String parkingName;
  final String bookingId;

  const _RatingSheet({
    required this.parkingId,
    required this.parkingName,
    required this.bookingId,
  });

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet>
    with TickerProviderStateMixin {
  int _rating = 0;
  final _reviewCtrl = TextEditingController();
  final _selectedTags = <String>{};
  bool _isSubmitting = false;
  bool _isSubmitted = false;

  late AnimationController _successCtrl;
  late Animation<double> _successAnim;

  static const Color _primary = Color(0xFF4D6FFF);
  static const Color _textDark = Color(0xFF1C1C1E);
  static const Color _starGold = Color(0xFFFBBF24);

  static const _availableTags = [
    'Clean',
    'Safe',
    'Easy Access',
    'Well Lit',
    'Affordable',
    'Spacious',
  ];

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _successAnim =
        CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _reviewCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0 || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await ReviewRepository.instance.submitReview(
        parkingId: widget.parkingId,
        bookingId: widget.bookingId,
        rating: _rating,
        reviewText: _reviewCtrl.text.trim(),
        tags: _selectedTags.toList(),
      );

      HapticFeedback.mediumImpact();
      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
      });
      _successCtrl.forward();

      // Auto-dismiss after animation
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: _isSubmitted ? _buildSuccessView() : _buildFormView(),
    );
  }

  /* ── Success View ──────────────────────────────────────────────────────── */
  Widget _buildSuccessView() {
    return ScaleTransition(
      scale: _successAnim,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF00C853).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: Color(0xFF00C853), size: 48),
            ),
            const SizedBox(height: 20),
            const Text('Thank you!',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: _textDark)),
            const SizedBox(height: 6),
            Text('Your review helps other parkers.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  /* ── Form View ─────────────────────────────────────────────────────────── */
  Widget _buildFormView() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle bar ──────────────────────────────────────────────────
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // ── Title ──────────────────────────────────────────────────────
          const Text('Rate Your Experience',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _textDark,
                  letterSpacing: -0.5)),
          const SizedBox(height: 6),
          Text(widget.parkingName,
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 28),

          // ── Stars ──────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              final isSelected = starIndex <= _rating;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _rating = starIndex);
                },
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.0, end: isSelected ? 1.0 : 0.7),
                  duration: const Duration(milliseconds: 200),
                  builder: (_, scale, child) => Transform.scale(
                    scale: isSelected ? 1.15 : scale,
                    child: child,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(
                      isSelected
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 44,
                      color: isSelected ? _starGold : Colors.grey.shade300,
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_rating > 0) ...[
            const SizedBox(height: 8),
            Text(
              _ratingLabel(_rating),
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _starGold),
            ),
          ],
          const SizedBox(height: 28),

          // ── Tags ──────────────────────────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableTags.map((tag) {
              final isActive = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isActive) {
                      _selectedTags.remove(tag);
                    } else {
                      _selectedTags.add(tag);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _primary.withValues(alpha: 0.1)
                        : const Color(0xFFF5F7FB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isActive
                            ? _primary
                            : Colors.grey.shade200),
                  ),
                  child: Text(tag,
                      style: TextStyle(
                          color: isActive ? _primary : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── Review Text ───────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: TextField(
              controller: _reviewCtrl,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Tell us more (optional)...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Submit Button ─────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _rating > 0 && !_isSubmitting ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                disabledBackgroundColor: _primary.withValues(alpha: 0.3),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Review',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3)),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  String _ratingLabel(int r) {
    switch (r) {
      case 1:
        return 'Poor 😞';
      case 2:
        return 'Fair 😐';
      case 3:
        return 'Good 🙂';
      case 4:
        return 'Great 😊';
      case 5:
        return 'Excellent 🤩';
      default:
        return '';
    }
  }
}
