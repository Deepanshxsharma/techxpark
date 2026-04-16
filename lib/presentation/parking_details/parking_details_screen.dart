import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/review_model.dart';
import '../../services/bookmark_service.dart';
import '../../services/review_repository.dart';
import '../../theme/app_colors.dart';
import '../booking/booking_screen.dart';

/// Parking Details Screen — Stitch design.
/// Full-bleed hero image, glassmorphic info overlay, review cards,
/// gradient CTA, bookmark toggle, and consistent dark mode.
class ParkingDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String collectionName;

  const ParkingDetailsScreen({
    super.key,
    required this.data,
    this.collectionName = 'parking_locations',
  });

  @override
  State<ParkingDetailsScreen> createState() => _ParkingDetailsScreenState();
}

class _ParkingDetailsScreenState extends State<ParkingDetailsScreen> {
  bool isSaved = false;
  bool loading = true;
  late final String parkingId;

  @override
  void initState() {
    super.initState();
    parkingId = widget.data['id']?.toString() ?? '';
    if (parkingId.isEmpty) {
      loading = false;
      return;
    }
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    if (parkingId.isEmpty) {
      setState(() => loading = false);
      return;
    }
    final value = await BookmarkService.isSaved(parkingId);
    if (!mounted) return;
    setState(() {
      isSaved = value;
      loading = false;
    });
  }

  Future<void> _toggleSave() async {
    if (parkingId.isEmpty) return;
    HapticFeedback.mediumImpact();
    await BookmarkService.toggleSave(parkingId);
    if (!mounted) return;
    setState(() => isSaved = !isSaved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isSaved ? 'Added to saved' : 'Removed from saved'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = widget.data;
    final name = data['name']?.toString() ?? 'Parking Spot';
    final price = _asDouble(
        data['price'] ?? data['price_per_hour'] ?? data['pricePerHour']);
    final distance = _asDouble(data['distance']);
    final imagePath =
        data['imageUrl']?.toString() ?? data['image']?.toString() ?? '';
    final lat = _asDouble(data['lat'] ?? data['latitude']);
    final lng = _asDouble(data['lng'] ?? data['longitude']);
    final address = data['address']?.toString() ?? '';
    final slots = (data['available_slots'] as num?)?.toInt() ??
        (data['totalSlots'] as num?)?.toInt();
    final description = data['description']?.toString() ??
        'Safe, secure and covered parking area with 24/7 monitoring.';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF9F9FB),
        body: Stack(
          children: [
            // ── Scrollable content ────────────────────────────
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Hero image with gradient overlay
                SliverAppBar(
                  expandedHeight: 280,
                  pinned: true,
                  backgroundColor: AppColors.primary,
                  surfaceTintColor: Colors.transparent,
                  leading: Padding(
                    padding: const EdgeInsets.all(8),
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: loading ? null : _toggleSave,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : Icon(
                                  isSaved
                                      ? Icons.bookmark
                                      : Icons.bookmark_border,
                                  color: isSaved
                                      ? const Color(0xFFFBBF24)
                                      : Colors.white,
                                  size: 22),
                        ),
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        _ParkingImage(imagePath: imagePath, isDark: isDark),
                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                        // Name + address overlay
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 16,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontFamily: 'Plus Jakarta Sans',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              if (address.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        color: Colors.white70, size: 14),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        address,
                                        style: const TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 13,
                                          color: Colors.white70,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Info badges row ──────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Row(
                      children: [
                        _StatBadge(
                          icon: Icons.currency_rupee,
                          label: '₹${price.toStringAsFixed(price % 1 == 0 ? 0 : 1)}/hr',
                          color: AppColors.success,
                          isDark: isDark,
                        ),
                        const SizedBox(width: 10),
                        if (slots != null)
                          _StatBadge(
                            icon: Icons.local_parking,
                            label: '$slots Slots',
                            color: slots > 5
                                ? const Color(0xFFF59E0B)
                                : AppColors.error,
                            isDark: isDark,
                          ),
                        if (distance > 0) ...[
                          const SizedBox(width: 10),
                          _StatBadge(
                            icon: Icons.near_me,
                            label: _formatDistance(distance),
                            color: AppColors.primary,
                            isDark: isDark,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Live rating ──────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildLiveRatingBadge(isDark),
                  ),
                ),

                // ── Description ──────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About',
                          style: TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            height: 1.6,
                            color: isDark
                                ? Colors.white70
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Action buttons ───────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Row(
                      children: [
                        // View on Map
                        Expanded(
                          child: GestureDetector(
                            onTap: lat == 0 && lng == 0
                                ? null
                                : () {
                                    final url = Uri.parse(
                                        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
                                    launchUrl(url,
                                        mode: LaunchMode.externalApplication);
                                  },
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.surfaceDark
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white12
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.map_outlined,
                                      color: AppColors.primary, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'View on Map',
                                    style: TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Book Now
                        Expanded(
                          child: GestureDetector(
                            onTap: parkingId.isEmpty
                                ? null
                                : () {
                                    HapticFeedback.mediumImpact();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => BookingScreen(
                                          parkingId: parkingId,
                                          parking:
                                              Map<String, dynamic>.from(data),
                                        ),
                                      ),
                                    );
                                  },
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.25),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.bolt,
                                      color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Book Now',
                                    style: TextStyle(
                                      fontFamily: 'Plus Jakarta Sans',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Reviews ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
                    child: _buildReviewsSection(isDark),
                  ),
                ),

                // Bottom spacer
                const SliverToBoxAdapter(
                    child: SizedBox(height: 48)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // LIVE RATING BADGE
  // ═══════════════════════════════════════════════════════════════
  Widget _buildLiveRatingBadge(bool isDark) {
    if (parkingId.isEmpty) {
      return Text(
        'No reviews yet',
        style: TextStyle(
          fontFamily: 'Manrope',
          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection(widget.collectionName)
          .doc(parkingId)
          .snapshots(),
      builder: (context, snapshot) {
        double avgRating = 0;
        int totalReviews = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final d = snapshot.data!.data() ?? {};
          avgRating = ((d['averageRating'] ??
                      d['ratingAverage'] ??
                      d['rating']) as num?)
                  ?.toDouble() ??
              0;
          totalReviews = ((d['totalReviews'] ??
                      d['ratingCount'] ??
                      d['reviews']) as num?)
                  ?.toInt() ??
              0;
        }

        if (totalReviews == 0) {
          return Text(
            'No reviews yet',
            style: TextStyle(
              fontFamily: 'Manrope',
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              fontSize: 13,
            ),
          );
        }

        return Row(
          children: [
            ...List.generate(5, (i) {
              if (i < avgRating.floor()) {
                return const Icon(Icons.star_rounded,
                    color: Color(0xFFFBBF24), size: 20);
              } else if (i < avgRating.ceil() && avgRating % 1 != 0) {
                return const Icon(Icons.star_half_rounded,
                    color: Color(0xFFFBBF24), size: 20);
              }
              return Icon(Icons.star_outline_rounded,
                  color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                  size: 20);
            }),
            const SizedBox(width: 8),
            Text(
              avgRating.toStringAsFixed(1),
              style: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '($totalReviews)',
              style: TextStyle(
                fontFamily: 'Manrope',
                color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                fontSize: 13,
              ),
            ),
          ],
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // REVIEWS SECTION
  // ═══════════════════════════════════════════════════════════════
  Widget _buildReviewsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reviews',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<ReviewModel>>(
          stream: ReviewRepository.instance.reviewsStream(parkingId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary)),
              );
            }

            final reviews = snapshot.data!;
            if (reviews.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceDark
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.rate_review_outlined,
                        size: 40,
                        color: isDark
                            ? Colors.white24
                            : const Color(0xFFE2E8F0)),
                    const SizedBox(height: 10),
                    Text(
                      'No reviews yet',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children:
                  reviews.map((r) => _buildReviewCard(r, isDark)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildReviewCard(ReviewModel review, bool isDark) {
    final date = review.createdAt != null
        ? DateFormat.yMMMd().format(review.createdAt!)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    (review.userName.isNotEmpty
                            ? review.userName[0]
                            : 'U')
                        .toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.userName,
                      style: TextStyle(
                        fontFamily: 'Plus Jakarta Sans',
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF0F172A),
                      ),
                    ),
                    if (date.isNotEmpty)
                      Text(
                        date,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 14,
                    color: i < review.rating
                        ? const Color(0xFFFBBF24)
                        : (isDark
                            ? Colors.white24
                            : const Color(0xFFE2E8F0)),
                  ),
                ),
              ),
            ],
          ),
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: review.tags
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        t,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (review.reviewText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.reviewText,
              style: TextStyle(
                fontFamily: 'Manrope',
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// STAT BADGE — Price, slots, distance
// ═══════════════════════════════════════════════════════════════
class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PARKING IMAGE — Network/Asset with fallback
// ═══════════════════════════════════════════════════════════════
class _ParkingImage extends StatelessWidget {
  final String imagePath;
  final bool isDark;

  const _ParkingImage({required this.imagePath, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveImagePath(imagePath);
    if (resolved == null) return _fallback();

    if (resolved.startsWith('http')) {
      return Image.network(
        resolved,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, e, st) => _fallback(),
      );
    }

    return Image.asset(
      resolved,
      fit: BoxFit.cover,
      errorBuilder: (_, e, st) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      color: isDark
          ? AppColors.surfaceDark
          : AppColors.primary.withValues(alpha: 0.06),
      child: Center(
        child: Icon(
          Icons.local_parking_rounded,
          size: 56,
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────
double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _formatDistance(double meters) {
  if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

String? _resolveImagePath(String raw) {
  final cleaned = raw.trim().replaceAll('"', '');
  if (cleaned.isEmpty) return null;
  if (cleaned.startsWith('http')) return cleaned;
  if (cleaned.startsWith('assets/')) return cleaned;
  final lower = cleaned.toLowerCase();
  if (lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp')) {
    return 'assets/images/$cleaned';
  }
  return cleaned;
}
