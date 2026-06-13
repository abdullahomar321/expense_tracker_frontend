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

class IncomeApi {
  static Future<Map<String, dynamic>> addIncome({
    required String token,
    required double amount,
    String? description,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/income");

    final response = await http.post(
      url,
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "amount": amount,
        "description": description ?? "",
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
        "message": data["message"] ?? "Something went wrong",
      };
    }
  }

  static Future<Map<String, dynamic>> fetchBalance({
    required String token,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/income");

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
        "balance": _parseDouble(data["balance"]),
      };
    } else {
      return {
        "success": false,
        "message": data["message"] ?? "Something went wrong",
      };
    }
  }
}