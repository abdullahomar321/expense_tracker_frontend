import 'package:expense_tracker/api_calls/expense_api.dart';
import 'package:expense_tracker/services/secure_token_storage.dart';
import 'package:expense_tracker/widgets/expense_chat_context.dart';

class ExpenseContextService {
  static Future<ExpenseChatContext> loadContext({
    required double currentIncome,
    required double currentBalance,
  }) async {
    final token = await SecureTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      return ExpenseChatContext(
        expenses: const [],
        totalSpent: 0,
        totalIncome: currentIncome,
        balance: currentBalance,
        topCategories: const [],
      );
    }

    final response = await ExpenseApi.fetchExpenses(token: token);
    if (response['success'] != true) {
      return ExpenseChatContext(
        expenses: const [],
        totalSpent: 0,
        totalIncome: currentIncome,
        balance: currentBalance,
        topCategories: const [],
      );
    }

    final expenses = (response['expenses'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    double totalSpent = 0;
    final categories = <String, double>{};

    for (final expense in expenses) {
      final amount = _parseDouble(expense['amount']);
      totalSpent += amount;
      final category = (expense['category']?.toString().trim().isNotEmpty ?? false)
          ? expense['category'].toString().trim()
          : 'General';
      categories.update(category, (value) => value + amount, ifAbsent: () => amount);
    }

    final topCategories = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final latestBalance = _parseDouble(response['balance'], currentBalance);

    return ExpenseChatContext(
      expenses: expenses,
      totalSpent: totalSpent,
      totalIncome: currentIncome,
      balance: latestBalance,
      topCategories: topCategories.take(3).toList(),
    );
  }

  static Map<String, dynamic> buildFinancialSnapshot(ExpenseChatContext context) {
    final remaining = context.totalIncome - context.totalSpent;
    return {
      'total_income': context.totalIncome,
      'total_spent': context.totalSpent,
      'remaining_budget': remaining,
      'current_balance': context.balance,
      'expense_count': context.expenses.length,
      'top_categories': context.topCategories
          .map((entry) => {
                'category': entry.key,
                'amount': entry.value,
              })
          .toList(),
    };
  }

  static double _parseDouble(dynamic value, [double fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }
}
