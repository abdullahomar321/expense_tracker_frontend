import 'dart:convert';
import 'package:expense_tracker/api_calls/api_config.dart';
import 'package:expense_tracker/api_calls/api_headers.dart';
import 'package:flutter/foundation.dart';
import 'package:expense_tracker/api_calls/api_response_parser.dart';
import 'package:http/http.dart' as http;

class GeminiChatResult {
  const GeminiChatResult({
    required this.success,
    required this.message,
    this.reply,
    this.statusCode,
  });

  final bool success;
  final String message;
  final String? reply;
  final int? statusCode;
}

class GeminiApi {
  static const _requestTimeout = Duration(seconds: 30);

  static Future<GeminiChatResult> sendMessage({
    required String message,
    required List<Map<String, dynamic>> expenses,
    required Map<String, dynamic> financialContext,
  }) async {
    try {
      final response = await http
          .post(
        Uri.parse('${ApiConfig.baseUrl}/api/ai/chat'),
        headers: await ApiHeaders.authorizedJson(),
        body: jsonEncode({
          'message': message,
          'expenses': expenses,
          'financial_context': financialContext,
        }),
      )
          .timeout(_requestTimeout);

      final body = ApiResponseParser.decodeBody(response.body);

      if (response.statusCode == 200) {
        final data = body['data'] is Map<String, dynamic>
            ? body['data'] as Map<String, dynamic>
            : body['data'] is Map
            ? Map<String, dynamic>.from(body['data'])
            : <String, dynamic>{};

        return GeminiChatResult(
          success: body['success'] == true,
          message: ApiResponseParser.readMessage(
            body,
            fallback: 'Gemini response generated successfully.',
          ),
          reply: data['reply']?.toString(),
          statusCode: response.statusCode,
        );
      }
      debugPrint('GeminiApi error one: ${response.statusCode}');
      debugPrint('$body');
      return GeminiChatResult(
        success: false,
        message: ApiResponseParser.readError(
          body,
          fallback: 'Failed to send message to assistant',
        ),
        statusCode: response.statusCode,
      );
    } catch (e,st) {
      debugPrint('GeminiApi error two: $e');
      debugPrint('$st');
      return const GeminiChatResult(
        success: false,
        message: 'Unable to contact AI assistant right now.',
      );
    }
  }
}
