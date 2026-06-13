import 'package:expense_tracker/services/secure_token_storage.dart';

class ApiHeaders {
  static Map<String, String> json() => const {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Future<Map<String, String>> authorizedJson() async {
    final headers = Map<String, String>.from(json());
    final token = await SecureTokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
}
