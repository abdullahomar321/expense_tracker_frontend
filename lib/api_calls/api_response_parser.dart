import 'dart:convert';

class ApiResponseParser {
  static bool isJsonResponse(String body) {
    if (body.trim().isEmpty) return false;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map || decoded is List;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> decodeBody(String body) {
    if (body.isEmpty) return {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }

  static String readMessage(
    Map<String, dynamic> body, {
    required String fallback,
  }) {
    final message = body['message'];
    if (message is String && message.isNotEmpty) return message;
    return fallback;
  }

  static String readError(
    Map<String, dynamic> body, {
    required String fallback,
  }) {
    final message = body['message'];
    if (message is String && message.isNotEmpty) return message;

    final error = body['error'];
    if (error is String && error.isNotEmpty) return error;

    final detail = body['detail'];
    if (detail is String && detail.isNotEmpty) return detail;

    final errors = body['errors'];
    if (errors is Map) {
      for (final entry in errors.entries) {
        final value = entry.value;
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    }

    return fallback;
  }

  static bool isUserNotFound({
    required int statusCode,
    required String message,
  }) {
    if (statusCode == 404) return true;

    final normalized = message.toLowerCase();
    return normalized.contains('user does not exist') ||
        normalized.contains('user not found') ||
        normalized.contains('no user found') ||
        normalized.contains('account does not exist') ||
        normalized.contains('account not found') ||
        normalized.contains('email not found') ||
        normalized.contains('not registered');
  }

  static bool isEmailAlreadyExists({
    required int statusCode,
    required String message,
  }) {
    if (statusCode == 409) return true;

    final normalized = message.toLowerCase();
    return normalized.contains('already exists') ||
        normalized.contains('already registered') ||
        normalized.contains('email taken') ||
        normalized.contains('duplicate');
  }

  static double readBalance(Map<String, dynamic> data) {
    final value = data['balance'] ??
        data['total_income'] ??
        data['totalIncome'] ??
        data['income'];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static String? readToken(Map<String, dynamic> body) {
    final direct = body['token'] ?? body['access_token'];
    if (direct is String && direct.isNotEmpty) return direct;

    final data = body['data'];
    if (data is Map) {
      final nested = data['token'] ?? data['access_token'];
      if (nested is String && nested.isNotEmpty) return nested;
    }

    return null;
  }

  static bool isInvalidCredentials({
    required int statusCode,
    required String message,
  }) {
    if (statusCode == 401) return true;

    final normalized = message.toLowerCase();
    return normalized.contains('invalid password') ||
        normalized.contains('incorrect password') ||
        normalized.contains('wrong password') ||
        normalized.contains('invalid credentials');
  }
}
