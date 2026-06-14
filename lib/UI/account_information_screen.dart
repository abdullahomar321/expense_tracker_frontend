import 'package:expense_tracker/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AccountInformationScreen extends StatelessWidget {
  const AccountInformationScreen({super.key});

  static const _accentColor = Color(0xFF10B981);

  String _formatIncome(double amount) => '\$${amount.toStringAsFixed(0)}';

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _accentColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Account Information',
          style: TextStyle(
            color: Color(0xFF1F2937),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your account details',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            _InfoCard(
              icon: Icons.person_outline_rounded,
              label: 'Name',
              value: user.name,
            ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.email_outlined,
              label: 'Email ID',
              value: user.email,
            ),

            // _InfoCard(
            //   icon: Icons.payments_outlined,
            //   label: 'Total Income',
            //   value: _formatIncome(user.totalIncome),
            //   valueColor: _accentColor,
            // ),
            // const SizedBox(height: 12),
            // _InfoCard(
            //   icon: Icons.shopping_cart_outlined,
            //   label: 'Total Spent',
            //   value: _formatIncome(user.spent),
            //   valueColor: const Color(0xFFE85D4C),
            // ),
            const SizedBox(height: 12),
            _InfoCard(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Current Balance',
              value: _formatIncome(user.balance),
              valueColor: _accentColor,
            ),
            // const SizedBox(height: 12),
            // _InfoCard(
            //   icon: Icons.trending_up_outlined,
            //   label: 'Remaining',
            //   value: _formatIncome(user.balance),
            //   valueColor: _accentColor,
            // ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFF1F2937),
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AccountInformationScreen._accentColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
