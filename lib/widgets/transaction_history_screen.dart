import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api_calls/wallet_api.dart';
import '../services/secure_token_storage.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  String _selectedFilter = 'All';
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  String _formatDate(dynamic dateString) {
    if (dateString == null) return 'Unknown Date';
    try {
      final DateTime dt = DateTime.parse(dateString.toString()).toLocal();
      return DateFormat('MMM dd, yyyy \u2022 hh:mm a').format(dt);
    } catch (_) {
      return dateString.toString();
    }
  }

  double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _fetchTransactions() async {
    setState(() {
      _isLoading = true;
    });

    final token = await SecureTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      if (mounted) setState(() { _isLoading = false; });
      return;
    }

    Map<String, dynamic> response;
    
    if (_selectedFilter == 'All') {
      response = await WalletApi.fetchFullHistory(token: token);
    } else if (_selectedFilter == 'Money Sent') {
      response = await WalletApi.fetchSentHistory(token: token);
    } else {
      // Expenses
      response = await WalletApi.fetchExpenseHistory(token: token);
    }

    if (mounted) {
      if (response['success']) {
        final List<dynamic> rawData = response['data'] ?? [];
        List<Map<String, dynamic>> parsedList = [];

        for (var tx in rawData) {
          double amount = _parseAmount(tx['amount']);
          String title = 'Unknown';
          String date = 'Unknown Date';
          IconData icon = Icons.receipt_long_outlined;
          Color color = Colors.grey;

          if (_selectedFilter == 'All') {
            final type = tx['type']?.toString().toLowerCase();
            date = _formatDate(tx['date']);
            if (type == 'send') {
              title = tx['name'] ?? 'Sent Money';
              icon = Icons.send_outlined;
              color = Colors.blue;
            } else {
              title = tx['name'] ?? 'Expense';
              icon = Icons.money_off_csred_sharp;
              color = Colors.green;
            }
          } else if (_selectedFilter == 'Money Sent') {
            final rName = tx['receiver_name'];
            title = rName != null ? 'Sent to $rName' : 'Sent Money';
            date = _formatDate(tx['date']);
            icon = Icons.send_outlined;
            color = Colors.blue;
          } else if (_selectedFilter == 'Expenses') {
            title = tx['name'] ?? 'Expense';
            date = _formatDate(tx['created_at'] ?? tx['date']);
            icon = Icons.money_off_csred_sharp;
            color = Colors.green;
          }

          parsedList.add({
            'title': title,
            'date': date,
            'amount': amount,
            'icon': icon,
            'color': color,
            'note': tx['note'], // In case there's a note
          });
        }

        setState(() {
          _transactions = parsedList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _transactions = [];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Failed to load history')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50],
      child: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: ['All', 'Expenses', 'Money Sent'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilterChip(
                    label: Text(
                      filter,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (!isSelected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                        _fetchTransactions();
                      }
                    },
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFF10B981),
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF10B981) : Colors.grey.shade300,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Transactions List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF10B981)),
                  )
                : _transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions found',
                              style: TextStyle(color: Colors.grey[500], fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final tx = _transactions[index];
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: Row(
                              children: [
                                // Icon container
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: (tx['color'] as Color).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    tx['icon'],
                                    color: tx['color'],
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx['title'],
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            tx['date'],
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (tx['note'] != null && tx['note'].toString().isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Icon(Icons.circle, size: 4, color: Colors.grey[400]),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                tx['note'],
                                                style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 13,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Amount (Since all are expenses/sent money, we show them as negative)
                                Text(
                                  '-\$${tx['amount'].abs().toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFFE85D4C),
                                  ),
                                ),
                              ],
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
