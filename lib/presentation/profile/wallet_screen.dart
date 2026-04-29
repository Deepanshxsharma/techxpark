import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 80.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 10, 20, bottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBalanceCard(context),
            const SizedBox(height: 32),
            _buildSectionTitle(context, 'Payment Methods'),
            const SizedBox(height: 16),
            _buildPaymentMethodsCarousel(context),
            const SizedBox(height: 32),
            _buildSectionTitle(context, 'Recent Transactions'),
            const SizedBox(height: 16),
            _buildTransactionList(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance',
            style: AppTextStyles.body2.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹2,450.00',
            style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 36),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.add_circle_outline,
                  label: 'Add Funds',
                  isPrimary: true,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Withdraw',
                  isPrimary: false,
                  onTap: () {},
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isPrimary
                ? Colors.white
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: !isPrimary
                ? Border.all(color: Colors.white.withValues(alpha: 0.3))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isPrimary ? AppColors.primary : Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.body2SemiBold.copyWith(
                  color: isPrimary ? AppColors.primary : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.h3),
        Icon(Icons.more_horiz, color: AppColors.textTertiaryLight),
      ],
    );
  }

  Widget _buildPaymentMethodsCarousel(BuildContext context) {
    return SizedBox(
      height: 70,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          _buildPaymentCard(
            brandName: 'Amazon Pay',
            icon: Icons.account_balance_wallet,
            color: const Color(0xFFF9A825), // amazon orangeish
            lastDigits: 'UPI',
            isSelected: true,
          ),
          const SizedBox(width: 12),
          _buildPaymentCard(
            brandName: 'Credit Card',
            icon: Icons.credit_card,
            color: const Color(0xFF1E88E5), // Visa blue
            lastDigits: '•• 4242',
            isSelected: false,
          ),
          const SizedBox(width: 12),
          _buildAddPaymentCard(),
        ],
      ),
    );
  }

  Widget _buildPaymentCard({
    required String brandName,
    required IconData icon,
    required Color color,
    required String lastDigits,
    required bool isSelected,
  }) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.borderLight,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  brandName,
                  style: AppTextStyles.captionBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  lastDigits,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPaymentCard() {
    return Container(
      width: 70,
      decoration: BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderLight,
          style: BorderStyle.solid,
        ),
      ),
      child: Center(child: Icon(Icons.add, color: AppColors.primary)),
    );
  }

  Widget _buildTransactionList(BuildContext context) {
    return Column(
      children: [
        _buildTransactionTile(
          title: 'Orion Mall Parking',
          date: 'Today, 2:30 PM',
          amount: '-₹40.00',
          icon: Icons.local_parking,
          iconColor: AppColors.primary,
          isNegative: true,
        ),
        _buildTransactionTile(
          title: 'Top Up',
          date: 'Yesterday, 10:00 AM',
          amount: '+₹500.00',
          icon: Icons.account_balance_wallet,
          iconColor: AppColors.success,
          isNegative: false,
        ),
        _buildTransactionTile(
          title: 'Gardenia Aprt. Parking',
          date: 'Oct 12, 1:15 PM',
          amount: '-₹60.00',
          icon: Icons.directions_car,
          iconColor: AppColors.primary,
          isNegative: true,
        ),
      ],
    );
  }

  Widget _buildTransactionTile({
    required String title,
    required String date,
    required String amount,
    required IconData icon,
    required Color iconColor,
    required bool isNegative,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body2SemiBold,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: AppTextStyles.body2SemiBold.copyWith(
              color: isNegative
                  ? AppColors.textPrimaryLight
                  : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
