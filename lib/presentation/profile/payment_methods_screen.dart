import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  int _selectedMethodIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        title: const Text('Payment Methods'),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a default payment method for seamless bookings.',
              style: AppTextStyles.body2.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('Saved Cards'),
            const SizedBox(height: 16),
            _buildCardItem(
              index: 0,
              type: 'Visa',
              last4: '4242',
              expiry: '12/28',
              icon: Icons.credit_card,
            ),
            const SizedBox(height: 12),
            _buildCardItem(
              index: 1,
              type: 'Mastercard',
              last4: '8899',
              expiry: '09/26',
              icon: Icons.credit_card_outlined,
            ),
            const SizedBox(height: 24),
            _buildAddNewButton(
              icon: Icons.add_card,
              label: 'Add New Card',
              onTap: () {},
            ),
            const SizedBox(height: 40),
            _buildSectionHeader('UPI'),
            const SizedBox(height: 16),
            _buildUpiItem(
              index: 2,
              app: 'Google Pay',
              upiId: 'user@okicici',
              iconUrl:
                  'https://upload.wikimedia.org/wikipedia/commons/f/f2/Google_Pay_Logo.svg',
            ),
            const SizedBox(height: 12),
            _buildUpiItem(
              index: 3,
              app: 'PhonePe',
              upiId: 'user@ybl',
              iconUrl:
                  'https://upload.wikimedia.org/wikipedia/en/thumb/6/6b/PhonePe_Logo.svg/1200px-PhonePe_Logo.svg.png',
            ),
            const SizedBox(height: 24),
            _buildAddNewButton(
              icon: Icons.add_circle_outline,
              label: 'Add New UPI ID',
              onTap: () {},
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: Text(
              'Save Preferences',
              style: AppTextStyles.h3.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: AppTextStyles.h3);
  }

  Widget _buildCardItem({
    required int index,
    required String type,
    required String last4,
    required String expiry,
    required IconData icon,
  }) {
    final isSelected = _selectedMethodIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethodIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$type •••• $last4',
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Expires $expiry',
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textSecondaryLight.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpiItem({
    required int index,
    required String app,
    required String upiId,
    required String iconUrl,
  }) {
    final isSelected = _selectedMethodIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethodIndex = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
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
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.bgLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.account_balance, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app,
                    style: AppTextStyles.body1.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    upiId,
                    style: AppTextStyles.body2.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textSecondaryLight.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNewButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: AppTextStyles.body2.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
