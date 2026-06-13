import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:expense_tracker/UI/app_startup.dart';
import 'package:expense_tracker/providers/splash_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/api_calls/stripe_config.dart';
import 'package:expense_tracker/api_calls/payment_api.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Stripe with publishable key from config
  Stripe.publishableKey = StripeConfig.publishableKey;

  // Optionally fetch the latest publishable key from backend
  // This is useful if you rotate keys on the server
  _fetchStripeKey();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => SplashProvider()..startTimer(),
        ),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const Expensetracker(),
    ),
  );
}

Future<void> _fetchStripeKey() async {
  try {
    final response = await PaymentApi.getStripeKey();
    if (response['success']) {
      Stripe.publishableKey = response['publishableKey'];
    }
  } catch (e) {
    // Use fallback key from config
    print('Using default Stripe key');
  }
}

class Expensetracker extends StatelessWidget {
  const Expensetracker({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const AppStartup(),
    );
  }
}
