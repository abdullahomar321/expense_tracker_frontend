import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:expense_tracker/UI/app_startup.dart';
import 'package:expense_tracker/providers/splash_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/api_calls/stripe_config.dart';
import 'package:expense_tracker/api_calls/payment_api.dart';
import 'package:expense_tracker/services/pin_service.dart';
import 'package:expense_tracker/widgets/pin_auth_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('settings');
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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

class Expensetracker extends StatefulWidget {
  const Expensetracker({super.key});

  @override
  State<Expensetracker> createState() => _ExpensetrackerState();
}

class _ExpensetrackerState extends State<Expensetracker> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      PinService.recordBackgroundTime();
    } else if (state == AppLifecycleState.resumed) {
      if (PinService.shouldPromptPin()) {
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => const PinAuthScreen(mode: PinAuthMode.verify),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      home: const AppStartup(),
    );
  }
}
