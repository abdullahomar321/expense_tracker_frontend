import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../api_calls/expense_api.dart';
import '../api_calls/income_api.dart';
import '../providers/user_provider.dart';
import '../services/secure_token_storage.dart';

// Helper function to safely parse double from various types
double _parseAmount(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

// Generate PDF Report
Future<void> _generatePdfReport(
  BuildContext context,
  List<Map<String, dynamic>> expenses,
  double balance,
  double totalIncome,
) async {
  final pdf = pw.Document();

  // Calculate totals
  final totalSpent = expenses.fold<double>(
    0,
    (sum, expense) => sum + _parseAmount(expense['amount']),
  );
  final deficit = totalSpent > totalIncome ? totalSpent - totalIncome : 0.0;
  final remaining = balance; // balance is the remaining balance

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Center(
              child: pw.Text(
                'Expense Report',
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.green800,
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Generated on: ${DateTime.now().toString().split('.')[0]}',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
            ),
            pw.SizedBox(height: 30),

            // Financial Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Financial Summary',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green800,
                    ),
                  ),
                  pw.SizedBox(height: 15),
                  _buildSummaryRow('Total Income', '\$${totalIncome.toStringAsFixed(2)}'),
                  _buildSummaryRow('Total Spent', '\$${totalSpent.toStringAsFixed(2)}'),
                  _buildSummaryRow('Current Balance', '\$${balance.toStringAsFixed(2)}'),
                  pw.Divider(color: PdfColors.green200),
                  if (deficit > 0)
                    _buildSummaryRow(
                      'DEFICIT',
                      '\$${deficit.toStringAsFixed(2)}',
                      isDeficit: true,
                    )
                  else
                    _buildSummaryRow(
                      'Remaining',
                      '\$${remaining.toStringAsFixed(2)}',
                      isPositive: true,
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // Expense Details
            pw.Text(
              'Expense Details',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
            pw.SizedBox(height: 15),

            if (expenses.isEmpty)
              pw.Text(
                'No expenses recorded.',
                style: const pw.TextStyle(color: PdfColors.grey600),
              )
            else
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.green700,
                ),
                cellPadding: const pw.EdgeInsets.all(8),
                cellAlignment: pw.Alignment.centerLeft,
                headers: ['Name', 'Amount', 'Date'],
                data: expenses.map((expense) {
                  return [
                    expense['name'] ?? 'Expense',
                    '\$${_parseAmount(expense['amount']).toStringAsFixed(2)}',
                    expense['created_at'] ?? 'N/A',
                  ];
                }).toList(),
              ),

            pw.SizedBox(height: 30),

            // Analysis Section
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: deficit > 0 ? PdfColors.red50 : PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Analysis',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: deficit > 0 ? PdfColors.red800 : PdfColors.blue800,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    deficit > 0
                        ? 'You are in a deficit of \$${deficit.toStringAsFixed(2)}. Your expenses exceed your remaining balance by this amount.'
                        : 'You have a surplus of \$${remaining.toStringAsFixed(2)}. Your expenses are within your income.',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Total Expenses: ${expenses.length}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'Average per Expense: \$${(expenses.isNotEmpty ? totalSpent / expenses.length : 0).toStringAsFixed(2)}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  // Request storage permission on Android
  if (await Permission.storage.isDenied) {
    await Permission.storage.request();
  }

  // Save PDF directly to Downloads folder
  final fileName = 'Expense_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
  final pdfBytes = await pdf.save();

  // Get the downloads directory
  Directory? directory;
  if (Platform.isAndroid) {
    directory = Directory('/storage/emulated/0/Download');
  } else if (Platform.isIOS) {
    directory = await getApplicationDocumentsDirectory();
  } else {
    directory = await getDownloadsDirectory();
  }

  if (directory != null) {
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(pdfBytes);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("PDF saved to Downloads as $fileName")),
    );
  } else {
    // Fallback to share dialog
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: fileName,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("PDF saved as $fileName")),
    );
  }
}

// Helper to build summary rows
pw.Widget _buildSummaryRow(String label, String value, {bool isDeficit = false, bool isPositive = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: isDeficit ? PdfColors.red800 : (isPositive ? PdfColors.green800 : PdfColors.black),
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: isDeficit ? PdfColors.red800 : (isPositive ? PdfColors.green800 : PdfColors.black),
          ),
        ),
      ],
    ),
  );
}

class Expenses extends StatefulWidget {
  const Expenses({super.key});

  @override
  State<Expenses> createState() => _ExpensesState();
}

class _ExpensesState extends State<Expenses> {
  final TextEditingController _incomeController = TextEditingController();
  final TextEditingController _expenseNameController = TextEditingController();
  final TextEditingController _expenseAmountController = TextEditingController();

  bool _isSubmitting = false;
  bool _isLoading = true;
  final List<Map<String, dynamic>> _expenses = [];
  String? _token;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);

    _token = await SecureTokenStorage.getToken();
    if (_token == null || _token!.isEmpty) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unauthenticated. Please log in again.")),
      );
      return;
    }

    final response = await ExpenseApi.fetchExpenses(token: _token!);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response['success']) {
      final expensesList = response['expenses'] as List<dynamic>? ?? [];
      final mappedExpenses = expensesList.map((e) => Map<String, dynamic>.from(e)).toList();

      setState(() {
        _expenses
          ..clear()
          ..addAll(mappedExpenses);
      });

      final totalSpent = mappedExpenses.fold<double>(
        0,
        (sum, expense) => sum + _parseAmount(expense['amount']),
      );
      context.read<UserProvider>().updateSpent(totalSpent);

      // Update balance from API
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? "Failed to load expenses")),
      );
    }
  }

  // Function to show the Add Income Dialog
  void _showAddIncomeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Add Monthly Income",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Enter your total income to set your starting balance.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _incomeController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                hintText: "0.00",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            ),
            onPressed: _isSubmitting ? null : _submitIncome,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    "Add",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  // API Call Logic for Income
  Future<void> _submitIncome() async {
    final amountStr = _incomeController.text;
    if (amountStr.isEmpty) return;

    final double amount = double.tryParse(amountStr) ?? 0.0;

    setState(() => _isSubmitting = true);

    final token = await SecureTokenStorage.getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unauthenticated. Please log in again.")),
      );
      return;
    }

    final response = await IncomeApi.addIncome(
      amount: amount,
      description: "Initial Balance",
      token: token,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (response['success']) {
      _incomeController.clear();

      final provider = context.read<UserProvider>();

      final data = response['data'];
      if (data != null) {
        final balanceVal = data['new_balance'] ?? data['balance'] ?? data['total_income'] ?? data['totalIncome'];
        if (balanceVal != null) {
          double serverBalance = amount;
          if (balanceVal is num) {
            serverBalance = balanceVal.toDouble();
          } else if (balanceVal is String) {
            serverBalance = double.tryParse(balanceVal) ?? amount;
          }
          provider.updateBalance(serverBalance);
          provider.updateTotalIncome(serverBalance + provider.spent);
        }
      } else {
        provider.updateBalance(provider.balance + amount);
        provider.updateTotalIncome(provider.totalIncome + amount);
      }

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Income added successfully!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? "Failed to add income")),
      );
    }
  }

  // Function to show the Add Expense Dialog
  void _showAddExpenseDialog() {
    _expenseNameController.clear();
    _expenseAmountController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Add Expense",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _expenseNameController,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.shopping_bag_outlined, color: Colors.green),
                hintText: "Expense Name (e.g., Food, Rent)",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _expenseAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                hintText: "Amount Spent",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            ),
            onPressed: _isSubmitting ? null : _submitExpense,
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    "Add",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  // Function to show Edit Expense Dialog
  void _showEditExpenseDialog(Map<String, dynamic> expense) {
    _expenseNameController.text = expense['name'] ?? '';
    _expenseAmountController.text = expense['amount']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Edit Expense",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _expenseNameController,
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.shopping_bag_outlined, color: Colors.green),
                hintText: "Expense Name",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _expenseAmountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                hintText: "Amount",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            ),
            onPressed: _isSubmitting ? null : () => _updateExpense(expense),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    "Update",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  // Submit new expense
  Future<void> _submitExpense() async {
    final name = _expenseNameController.text.trim();
    final amountStr = _expenseAmountController.text.trim();

    if (name.isEmpty || amountStr.isEmpty) return;

    final double? amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid amount")),
      );
      return;
    }

    final userProvider = context.read<UserProvider>();
    if (userProvider.balance < amount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Insufficient balance")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final token = await SecureTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unauthenticated. Please log in again.")),
      );
      return;
    }

    final response = await ExpenseApi.addExpense(
      token: token,
      name: name,
      amount: amount,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (response['success']) {
      final double newBalance = userProvider.balance - amount;
      final double newSpent = userProvider.spent + amount;
      userProvider.updateBalance(newBalance);
      userProvider.updateSpent(newSpent);

      // Reload expenses from server
      await _loadExpenses();

      _expenseNameController.clear();
      _expenseAmountController.clear();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Expense added successfully!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? "Failed to add expense")),
      );
    }
  }

  // Update expense (PUT API)
  Future<void> _updateExpense(Map<String, dynamic> expense) async {
    final name = _expenseNameController.text.trim();
    final amountStr = _expenseAmountController.text.trim();

    if (name.isEmpty || amountStr.isEmpty) return;

    final double? newAmount = double.tryParse(amountStr);
    if (newAmount == null || newAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid amount")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final token = await SecureTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unauthenticated. Please log in again.")),
      );
      return;
    }

    final expenseId = expense['id'];
    if (expenseId == null) {
      setState(() => _isSubmitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid expense ID")),
      );
      return;
    }

    final oldAmount = _parseAmount(expense['amount']);
    final response = await ExpenseApi.updateExpense(
      token: token,
      expenseId: expenseId,
      name: name,
      amount: newAmount,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (response['success']) {
      final userProvider = context.read<UserProvider>();

      // Adjust balance based on amount difference
      final amountDiff = newAmount - oldAmount;
      final double newBalance = userProvider.balance - amountDiff;
      final double newSpent = userProvider.spent + amountDiff;
      userProvider.updateBalance(newBalance);
      userProvider.updateSpent(newSpent);

      // Reload expenses from server
      await _loadExpenses();

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Expense updated successfully!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? "Failed to update expense")),
      );
    }
  }

  // Delete expense (swipe right)
  Future<void> _deleteExpense(Map<String, dynamic> expense) async {
    final token = await SecureTokenStorage.getToken();
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unauthenticated. Please log in again.")),
      );
      return;
    }

    final expenseId = expense['id'];
    if (expenseId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid expense ID")),
      );
      return;
    }

    final response = await ExpenseApi.deleteExpense(
      token: token,
      expenseId: expenseId,
    );

    if (!mounted) return;

    if (response['success']) {
      // Update local balance
      final amount = _parseAmount(expense['amount']);
      final userProvider = context.read<UserProvider>();
      final double newBalance = userProvider.balance + amount;
      final double newSpent = userProvider.spent - amount;
      userProvider.updateBalance(newBalance);
      userProvider.updateSpent(newSpent < 0 ? 0 : newSpent);

      setState(() {
        _expenses.removeWhere((e) => e['id'] == expenseId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Expense deleted!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response['message'] ?? "Failed to delete expense")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final balance = user.balance;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.green,
          ),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: IconButton(
              icon: const Icon(
                Icons.add,
                color: Colors.green,
                size: 28,
              ),
              onPressed: _showAddIncomeDialog,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          // Main Balance Card
          Container(
            height: 180,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.08),
                  spreadRadius: 2,
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Current Balance",
                        style: TextStyle(
                          color: Colors.green.shade400,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "\$${balance.toStringAsFixed(2)}",
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // PDF button at bottom right
                Positioned(
                  bottom: 15,
                  right: 15,
                  child: IconButton(
                    icon: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.green,
                      size: 28,
                    ),
                    onPressed: () => _generatePdfReport(
                      context,
                      _expenses,
                      user.balance,
                      user.totalIncome,
                    ),
                    tooltip: 'Generate PDF Report',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // Recent Expenses Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Recent Expenses",
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "Swipe ← Edit | Delete →",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Expenses List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _expenses.isEmpty
                    ? Center(
                        child: Text(
                          "No expenses added yet.",
                          style: TextStyle(
                            color: Colors.green.shade300,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadExpenses,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: _expenses.length,
                          itemBuilder: (context, index) {
                            final expense = _expenses[index];
                            final expenseAmount = _parseAmount(expense['amount']);

                            return Dismissible(
                              key: Key('expense_${expense['id']}'),
                              // Swipe right to delete
                              direction: DismissDirection.horizontal,
                              background: Container(
                                alignment: Alignment.centerLeft,
                                padding: const EdgeInsets.only(left: 20),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              secondaryBackground: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Icon(Icons.edit, color: Colors.white),
                              ),
                              confirmDismiss: (direction) async {
                                if (direction == DismissDirection.startToEnd) {
                                  // Swipe right - delete
                                  return await showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text("Delete Expense"),
                                      content: const Text("Are you sure you want to delete this expense?"),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  // Swipe left - edit
                                  _showEditExpenseDialog(expense);
                                  return false;
                                }
                              },
                              onDismissed: (direction) {
                                if (direction == DismissDirection.startToEnd) {
                                  _deleteExpense(expense);
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: Colors.green.shade50,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withValues(alpha: 0.02),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Icon(
                                            Icons.shopping_bag_outlined,
                                            color: Colors.green.shade700,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(width: 15),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              expense['name'] ?? 'Expense',
                                              style: TextStyle(
                                                color: Colors.green.shade900,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              expense['created_at'] ?? 'Today',
                                              style: TextStyle(
                                                color: Colors.green.shade300,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Text(
                                      "-\$${expenseAmount.toStringAsFixed(2)}",
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: SizedBox(
        height: 48,
        child: FloatingActionButton.extended(
          onPressed: _showAddExpenseDialog,
          backgroundColor: Colors.green,
          elevation: 6,
          icon: const Icon(Icons.remove_circle_outline, color: Colors.white),
          label: const Text(
            "Add Expenses",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
