import 'dart:math';
import 'package:flutter/material.dart';

class ExpensePieChart extends StatelessWidget {
  const ExpensePieChart({super.key, required this.expenses});

  final List<Map<String, dynamic>> expenses;

  static const List<Color> _sliceColors = [
    Color(0xFFEF4444), // Red
    Color(0xFF3B82F6), // Blue
    Color(0xFFF97316), // Orange
    Color(0xFF10B981), // Green
    Color(0xFF8B5CF6), // Purple
    Color(0xFFEC4899), // Pink
    Color(0xFF06B6D4), // Cyan
    Color(0xFF94A3B8), // Slate gray for the rest
  ];

  double _parseAmount(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // 1. Map expenses to helper objects & filter out zero/negative amounts
    final List<_ExpenseItem> parsedItems = [];
    for (final exp in expenses) {
      final amt = _parseAmount(exp['amount']);
      if (amt > 0) {
        parsedItems.add(_ExpenseItem(
          name: exp['name']?.toString() ?? 'Expense',
          amount: amt,
        ));
      }
    }

    // 2. Sort descending by amount
    parsedItems.sort((a, b) => b.amount.compareTo(a.amount));

    // 3. Compute total
    final totalSpent = parsedItems.fold<double>(0, (sum, item) => sum + item.amount);

    if (parsedItems.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Column(
          children: [
            Text(
              'Expenses Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 20),
            Center(
              child: Text(
                'No expenses entered yet to chart.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    // Group items beyond the 6th to keep the list and colors readable, or display top 5 and group "Others"
    final List<_ChartSegment> segments = [];
    double otherAmount = 0;

    for (int i = 0; i < parsedItems.length; i++) {
      final item = parsedItems[i];
      if (i < 5 || parsedItems.length <= 6) {
        final color = i < _sliceColors.length ? _sliceColors[i] : _sliceColors.last;
        segments.add(_ChartSegment(
          name: item.name,
          amount: item.amount,
          color: color,
        ));
      } else {
        otherAmount += item.amount;
      }
    }

    if (otherAmount > 0) {
      segments.add(_ChartSegment(
        name: 'Other Expenses',
        amount: otherAmount,
        color: _sliceColors.last,
      ));
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Expenses Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Chart area
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  children: [
                    CustomPaint(
                      size: const Size(140, 140),
                      painter: _DonutChartPainter(segments: segments, total: totalSpent),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'TOTAL',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '\$${totalSpent.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Legend
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: segments.map((seg) {
                    final percentage = (seg.amount / totalSpent) * 100;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: seg.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              seg.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${percentage.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpenseItem {
  _ExpenseItem({required this.name, required this.amount});
  final String name;
  final double amount;
}

class _ChartSegment {
  _ChartSegment({required this.name, required this.amount, required this.color});
  final String name;
  final double amount;
  final Color color;
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({required this.segments, required this.total});

  final List<_ChartSegment> segments;
  final double total;

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 18.0;
    final Rect rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.width - strokeWidth) / 2,
    );

    double startAngle = -pi / 2;

    for (final seg in segments) {
      final sweepAngle = (seg.amount / total) * 2 * pi;

      final paint = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
