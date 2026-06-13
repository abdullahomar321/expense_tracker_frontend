import 'package:expense_tracker/api_calls/api_config.dart';
import 'package:expense_tracker/api_calls/api_headers.dart';
import 'package:http/http.dart' as http;

class LogoutResult {
  const LogoutResult({required this.success, this.message = ''});

  final bool success;
  final String message;
}

class LogoutApi {
  static const _requestTimeout = Duration(seconds: 15);

  /// Calls DELETE /api/logout to revoke the current Sanctum token.
  /// Returns [LogoutResult.success] = true as long as the local session
  /// should be cleared (including when the server returns 401, meaning
  /// the token was already expired or revoked).
  static Future<LogoutResult> logout() async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/api/logout'),
            headers: await ApiHeaders.authorizedJson(),
          )
          .timeout(_requestTimeout);

      // 200–204: token successfully revoked on server
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return const LogoutResult(success: true, message: 'Logged out successfully');
      }

      // 401: token was already expired/revoked — still clear locally
      if (response.statusCode == 401) {
        return const LogoutResult(success: true, message: 'Session already expired');
      }

      return LogoutResult(
        success: false,
        message: 'Server error during logout (${response.statusCode})',
      );
    } on http.ClientException {
      // Network failure — still clear locally so user is not stuck
      return const LogoutResult(
        success: true,
        message: 'Logged out (offline)',
      );
    } catch (_) {
      return const LogoutResult(
        success: true,
        message: 'Logged out',
      );
    }
  }
}
