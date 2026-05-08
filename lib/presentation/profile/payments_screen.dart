import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _TransactionsScaffold(
      title: 'Payments & Wallet',
      receiptsOnly: false,
    );
  }
}

class ReceiptsScreen extends StatelessWidget {
  const ReceiptsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _TransactionsScaffold(
      title: 'Receipts & Invoices',
      receiptsOnly: true,
    );
  }
}

class _TransactionsScaffold extends StatelessWidget {
  final String title;
  final bool receiptsOnly;

  const _TransactionsScaffold({
    required this.title,
    required this.receiptsOnly,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please sign in again.')));
    }

    final stream = FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'completed')
        .snapshots();

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
          title,
          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final docs = [...snap.data!.docs]
            ..sort((a, b) => _dateOf(b.data()).compareTo(_dateOf(a.data())));
          final now = DateTime.now();
          final monthDocs = docs.where((doc) {
            final date = _dateOf(doc.data());
            return date.year == now.year && date.month == now.month;
          }).toList();
          final monthlySpent = monthDocs.fold<double>(
            0,
            (total, doc) => total + _amountOf(doc.data()),
          );

          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              if (!receiptsOnly)
                Row(
                  children: [
                    Expanded(
                      child: _summaryCard(
                        'Spent this month',
                        '₹${monthlySpent.toStringAsFixed(0)}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _summaryCard(
                        'Bookings this month',
                        '${monthDocs.length}',
                      ),
                    ),
                  ],
                ),
              if (!receiptsOnly) const SizedBox(height: 22),
              Text(
                receiptsOnly ? 'COMPLETED RECEIPTS' : 'TRANSACTIONS',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF757686),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 10),
              if (docs.isEmpty)
                _emptyState(
                  receiptsOnly ? 'No receipts yet' : 'No transactions yet',
                )
              else
                ...docs.map(
                  (doc) => _transactionRow(context, doc.data(), receiptsOnly),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF757686),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _transactionRow(
    BuildContext context,
    Map<String, dynamic> data,
    bool receipt,
  ) {
    final name =
        data['parkingName']?.toString() ??
        data['lotName']?.toString() ??
        'Parking Location';
    final date = _dateOf(data);
    final duration =
        (data['durationMinutes'] as num?)?.toInt() ??
        ((data['hours'] as num?)?.toInt() ?? 1) * 60;
    final amount = _amountOf(data);
    final paid =
        (data['paymentStatus']?.toString().toLowerCase() ?? '').contains(
          'success',
        ) ||
        amount > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              receipt ? Icons.receipt_long_rounded : Icons.payments_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  '${DateFormat('dd MMM yyyy').format(date)} · ${(duration / 60).toStringAsFixed(duration % 60 == 0 ? 0 : 1)}h',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF757686),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹${amount.toStringAsFixed(0)}',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: paid
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  paid ? 'Paid' : 'Pending',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: paid
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFF57F17),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

DateTime _dateOf(Map<String, dynamic> data) {
  for (final key in ['completedAt', 'endTime', 'startTime', 'createdAt']) {
    final value = data[key];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
  }
  return DateTime.fromMillisecondsSinceEpoch(0);
}

double _amountOf(Map<String, dynamic> data) {
  final value =
      data['amountPaid'] ??
      data['totalAmount'] ??
      data['amount'] ??
      data['price'];
  return (value as num?)?.toDouble() ?? 0;
}
