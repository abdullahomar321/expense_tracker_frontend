import 'dart:convert';
import 'package:expense_tracker/api_calls/api_config.dart';
import 'package:http/http.dart' as http;

// Helper to safely parse double from various types
double _parseDouble(dynamic value, [double defaultValue = 0.0]) {
  if (value == null) return defaultValue;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? defaultValue;
  return defaultValue;
}

class ExpenseApi {
  static Future<Map<String, dynamic>> addExpense({
    required String token,
    required String name,
    required double amount,
    String? category,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/expenses");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "name": name,
        "amount": amount,
        "category": category ?? "General",
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return {
        "success": true,
        "data": data,
      };
    } else {
      return {
        "success": false,
        "message": data["message"] ?? "Failed to add expense",
      };
    }
  }

  static Future<Map<String, dynamic>> fetchExpenses({
    required String token,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/expenses");

    final response = await http.get(
      url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {
        "success": true,
        "expenses": data["expenses"] ?? data["data"] ?? [],
        "balance": data.containsKey("balance") ? data["balance"] : null,
      };
    } else {
      return {
        "success": false,
        "message": data["message"] ?? "Failed to fetch expenses",
      };
    }
  }

  static Future<Map<String, dynamic>> deleteExpense({
    required String token,
    required int expenseId,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/expenses/$expenseId");

    final response = await http.delete(
      url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {
        "success": true,
        "data": data,
      };
    } else {
      return {
        "success": false,
        "message": data["message"] ?? "Failed to delete expense",
      };
    }
  }

  static Future<Map<String, dynamic>> updateExpense({
    required String token,
    required int expenseId,
    required String name,
    required double amount,
    String? category,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/expenses/$expenseId");

    final response = await http.put(
      url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "name": name,
        "amount": amount,
        "category": category ?? "General",
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {
        "success": true,
        "data": data,
      };
    } else {
      return {
        "success": false,
        "message": data["message"] ?? "Failed to update expense",
      };
    }
  }
}
