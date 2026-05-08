import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';

class LoyaltyScreen extends StatelessWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in again.')));
    }

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
          'Loyalty Points',
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnap) {
          final points =
              (userSnap.data?.data()?['loyaltyPoints'] as num?)?.toInt() ?? 0;
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              _balanceCard(points),
              const SizedBox(height: 20),
              _infoSection('How to earn points', const [
                (
                  'Book parking',
                  '10 points / booking',
                  Icons.local_parking_rounded,
                ),
                ('Write a review', '25 points', Icons.star_rounded),
                ('Refer a friend', '100 points', Icons.group_rounded),
                ('Birthday bonus', '50 points', Icons.cake_rounded),
              ]),
              _redeemSection(),
              _history(user.uid),
            ],
          );
        },
      ),
    );
  }

  Widget _balanceCard(int points) {
    final progress = (points / 500).clamp(0, 1).toDouble();
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0029B9), Color(0xFF1E3A8A)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$points Points',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '= ₹${(points / 10).floor()} value',
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 18),
          Text(
            'Next reward at 500 points',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoSection(String title, List<(String, String, IconData)> rows) {
    return _card(
      title,
      rows.map((row) {
        return ListTile(
          leading: Icon(row.$3, color: AppColors.primary),
          title: Text(
            row.$1,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(row.$2),
        );
      }).toList(),
    );
  }

  Widget _redeemSection() {
    return _card('How to redeem', [
      _redeemRow('500 points', '₹50 off next booking'),
      _redeemRow('1000 points', '₹120 off'),
      _redeemRow('2000 points', '1 hour free parking'),
    ]);
  }

  Widget _redeemRow(String points, String value) {
    return ListTile(
      leading: const Icon(Icons.redeem_rounded, color: AppColors.primary),
      title: Text(
        points,
        style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(value),
    );
  }

  Widget _history(String uid) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('pointsHistory')
          .snapshots(),
      builder: (context, snap) {
        final docs = [
          ...(snap.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[]),
        ]..sort((a, b) => _date(b.data()).compareTo(_date(a.data())));
        return _card(
          'Points history',
          docs.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'No points activity yet',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF757686),
                      ),
                    ),
                  ),
                ]
              : docs.map((doc) {
                  final data = doc.data();
                  final points = (data['points'] as num?)?.toInt() ?? 0;
                  final type =
                      data['type']?.toString() ??
                      (points >= 0 ? 'Earned' : 'Redeemed');
                  return ListTile(
                    leading: Icon(
                      points >= 0
                          ? Icons.add_circle_rounded
                          : Icons.remove_circle_rounded,
                      color: points >= 0 ? AppColors.success : AppColors.error,
                    ),
                    title: Text(
                      data['title']?.toString() ?? type,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      DateFormat('dd MMM yyyy').format(_date(data)),
                    ),
                    trailing: Text(
                      '${points >= 0 ? '+' : ''}$points',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w900,
                        color: points >= 0
                            ? AppColors.success
                            : AppColors.error,
                      ),
                    ),
                  );
                }).toList(),
        );
      },
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF757686),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  DateTime _date(Map<String, dynamic> data) {
    final raw = data['createdAt'] ?? data['date'];
    if (raw is Timestamp) return raw.toDate();
    return DateTime.now();
  }
}
