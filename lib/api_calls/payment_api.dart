import 'dart:convert';
import 'package:expense_tracker/api_calls/api_config.dart';
import 'package:expense_tracker/api_calls/api_headers.dart';
import 'package:expense_tracker/api_calls/api_response_parser.dart';
import 'package:http/http.dart' as http;

class PaymentApi {
  static const _requestTimeout = Duration(seconds: 30);

  static Future<Map<String, dynamic>> getStripeKey() async {
    final url = Uri.parse('${ApiConfig.baseUrl}/api/stripe-key');

    try {
      final response = await http
          .get(url, headers: ApiHeaders.json())
          .timeout(_requestTimeout);

      final data = ApiResponseParser.decodeBody(response.body);
          print('Stripe Key Response: $data'); // Debug log
      if (response.statusCode == 200) {
        return {
          'success': true,
          'publishableKey': data['publishable_key'],
        };
      }

      return {
        'success': false,
        'message': ApiResponseParser.readError(
          data,
          fallback: 'Failed to get Stripe key',
        ),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> createPaymentIntent({
    required int amount,
    String currency = 'usd',
  }) async {
    // Fixed: was /api/create-payment-intent
    final url = Uri.parse('${ApiConfig.baseUrl}/api/payments/create-intent');

    try {
      final response = await http

          .post(
        url,
        headers: await ApiHeaders.authorizedJson(),
        body: jsonEncode({
          'amount': amount,
          'currency': currency,
        }),
      )
          .timeout(_requestTimeout);


      final data = ApiResponseParser.decodeBody(response.body);
        print('Create Payment Intent Response: $data'); // Debug log
      if (response.statusCode == 200) {
        return {
          'success': true,
          'clientSecret': data['client_secret'],
          'paymentIntentId': data['payment_intent_id'],
          'amount': data['amount'],
          'currency': data['currency'],
        };
      }

      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': ApiResponseParser.readError(
          data,
          fallback: 'Failed to create payment intent',
        ),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> confirmPayment({
    required String paymentIntentId,
  }) async {
    // Fixed: was /api/confirm-payment
    final url = Uri.parse('${ApiConfig.baseUrl}/api/payments/confirm');

    try {
      final response = await http
          .post(
        url,
        headers: await ApiHeaders.authorizedJson(),
        body: jsonEncode({
          'payment_intent_id': paymentIntentId,
        }),
      )
          .timeout(_requestTimeout);

      final data = ApiResponseParser.decodeBody(response.body);
      print('Create Confirm Payment Response: $data');
      if (response.statusCode == 200) {
        return {
          'success': true,
          'status': data['status'],
          'amount': data['amount'],
          'currency': data['currency'],
          'isPremium': data['is_premium'] == true,
          'message': data['message'],
        };
      }

      return {
        'success': false,
        'statusCode': response.statusCode,
        'message': ApiResponseParser.readError(
          data,
          fallback: 'Failed to confirm payment',
        ),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Connection error: $e',
      };
    }
  }
}