import 'package:expense_tracker/UI/dashboard.dart';
import 'package:expense_tracker/UI/logo.dart';
import 'package:expense_tracker/UI/options.dart';
import 'package:expense_tracker/providers/splash_provider.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppStartup extends StatefulWidget {
  const AppStartup({super.key});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  Future<bool>? _sessionFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sessionFuture ??= AuthService.restoreSession(context.read<UserProvider>());
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SplashProvider>(
      builder: (context, splashProvider, child) {
        if (!splashProvider.isFinished) {
          return const Logo();
        }

        return FutureBuilder<bool>(
          future: _sessionFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF10B981),
                  ),
                ),
              );
            }

            if (snapshot.data == true) {
              return const Dashboard();
            }

            return const Options();
          },
        );
      },
    );
  }
}
