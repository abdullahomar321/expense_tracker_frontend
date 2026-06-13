import 'dart:convert';
import 'package:expense_tracker/api_calls/api_config.dart';
import 'package:http/http.dart' as http;

class WalletApi {
  static Future<Map<String, dynamic>> fetchUsers({
    required String token,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/users");

    try {
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
        // Handle object returning users array
        final usersList = data["users"] ?? data["data"] ?? [];
        return {
          "success": true,
          "users": usersList,
        };
      } else {
        return {
          "success": false,
          "message": data["message"] ?? "Failed to fetch users",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "message": e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> sendMoney({
    required String token,
    required String email,
    required double amount,
    String? note,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/wallet/send");

    try {
      final bodyData = {
        "receiver_email": email,
        "amount": amount,
      };
      if (note != null && note.isNotEmpty) {
        bodyData["note"] = note;
      }

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode(bodyData),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          "success": true,
          "message": data["message"] ?? "Money sent successfully",
        };
      } else {
        return {
          "success": false,
          "message": data["message"] ?? "Failed to send money",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "message": e.toString(),
      };
    }
  }

  static Future<Map<String, dynamic>> fetchBalance({
    required String token,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/wallet/balance");

    try {
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
          "balance": data["balance"],
        };
      } else {
        return {
          "success": false,
          "message": data["message"] ?? "Failed to fetch balance",
        };
      }
    } catch (e) {
      return {
        "success": false,
        "message": e.toString(),
      };
    }
  }
  static Future<Map<String, dynamic>> fetchFullHistory({required String token}) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/history");
    try {
      final response = await http.get(url, headers: {"Accept": "application/json", "Authorization": "Bearer $token"});
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {"success": true, "data": data["history"] ?? []};
      }
      return {"success": false, "message": data["message"] ?? "Failed to fetch history"};
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> fetchSentHistory({required String token}) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/history/sent");
    try {
      final response = await http.get(url, headers: {"Accept": "application/json", "Authorization": "Bearer $token"});
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {"success": true, "data": data["transactions"] ?? []};
      }
      return {"success": false, "message": data["message"] ?? "Failed to fetch sent history"};
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }

  static Future<Map<String, dynamic>> fetchExpenseHistory({required String token}) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/history/expenses");
    try {
      final response = await http.get(url, headers: {"Accept": "application/json", "Authorization": "Bearer $token"});
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {"success": true, "data": data["expenses"] ?? []};
      }
      return {"success": false, "message": data["message"] ?? "Failed to fetch expense history"};
    } catch (e) {
      return {"success": false, "message": e.toString()};
    }
  }
}
