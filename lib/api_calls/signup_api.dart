import 'dart:convert';

import 'package:expense_tracker/api_calls/api_config.dart';
import 'package:expense_tracker/api_calls/api_headers.dart';
import 'package:expense_tracker/api_calls/api_response_parser.dart';
import 'package:http/http.dart' as http;

enum SignupErrorType {
  none,
  emailExists,
  validation,
  network,
  server,
  unknown,
}

class SignupResult {
  const SignupResult({
    required this.success,
    required this.message,
    this.errorType = SignupErrorType.none,
  });

  final bool success;
  final String message;
  final SignupErrorType errorType;
}

class SignupApi {
  static const _requestTimeout = Duration(seconds: 15);

  static Future<SignupResult> signup({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/signup'),
            headers: ApiHeaders.json(),
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
              'password_confirmation': confirmPassword, // Laravel's default field name
              'confirm_password': confirmPassword, // Alternative field name some backends use
            }),
          )
          .timeout(_requestTimeout);

      final body = ApiResponseParser.decodeBody(response.body);
      final apiMessage = ApiResponseParser.readError(
        body,
        fallback: '',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!ApiResponseParser.isJsonResponse(response.body)) {
          return const SignupResult(
            success: false,
            message:
                'Unexpected server response. Ensure /api/signup returns JSON.',
            errorType: SignupErrorType.server,
          );
        }

        return SignupResult(
          success: true,
          message: ApiResponseParser.readMessage(
            body,
            fallback: 'Account created successfully',
          ),
        );
      }

      if (ApiResponseParser.isEmailAlreadyExists(
        statusCode: response.statusCode,
        message: apiMessage,
      )) {
        return const SignupResult(
          success: false,
          message: 'An account with this email already exists',
          errorType: SignupErrorType.emailExists,
        );
      }

      if (response.statusCode == 422 || response.statusCode == 400) {
        return SignupResult(
          success: false,
          message: apiMessage.isNotEmpty
              ? apiMessage
              : 'Please check your details and try again',
          errorType: SignupErrorType.validation,
        );
      }

      if (response.statusCode >= 500) {
        return const SignupResult(
          success: false,
          message: 'Server error. Please try again later.',
          errorType: SignupErrorType.server,
        );
      }

      return SignupResult(
        success: false,
        message: apiMessage.isNotEmpty
            ? apiMessage
            : 'Unable to create account. Please try again.',
        errorType: SignupErrorType.unknown,
      );
    } on http.ClientException {
      return const SignupResult(
        success: false,
        message: 'Could not reach server. Check your connection and try again.',
        errorType: SignupErrorType.network,
      );
    } catch (_) {
      return const SignupResult(
        success: false,
        message: 'Something went wrong. Please try again.',
        errorType: SignupErrorType.unknown,
      );
    }
  }
}
