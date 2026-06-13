import 'dart:convert';
import 'package:expense_tracker/api_calls/api_config.dart';
import 'package:expense_tracker/api_calls/api_headers.dart';
import 'package:expense_tracker/api_calls/api_response_parser.dart';
import 'package:http/http.dart' as http;

class ForgotPasswordApi {
  static const _requestTimeout = Duration(seconds: 15);

  /// Sends a password reset link to the provided email.
  /// This is a public endpoint — no Bearer token required.
  static Future<ForgotPasswordResult> sendResetEmail(String email) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/forgot-password'),
            headers: ApiHeaders.json(), // public endpoint, no auth
            body: jsonEncode({'email': email}),
          )
          .timeout(_requestTimeout);

      final body = ApiResponseParser.decodeBody(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ForgotPasswordResult(
          success: true,
          message: ApiResponseParser.readMessage(
            body,
            fallback: 'Password reset link sent to your email',
          ),
        );
      }

      // 404: email not registered
      if (response.statusCode == 404) {
        return const ForgotPasswordResult(
          success: false,
          message: 'No account found with this email address.',
        );
      }

      // 422: validation error
      return ForgotPasswordResult(
        success: false,
        message: ApiResponseParser.readError(
          body,
          fallback: 'Unable to send reset link. Please try again.',
        ),
      );
    } on http.ClientException {
      return const ForgotPasswordResult(
        success: false,
        message: 'Could not reach server. Check your connection.',
      );
    } catch (_) {
      return const ForgotPasswordResult(
        success: false,
        message: 'Something went wrong. Please try again.',
      );
    }
  }
}

class ForgotPasswordResult {
  const ForgotPasswordResult({
    required this.success,
    required this.message,
  });

  final bool success;
  final String message;
}
