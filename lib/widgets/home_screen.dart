import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/widgets/quick_actions_row.dart';
import 'package:expense_tracker/widgets/summary_card.dart';
import 'package:expense_tracker/services/secure_token_storage.dart';
import 'package:expense_tracker/api_calls/wallet_api.dart';
import 'package:expense_tracker/api_calls/expense_api.dart';
import 'package:expense_tracker/widgets/expense_pie_chart.dart';
import 'package:expense_tracker/widgets/expenses.dart';
import 'package:expense_tracker/widgets/send_money_screen.dart';
import 'package:expense_tracker/widgets/split_bill_hangout_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onSplitBill,
    this.onSendMoney,
    this.onEnterExpenses,
  });

  final VoidCallback? onSplitBill;
  final Future<void> Function()? onSendMoney;
  final VoidCallback? onEnterExpenses;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _recentTransactions = [];
  List<Map<String, dynamic>> _expenses = [];
  bool _isLoadingHistory = true;
  bool _isLoadingExpenses = true;

  @override
  void initState() {
    super.initState();
    _fetchFreshBalance();
    _fetchRecentTransactions();
    _fetchExpenses();
  }

  Future<void> _fetchFreshBalance() async {
    final token = await SecureTokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      final response = await WalletApi.fetchBalance(token: token);
      if (mounted && response['success']) {
        final newBalance = response['balance'];
        double parsedBalance = 0;
        if (newBalance is num) {
          parsedBalance = newBalance.toDouble();
        } else if (newBalance is String) {
          parsedBalance = double.tryParse(newBalance) ?? 0;
        }
        context.read<UserProvider>().updateBalance(parsedBalance);
      }
    }
  }

  Future<void> _fetchExpenses() async {
    final token = await SecureTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      if (mounted) setState(() { _isLoadingExpenses = false; });
      return;
    }

    final response = await ExpenseApi.fetchExpenses(token: token);
    if (mounted) {
      if (response['success']) {
        final List<dynamic> rawExpenses = response['expenses'] ?? [];
        final mappedExpenses = rawExpenses.map((e) => Map<String, dynamic>.from(e)).toList();
        setState(() {
          _expenses = mappedExpenses;
          _isLoadingExpenses = false;
        });

        // Also sync user provider spent/balance
        double totalSpent = 0;
        for (final expense in mappedExpenses) {
          final amountVal = expense['amount'];
          double parsedAmt = 0;
          if (amountVal is num) {
            parsedAmt = amountVal.toDouble();
          } else if (amountVal is String) {
            parsedAmt = double.tryParse(amountVal) ?? 0;
          }
          totalSpent += parsedAmt;
        }
        context.read<UserProvider>().updateSpent(totalSpent);
        final balance = response['balance'];
        if (balance != null) {
          double newBalance = 0;
          if (balance is num) {
            newBalance = balance.toDouble();
          } else if (balance is String) {
            newBalance = double.tryParse(balance) ?? 0;
          }
          context.read<UserProvider>().updateBalance(newBalance);
          context.read<UserProvider>().updateTotalIncome(newBalance + totalSpent);
        }
      } else {
        setState(() { _isLoadingExpenses = false; });
      }
    }
  }

  Future<void> _fetchRecentTransactions() async {
    final token = await SecureTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      if (mounted) setState(() { _isLoadingHistory = false; });
      return;
    }

    final response = await WalletApi.fetchFullHistory(token: token);
    if (mounted) {
      if (response['success']) {
        final List<dynamic> rawData = response['data'] ?? [];
        List<Map<String, dynamic>> parsedList = [];

        final fiveDaysAgo = DateTime.now().subtract(const Duration(days: 5));

        for (var tx in rawData) {
          final dateString = tx['date'] ?? tx['created_at'];
          if (dateString == null) continue;

          DateTime dt;
          try {
            dt = DateTime.parse(dateString.toString()).toLocal();
          } catch (_) {
            continue;
          }

          if (dt.isBefore(fiveDaysAgo)) {
            continue;
          }

          double amount = 0.0;
          if (tx['amount'] is num) {
            amount = tx['amount'].toDouble();
          } else if (tx['amount'] is String) {
            amount = double.tryParse(tx['amount']) ?? 0.0;
          }

          String title = 'Unknown';
          IconData icon = Icons.receipt_long_outlined;
          Color color = Colors.grey;

          final type = tx['type']?.toString().toLowerCase();
          if (type == 'send') {
            title = tx['name'] ?? 'Sent Money';
            icon = Icons.send_outlined;
            color = Colors.blue;
          } else {
            title = tx['name'] ?? 'Expense';
            icon = Icons.shopping_cart_outlined;
            color = Colors.orange;
          }

          parsedList.add({
            'title': title,
            'date': DateFormat('MMM dd \u2022 hh:mm a').format(dt),
            'amount': amount,
            'icon': icon,
            'color': color,
            'timestamp': dt,
          });
        }

        // Sort descending
        parsedList.sort((a, b) => (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));

        setState(() {
          _recentTransactions = parsedList;
          _isLoadingHistory = false;
        });
      } else {
        setState(() { _isLoadingHistory = false; });
      }
    }
  }

  void _refreshAllData() {
    _fetchFreshBalance();
    _fetchRecentTransactions();
    _fetchExpenses();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final displayName = user.name.isNotEmpty ? user.name.split(' ').first : 'there';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Welcome $displayName',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF10B981),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
          QuickActionsRow(
            onSplitBill: () {
              if (widget.onSplitBill != null) {
                widget.onSplitBill!();
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SplitBillHangoutScreen(),
                  ),
                );
              }
            },
            onSendMoney: () async {
              if (widget.onSendMoney != null) {
                await widget.onSendMoney!();
                _refreshAllData();
              } else {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SendMoneyScreen(),
                  ),
                );
                _refreshAllData();
              }
            },
            onEnterExpenses: () async {
              if (widget.onEnterExpenses != null) {
                widget.onEnterExpenses!();
              } else {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const Expenses(),
                  ),
                );
                _refreshAllData();
              }
            },
          ),
          const SizedBox(height: 15),
          SummaryCard(
            budget: user.balance,
            spent: user.spent,
          ),
          const SizedBox(height: 24),
          
          // Recent Transactions Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Recent Transactions (Last 5 days)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Recent Transactions List
          if (_isLoadingHistory)
             const Padding(
               padding: EdgeInsets.all(24.0),
               child: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
             )
          else if (_recentTransactions.isEmpty)
             const Padding(
               padding: EdgeInsets.all(24.0),
               child: Center(
                 child: Text(
                   'No transactions in the last 5 days.',
                   style: TextStyle(color: Colors.grey, fontSize: 16),
                 ),
               ),
             )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _recentTransactions.length > 4 ? 4 : _recentTransactions.length,
              itemBuilder: (context, index) {
                final tx = _recentTransactions[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (tx['color'] as Color).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(tx['icon'], color: tx['color'], size: 24),
                      ),
                      const SizedBox(width: 16),
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
                            Text(
                              tx['date'],
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
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
          const SizedBox(height: 12),
          // Circular Progress Indicator (Donut Chart) for Expenses Overview
          if (_isLoadingExpenses)
            _isLoadingHistory
                ? const SizedBox.shrink()
                : const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF10B981))),
                  )
          else
            ExpensePieChart(expenses: _expenses),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
