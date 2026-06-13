import 'package:expense_tracker/api_calls/api_config.dart';
import 'package:expense_tracker/api_calls/api_headers.dart';
import 'package:expense_tracker/api_calls/api_response_parser.dart';
import 'package:http/http.dart' as http;

class PremiumStatusResult {
  const PremiumStatusResult({
    required this.success,
    required this.isPremium,
    this.message = '',
    this.statusCode,
  });

  final bool success;
  final bool isPremium;
  final String message;
  final int? statusCode;
}

class PremiumApi {
  static const _requestTimeout = Duration(seconds: 15);

  static Future<String?> getGeminiApiKey() async {
    try {
      final response = await http
          .get(
        Uri.parse('${ApiConfig.baseUrl}/api/payments/gemini-api-key'),
        headers: await ApiHeaders.authorizedJson(),
      )
          .timeout(_requestTimeout);

      final body = ApiResponseParser.decodeBody(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final data = body['data'] is Map<String, dynamic>
            ? body['data'] as Map<String, dynamic>
            : body['data'] is Map
            ? Map<String, dynamic>.from(body['data'])
            : <String, dynamic>{};

        return data['gemini_api_key']?.toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<PremiumStatusResult> getPremiumStatus() async {

    try {
      final response = await http
          .get(
        // Fixed: was /api/premium-status
        Uri.parse('${ApiConfig.baseUrl}/api/payments/premium-status'),
        headers: await ApiHeaders.authorizedJson(),
      )
          .timeout(_requestTimeout);

      final body = ApiResponseParser.decodeBody(response.body);

      if (response.statusCode == 200) {
        final data = body['data'] is Map<String, dynamic>
            ? body['data'] as Map<String, dynamic>
            : body['data'] is Map
            ? Map<String, dynamic>.from(body['data'])
            : <String, dynamic>{};
         print('Premium Status Response: $data["is_premium"]');
        // 1. Inspect the runtime data type dynamically
        final rawPremiumData = data['is_premium'];
        bool premiumActive = false;

        if (rawPremiumData is bool) {
          // If the backend returns a flat boolean value: true / false
          premiumActive = rawPremiumData;
        } else if (rawPremiumData is Map) {
          // If the backend returns a nested object/map layout structure
          premiumActive = rawPremiumData['is_premium'] == true;
        }

// 2. Return your structured result safely
        return PremiumStatusResult(
          success: body['success'] == true || data['success'] == true,
          isPremium: premiumActive,
          message: ApiResponseParser.readMessage(
            data,
            fallback: premiumActive ? 'Premium active' : 'Premium inactive',
          ),
          statusCode: response.statusCode,
        );
      }

      return PremiumStatusResult(
        success: false,
        isPremium: false,
        message: ApiResponseParser.readError(
          body,
          fallback: 'Failed to fetch premium status',
        ),
        statusCode: response.statusCode,
      );
    } catch (error) {
       print('Error fetching premium status: $error');
      return const PremiumStatusResult(
        success: false,
        isPremium: false,
        message: 'Unable to fetch premium status',
      );
    }
  }
}