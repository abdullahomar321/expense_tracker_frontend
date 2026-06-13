import 'dart:convert';
import 'package:expense_tracker/api_calls/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class HangoutApi {
  static Future<Map<String, dynamic>> createHangout({
    required String token,
    required String name,
    required List<String> emails,
  }) async {
    final url = Uri.parse("${ApiConfig.baseUrl}/api/hangouts");

    try {
      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "name": name,
          "emails": emails,
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
          "message": data["message"] ?? "Failed to create hangout",
        };
      }
    } catch (e) {
      debugPrint("Error creating hangout: $e");
      return {
        "success": false,
        "message": e.toString(),
      };
    }
  }
}
