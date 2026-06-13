import 'package:expense_tracker/widgets/expenses.dart';
import 'package:flutter/material.dart';

class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({
    super.key,
    this.onSplitBill,
    this.onSendMoney,
    this.onEnterExpenses,
  });

  final VoidCallback? onSplitBill;
  final VoidCallback? onSendMoney;
  final VoidCallback? onEnterExpenses;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _QuickActionItem(
              icon: Icons.receipt_long_outlined,
              label: 'Split Bill',
              onTap: onSplitBill,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionItem(
              icon: Icons.send_outlined,
              label: 'Send Money',
              onTap: onSendMoney,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickActionItem(
              icon: Icons.add_circle_outline,
              label: 'Enter Expenses',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Expenses(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  static const Color _primaryGreen = Color(0xFF10B981);
  static const Color _darkGreen = Color(0xFF047857);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 18,
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFDFDFC), // off-white
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFFCF6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: _primaryGreen,
                  size: 26,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _darkGreen,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}