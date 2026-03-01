import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/review_model.dart';
import '../../services/bookmark_service.dart';
import '../../services/review_repository.dart';

class ParkingDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> data;

  const ParkingDetailsScreen({super.key, required this.data});

  @override
  State<ParkingDetailsScreen> createState() => _ParkingDetailsScreenState();
}

class _ParkingDetailsScreenState extends State<ParkingDetailsScreen> {
  bool isSaved = false;
  bool loading = true;
  late final String parkingId;

  static const Color _primary = Color(0xFF4D6FFF);
  static const Color _textDark = Color(0xFF1C1C1E);
  static const Color _starGold = Color(0xFFFBBF24);

  @override
  void initState() {
    super.initState();
    if (!widget.data.containsKey("id")) {
      throw Exception("ParkingDetailsScreen requires 'id' in data map");
    }
    parkingId = widget.data["id"];
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final value = await BookmarkService.isSaved(parkingId);
    if (!mounted) return;
    setState(() {
      isSaved = value;
      loading = false;
    });
  }

  Future<void> _toggleSave() async {
    await BookmarkService.toggleSave(parkingId);
    if (!mounted) return;
    setState(() => isSaved = !isSaved);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(isSaved ? "Saved" : "Removed"),
          duration: const Duration(seconds: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final name = data['name'] ?? "Parking Spot";
    final price = (data['price'] ?? 0).toDouble();
    final distance = (data['distance'] ?? 0).toDouble();
    final image = data['image'] ?? "park1.png";
    final lat = (data['lat'] ?? 0).toDouble();
    final lng = (data['lng'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xffF6F2FF),
      appBar: AppBar(
        title: Text(name, style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)),
                )
              : IconButton(
                  icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      color: Colors.white),
                  onPressed: _toggleSave,
                ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // ── Image ─────────────────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset("assets/images/$image",
                  width: double.infinity, height: 220, fit: BoxFit.cover),
            ),
            const SizedBox(height: 20),

            // ── Details Card ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                      "₹$price / hr • ${distance.toStringAsFixed(0)} m"),

                  // ── Live Rating Badge ───────────────────────────────
                  const SizedBox(height: 16),
                  _buildLiveRatingBadge(),

                  const SizedBox(height: 20),
                  const Text("Description",
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text(
                      "Safe, secure and covered parking area with monitoring."),

                  const SizedBox(height: 24),

                  // ── Action Buttons ──────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            final url = Uri.parse(
                                "https://www.google.com/maps/search/?api=1&query=$lat,$lng");
                            launchUrl(url,
                                mode: LaunchMode.externalApplication);
                          },
                          child: const Text("View on Map"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          child: const Text("Book Now"),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ── Reviews Section ─────────────────────────────────
                  _buildReviewsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ── Live Rating Badge ─────────────────────────────────────────────────── */
  Widget _buildLiveRatingBadge() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('parking_locations')
          .doc(parkingId)
          .snapshots(),
      builder: (context, snapshot) {
        double avgRating = 0;
        int totalReviews = 0;

        if (snapshot.hasData && snapshot.data!.exists) {
          final d = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          avgRating = (d['averageRating'] as num?)?.toDouble() ?? 0;
          totalReviews = (d['totalReviews'] as num?)?.toInt() ?? 0;
        }

        if (totalReviews == 0) {
          return Text('No reviews yet',
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: FontWeight.w500));
        }

        return Row(
          children: [
            ...List.generate(5, (i) {
              if (i < avgRating.floor()) {
                return const Icon(Icons.star_rounded,
                    color: _starGold, size: 20);
              } else if (i < avgRating.ceil() && avgRating % 1 != 0) {
                return const Icon(Icons.star_half_rounded,
                    color: _starGold, size: 20);
              }
              return Icon(Icons.star_outline_rounded,
                  color: Colors.grey.shade300, size: 20);
            }),
            const SizedBox(width: 8),
            Text(avgRating.toStringAsFixed(1),
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: _textDark)),
            const SizedBox(width: 4),
            Text('($totalReviews)',
                style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ],
        );
      },
    );
  }

  /* ── Reviews Section ───────────────────────────────────────────────────── */
  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reviews',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _textDark)),
        const SizedBox(height: 16),
        StreamBuilder<List<ReviewModel>>(
          stream: ReviewRepository.instance.reviewsStream(parkingId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child:
                          CircularProgressIndicator(color: _primary)));
            }

            final reviews = snapshot.data!;
            if (reviews.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FB),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.rate_review_outlined,
                        size: 40, color: Colors.grey.shade300),
                    const SizedBox(height: 10),
                    Text('No reviews yet',
                        style: TextStyle(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }

            return Column(
              children: reviews.map((r) => _buildReviewCard(r)).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildReviewCard(ReviewModel review) {
    final date = review.createdAt != null
        ? DateFormat.yMMMd().format(review.createdAt!)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _primary.withOpacity(0.1),
                child: Text(
                  (review.userName.isNotEmpty
                          ? review.userName[0]
                          : 'U')
                      .toUpperCase(),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _primary,
                      fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.userName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _textDark)),
                    Text(date,
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11)),
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
                              ? _starGold
                              : Colors.grey.shade300,
                        )),
              ),
            ],
          ),
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: review.tags
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(t,
                            style: const TextStyle(
                                color: _primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ))
                  .toList(),
            ),
          ],
          if (review.reviewText.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(review.reviewText,
                style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 14,
                    height: 1.4)),
          ],
        ],
      ),
    );
  }
}
