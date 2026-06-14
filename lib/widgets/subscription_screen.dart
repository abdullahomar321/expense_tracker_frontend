import 'dart:async';
import 'package:expense_tracker/api_calls/payment_api.dart';
import 'package:expense_tracker/api_calls/premium_api.dart';
import 'package:expense_tracker/api_calls/stripe_config.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/services/secure_token_storage.dart';
import 'package:expense_tracker/services/pin_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  // Hardcoded controllers for visual representation
  final _cardHolderController = TextEditingController(text: 'John Doe');
  final _cardNumberController = TextEditingController(text: '5555 5555 5555 4444');
  final _expiryController = TextEditingController(text: '12/30');
  final _cvvController = TextEditingController(text: '123');
  final _postalCodeController = TextEditingController(text: '90210');

  bool _isLoading = false;
  String? _errorMessage;

  static const _accent = Color(0xFF10B981);
  static const _title = Color(0xFF0F172A);
  static const _subtle = Color(0xFF64748B);
  static const _surface = Color(0xFFF8FAFC);
  static const _border = BorderSide(color: Color(0xFFE2E8F0));

  @override
  void initState() {
    super.initState();
    Stripe.instance.applySettings();
  }

  @override
  void dispose() {
    _cardHolderController.dispose();
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _postalCodeController.dispose();
    PinService.resetPaymentFlag();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: _accent),
      filled: true,
      fillColor: _surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: _border),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: _border),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _accent, width: 2),
      ),
    );
  }

  bool _validateCard() {
    setState(() => _errorMessage = null);
    if (_cardHolderController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter cardholder name');
      return false;
    }
    if (_postalCodeController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please enter postal code');
      return false;
    }
    return true;
  }

  Future<void> _processPayment() async {
    FocusScope.of(context).unfocus();
    if (!_validateCard()) return;

    setState(() => _isLoading = true);
    PinService.markPaymentInProgress();

    try {
      // Step 1: Create Payment Intent
      final createResponse = await PaymentApi.createPaymentIntent(
        amount: StripeConfig.amountInCents,
        currency: StripeConfig.currency,
      );

      if (!mounted) return;

      if (createResponse['success'] != true) {
        setState(() {
          _isLoading = false;
          _errorMessage = createResponse['message'] ?? 'Unable to start payment';
        });
        PinService.resetPaymentFlag();
        return;
      }

      final clientSecret = (createResponse['clientSecret'] ?? '').toString();
      final paymentIntentId = (createResponse['paymentIntentId'] ?? '').toString();

      if (clientSecret.isEmpty || paymentIntentId.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Payment setup failed. Please try again.';
        });
        PinService.resetPaymentFlag();
        return;
      }

      // Step 2: Use Stripe's explicit bypass logic to hardcode card details safely
      await Stripe.instance.dangerouslyUpdateCardDetails(
         CardDetails(
          number: '5555555555554444',
          cvc: '123',
          expirationMonth: 12,
          expirationYear: 30,
        ),
      );

      // Step 2b: Create a payment method pointing back to our updated card token layout
      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(
              name: _cardHolderController.text.trim(),
              address: Address(
                postalCode: _postalCodeController.text.trim(),
                city: null, country: null, line1: null, line2: null, state: null,
              ),
            ),
          ),
        ),
      );

      // Step 3: Confirm with backend
      final confirmResponse = await PaymentApi.confirmPayment(
        paymentIntentId: paymentIntentId,
      );

      if (!mounted) {
        PinService.resetPaymentFlag();
        return;
      }

      // Step 4: Check success
      if (confirmResponse['success'] == true) {
        final isPremium = confirmResponse['isPremium'] == true ||
            confirmResponse['is_premium'] == true ||
            confirmResponse['is_premium'] == 'true' ||
            confirmResponse['data']?['is_premium'] == true;

        if (isPremium) {
          await _verifyPremiumAndNavigate();
          return;
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = confirmResponse['message'] ??
                'Payment successful but premium not activated. Please contact support.';
          });
          PinService.resetPaymentFlag();
          return;
        }
      }

      setState(() {
        _isLoading = false;
        _errorMessage = confirmResponse['message'] ?? 'Payment confirmation failed';
      });
      PinService.resetPaymentFlag();
    } on StripeException catch (error) {
      if (!mounted) {
        PinService.resetPaymentFlag();
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.error.localizedMessage ?? 'Payment failed';
      });
      PinService.resetPaymentFlag();
    } catch (error) {
      if (!mounted) {
        PinService.resetPaymentFlag();
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
      PinService.resetPaymentFlag();
    }
  }

  Future<bool> _verifyPremiumAndNavigate() async {
    try {
      // Add 15-second timeout to prevent stuck loading
      final apiKey = await PremiumApi.getGeminiApiKey()
          .timeout(const Duration(seconds: 15));
      if (apiKey != null && apiKey.isNotEmpty) {
        await SecureTokenStorage.saveGeminiKey(apiKey);
      }

      final premiumStatus = await PremiumApi.getPremiumStatus()
          .timeout(const Duration(seconds: 15));

      if (!mounted) {
        PinService.resetPaymentFlag();
        return false;
      }

      if (!(premiumStatus.success && premiumStatus.isPremium)) {
        setState(() {
          _isLoading = false;
          _errorMessage = premiumStatus.message.isNotEmpty
              ? premiumStatus.message
              : 'Premium access could not be verified';
        });
        PinService.resetPaymentFlag();
        return false;
      }

      context.read<UserProvider>().setPremium(true);

      if (mounted) {
        PinService.resetPaymentFlag();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 Welcome to Premium! AI ChatBot unlocked.'),
            backgroundColor: _accent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.of(context).pop(true);
      }
      return true;
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Verification timeout. Please try again or check your connection.';
        });
      }
      PinService.resetPaymentFlag();
      return false;
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error verifying premium: $e';
        });
      }
      PinService.resetPaymentFlag();
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new, color: _accent),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Upgrade to Premium',
          style: TextStyle(color: _title, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'AI ChatBot',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Unlock AI-powered expense insights',
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      '\$4.99/month',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Error Message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

            // Payment form
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    spreadRadius: 2,
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Card Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _title),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Review your mockup payment details below',
                    style: TextStyle(fontSize: 13, color: _subtle),
                  ),
                  const SizedBox(height: 20),

                  // Cardholder name
                  TextField(
                    controller: _cardHolderController,
                    enabled: !_isLoading,
                    decoration: _fieldDecoration(
                      label: 'Cardholder Name',
                      hint: 'John Doe',
                      icon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card number (Visual mockup)
                  TextField(
                    controller: _cardNumberController,
                    enabled: false,
                    decoration: _fieldDecoration(
                      label: 'Card Number',
                      hint: 'XXXX XXXX XXXX XXXX',
                      icon: Icons.credit_card,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Expiry and CVV inline (Visual mockup)
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _expiryController,
                          enabled: false,
                          decoration: _fieldDecoration(
                            label: 'Expiry Date',
                            hint: 'MM/YY',
                            icon: Icons.calendar_today,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _cvvController,
                          enabled: false,
                          decoration: _fieldDecoration(
                            label: 'CVV',
                            hint: '123',
                            icon: Icons.lock_open_outlined,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Postal Code
                  TextField(
                    controller: _postalCodeController,
                    enabled: !_isLoading,
                    decoration: _fieldDecoration(
                      label: 'Postal Code',
                      hint: '12345',
                      icon: Icons.location_on_outlined,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Security badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFFCF6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD1FAE5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lock_outline, color: _accent, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Your payment is secured with Stripe encryption',
                      style: TextStyle(fontSize: 12, color: Color(0xFF047857)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Subscribe button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : const Text(
                  'Subscribe Now',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}