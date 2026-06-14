import 'dart:convert';

import 'package:expense_tracker/api_calls/api_config.dart';
import 'package:expense_tracker/api_calls/api_headers.dart';
import 'package:http/http.dart' as http;

enum LoginErrorType {
  none,
  userNotFound,
  invalidCredentials,
  network,
  server,
  unknown,
}

class LoginResult {
  const LoginResult({
    required this.success,
    required this.message,
    this.errorType = LoginErrorType.none,
    this.token,
    this.userId,
    this.name,
    this.email,
    this.photoUrl,
    this.balance = 0,
  });

  final bool success;
  final String message;
  final LoginErrorType errorType;
  final String? token;
  final String? userId;
  final String? name;
  final String? email;
  final String? photoUrl;
  final double balance;
}

class LoginApi {
  static const _requestTimeout = Duration(seconds: 15);

  static Future<LoginResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse('${ApiConfig.baseUrl}/api/login'),
        headers: ApiHeaders.json(),
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      )
          .timeout(_requestTimeout);

      final body = jsonDecode(response.body);

      final apiMessage = body['message'] ?? '';

      // ✅ SUCCESS
      if (response.statusCode == 200) {
        final token = body['token']; // 🔥 FIX IS HERE

        if (token == null || token.toString().isEmpty) {
          return const LoginResult(
            success: false,
            message: 'Login failed. Token not received from server.',
            errorType: LoginErrorType.unknown,
          );
        }

        final user = body['user'] ?? {};

        // Handle balance - could be num, String, or null
        double balance = 0;
        final balanceValue = user['balance'] ?? 0;
        if (balanceValue is num) {
          balance = balanceValue.toDouble();
        } else if (balanceValue is String) {
          balance = double.tryParse(balanceValue) ?? 0;
        }

        return LoginResult(
          success: true,
          message: body['message'] ?? 'Login successful',
          token: token,
          userId: user['id']?.toString(),
          name: user['name'],
          email: user['email'] ?? email,
          photoUrl: user['photo_url']?.toString() ?? user['avatar']?.toString(),
          balance: balance,
        );
      }

      // ❌ USER NOT FOUND
      if (response.statusCode == 404) {
        return const LoginResult(
          success: false,
          message: 'User does not exist',
          errorType: LoginErrorType.userNotFound,
        );
      }

      // ❌ INVALID CREDENTIALS
      if (response.statusCode == 401) {
        return const LoginResult(
          success: false,
          message: 'Incorrect email or password',
          errorType: LoginErrorType.invalidCredentials,
        );
      }

      // ❌ SERVER ERROR
      if (response.statusCode >= 500) {
        return const LoginResult(
          success: false,
          message: 'Server error. Please try again later.',
          errorType: LoginErrorType.server,
        );
      }

      return LoginResult(
        success: false,
        message: apiMessage.isNotEmpty
            ? apiMessage
            : 'Login failed. Try again.',
        errorType: LoginErrorType.unknown,
      );
    } catch (e) {
      print("LOGIN ERROR => $e");

      return LoginResult(
        success: false,
        message: e.toString(),
        errorType: LoginErrorType.network,
      );
    }
  }
}