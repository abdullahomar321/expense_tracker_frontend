import 'package:expense_tracker/api_calls/api_config.dart';
import 'package:expense_tracker/api_calls/api_headers.dart';
import 'package:expense_tracker/api_calls/api_response_parser.dart';
import 'package:http/http.dart' as http;

class UserProfileResult {
  const UserProfileResult({
    required this.success,
    this.userId,
    this.name,
    this.email,
    this.photoUrl,
    this.balance = 0,
  });

  final bool success;
  final String? userId;
  final String? name;
  final String? email;
  final String? photoUrl;
  final double balance;
}

class UserApi {
  static const _requestTimeout = Duration(seconds: 15);

  static Future<UserProfileResult> getCurrentUser() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/api/user'),
            headers: await ApiHeaders.authorizedJson(),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 401 || response.statusCode == 403) {
        return const UserProfileResult(success: false);
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = ApiResponseParser.decodeBody(response.body);
        final user = body.containsKey('user')
            ? _readMap(body['user'])
            : body;

        return UserProfileResult(
          success: true,
          userId: _readString(user['id']?.toString()),
          name: _readString(user['name']),
          email: _readString(user['email']),
          photoUrl: _readString(user['photo_url'] ?? user['avatar']),
          balance: ApiResponseParser.readBalance(user),
        );
      }

      return const UserProfileResult(success: false);
    } catch (_) {
      return const UserProfileResult(success: false);
    }
  }

  static Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return {};
  }

  static String? _readString(dynamic value) {
    if (value is String && value.isNotEmpty) return value;
    return null;
  }
}
