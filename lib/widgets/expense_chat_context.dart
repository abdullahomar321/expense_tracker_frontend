class ExpenseChatContext {
  const ExpenseChatContext({
    required this.expenses,
    required this.totalSpent,
    required this.totalIncome,
    required this.balance,
    required this.topCategories,
  });

  final List<Map<String, dynamic>> expenses;
  final double totalSpent;
  final double totalIncome;
  final double balance;
  final List<MapEntry<String, double>> topCategories;
}
