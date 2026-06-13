import 'package:flutter/material.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    this.budget = 0,
    this.spent = 0,
    this.periodLabel,
  });

  final double budget;
  final double spent;
  final String? periodLabel;

  static const _titleColor = Color(0xFF0F172A);
  static const _labelColor = Color(0xFF94A3B8);
  static const _spentColor = Color(0xFFE85D4C);
  static const _remainingColor = Color(0xFF10B981);
  static const _trackColor = Color(0xFFE2E8F0);

  double get _remaining => budget - spent;

  double get _usedFraction =>
      budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;

  int get _usedPercent => (_usedFraction * 100).round();

  String _formatAmount(double amount) => '\$${amount.toStringAsFixed(0)}';

  String _currentPeriodLabel() {
    final now = DateTime.now();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text(
                'Summary',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _titleColor,
                  letterSpacing: -0.3,
                ),
              ),
              Text(
                periodLabel ?? _currentPeriodLabel(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: _labelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SummaryRow(
            label: 'Budget',
            value: _formatAmount(budget),
            valueColor: _titleColor,
          ),
          const SizedBox(height: 16),
          _SummaryRow(
            label: 'Spent',
            value: _formatAmount(spent),
            valueColor: _spentColor,
          ),
          const SizedBox(height: 16),
          _SummaryRow(
            label: 'Remaining',
            value: _formatAmount(_remaining),
            valueColor: _remainingColor,
          ),
          const SizedBox(height: 24),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: _usedFraction,
                backgroundColor: _trackColor,
                color: _usedFraction > 0.45 ? _spentColor : _remainingColor,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '$_usedPercent% used',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: _labelColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: SummaryCard._labelColor,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: valueColor,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}
