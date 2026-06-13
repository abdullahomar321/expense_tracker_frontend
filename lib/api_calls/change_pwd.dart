import 'dart:convert';
import 'package:expense_tracker/api_calls/api_config.dart';
import 'package:expense_tracker/api_calls/api_headers.dart';
import 'package:expense_tracker/api_calls/api_response_parser.dart';
import 'package:http/http.dart' as http;

class ChangePasswordApi {
  static const _requestTimeout = Duration(seconds: 15);

  static Future<ChangePasswordResult> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/change-password'),
            headers: await ApiHeaders.authorizedJson(),
            body: jsonEncode({
              'current_password': currentPassword,
              'old_password': currentPassword, // Supporting backends that expect old_password
              'password': newPassword,
              'new_password': newPassword, // Supporting backends that expect new_password
              // Laravel's default validation uses password_confirmation
              'password_confirmation': confirmPassword,
              'confirm_password': confirmPassword, // Supporting backends that expect confirm_password
              'new_password_confirmation': confirmPassword, // Supporting backends that expect new_password_confirmation
            }),
          )
          .timeout(_requestTimeout);

      final body = ApiResponseParser.decodeBody(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ChangePasswordResult(
          success: true,
          message: ApiResponseParser.readMessage(
            body,
            fallback: 'Password changed successfully',
          ),
        );
      }

      // 401: token expired / unauthenticated
      if (response.statusCode == 401) {
        return const ChangePasswordResult(
          success: false,
          message: 'Session expired. Please log in again.',
          isSessionExpired: true,
        );
      }

      // 422: validation error (wrong current password, password rules, etc.)
      return ChangePasswordResult(
        success: false,
        message: ApiResponseParser.readError(
          body,
          fallback: 'Failed to change password. Please check your inputs.',
        ),
      );
    } on http.ClientException {
      return const ChangePasswordResult(
        success: false,
        message: 'Could not reach server. Check your connection.',
      );
    } catch (e) {
      return ChangePasswordResult(
        success: false,
        message: 'Something went wrong. Please try again.',
      );
    }
  }
}

class ChangePasswordResult {
  const ChangePasswordResult({
    required this.success,
    required this.message,
    this.isSessionExpired = false,
  });

  final bool success;
  final String message;
  final bool isSessionExpired;
}
