import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/app_colors.dart';
import '../parking_details/parking_details_screen.dart';

/// Saved Parkings Screen — Stitch design.
/// Premium cards with parking images, address, capacity info,
/// swipe-to-remove, and empty state illustration.
class SavedParkingsScreen extends StatelessWidget {
  const SavedParkingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (user == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF9F9FB),
        body: const Center(child: Text('Please login again')),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.bgDark : const Color(0xFFF9F9FB),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // App Bar
            SliverAppBar(
              pinned: true,
              backgroundColor:
                  (isDark ? AppColors.bgDark : const Color(0xFFF9F9FB))
                      .withValues(alpha: 0.85),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back,
                    color: isDark ? Colors.white : const Color(0xFF0029B9)),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Saved Locations',
                style: TextStyle(
                  fontFamily: 'Plus Jakarta Sans',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1C1D),
                  letterSpacing: -0.3,
                ),
              ),
            ),

            // Body
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    );
                  }

                  final userData =
                      userSnap.data!.data() as Map<String, dynamic>? ?? {};
                  final List savedIds =
                      userData['saved_parkings'] ?? [];

                  if (savedIds.isEmpty) {
                    return SliverFillRemaining(
                      child: _buildEmptyState(isDark),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(
                                top: 16, bottom: 12, left: 4),
                            child: Text(
                              '${savedIds.length} saved location${savedIds.length > 1 ? 's' : ''}',
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

                        final parkingId = savedIds[index - 1];
                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('parking_locations')
                              .doc(parkingId)
                              .snapshots(),
                          builder: (context, parkSnap) {
                            if (!parkSnap.hasData ||
                                !parkSnap.data!.exists) {
                              return const SizedBox.shrink();
                            }

                            final parking = parkSnap.data!.data()
                                as Map<String, dynamic>;

                            return _SavedParkingCard(
                              parkingId: parkingId,
                              parking: parking,
                              uid: user.uid,
                              isDark: isDark,
                            );
                          },
                        );
                      },
                      childCount: savedIds.length + 1, // +1 for header
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

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
            child: Icon(
              Icons.bookmark_border_rounded,
              size: 52,
              color: isDark
                  ? Colors.white38
                  : AppColors.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No saved locations',
            style: TextStyle(
              fontFamily: 'Plus Jakarta Sans',
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Bookmark your favorite parking spots\nfor quick access later.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              color: isDark ? Colors.white54 : const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// SAVED PARKING CARD — Dismissible with image, name, address
// ═══════════════════════════════════════════════════════════════
class _SavedParkingCard extends StatelessWidget {
  final String parkingId;
  final Map<String, dynamic> parking;
  final String uid;
  final bool isDark;

  const _SavedParkingCard({
    required this.parkingId,
    required this.parking,
    required this.uid,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final name = parking['name'] ?? 'Parking';
    final address = parking['address'] ?? '';
    final imageUrl = parking['imageUrl'] as String?;
    final totalSlots = (parking['totalSlots'] as num?)?.toInt() ?? 0;
    final pricePerHour = (parking['pricePerHour'] as num?)?.toDouble() ?? 0;

    return Dismissible(
      key: ValueKey(parkingId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.bookmark_remove,
            color: Colors.white, size: 26),
      ),
      onDismissed: (_) {
        HapticFeedback.mediumImpact();
        FirebaseFirestore.instance.collection('users').doc(uid).update({
          'saved_parkings': FieldValue.arrayRemove([parkingId]),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name removed from saved'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({
                  'saved_parkings': FieldValue.arrayUnion([parkingId]),
                });
              },
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ParkingDetailsScreen(
                data: {...parking, 'id': parkingId},
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16)),
                child: SizedBox(
                  width: 100,
                  height: 90,
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
              ),

              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontFamily: 'Plus Jakarta Sans',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 12,
                              color: isDark
                                  ? Colors.white38
                                  : const Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              address,
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _infoBadge(
                            '$totalSlots slots',
                            isDark,
                          ),
                          const SizedBox(width: 8),
                          _infoBadge(
                            '₹${pricePerHour.toStringAsFixed(0)}/hr',
                            isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Bookmark icon
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Icon(Icons.bookmark,
                    color: AppColors.primary, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: isDark
          ? AppColors.inputBgDark
          : AppColors.primary.withValues(alpha: 0.06),
      child: Center(
        child: Icon(Icons.local_parking,
            color: AppColors.primary.withValues(alpha: 0.3),
            size: 32),
      ),
    );
  }

  Widget _infoBadge(String text, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : const Color(0xFF64748B),
        ),
      ),
    );
  }
}
