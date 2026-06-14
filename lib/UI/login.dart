import 'package:expense_tracker/UI/dashboard.dart';
import 'package:expense_tracker/UI/forgot_password_screen.dart';
import 'package:expense_tracker/UI/signup.dart';
import 'package:expense_tracker/api_calls/expense_api.dart';
import 'package:expense_tracker/api_calls/login_api.dart';
import 'package:expense_tracker/api_calls/premium_api.dart';
import 'package:expense_tracker/api_calls/user_api.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/services/auth_service.dart';
import 'package:expense_tracker/services/firestore_sync_service.dart';
import 'package:expense_tracker/utils/auth_validators.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
              isError ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final email = AuthValidators.normalizeEmail(_emailController.text);
    final password = _passwordController.text;

    setState(() => _isLoading = true);

    final result = await LoginApi.login(
      email: email,
      password: password,
    );

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (!result.success) {
      if (result.errorType == LoginErrorType.userNotFound) {
        _showMessage('User does not exist', isError: true);
        return;
      }

      _showMessage(result.message, isError: true);
      return;
    }

    // Save the Sanctum token to secure storage
    try {
      await AuthService.saveSession(result);
    } catch (error) {
      _showMessage('Failed to save session: ${error.toString()}', isError: true);
      return;
    }

    if (!mounted) return;

    // If the login response included user data, use it directly.
    // Otherwise fetch the profile from /api/user asynchronously.
    final String userName = result.name ?? '';
    final String userEmail = result.email ?? email;
    final double userBalance = result.balance;

    // Set user provider immediately with whatever we have, or defaults
    context.read<UserProvider>().setUserFromLogin(
          name: userName.isNotEmpty ? userName : 'User',
          email: userEmail,
          totalIncome: userBalance,
          userId: result.userId,
          photoUrl: result.photoUrl ?? '',
          isPremium: false,
        );

    // Sync user profile to Firestore fire-and-forget (no UI block)
    if (result.userId != null && result.userId!.isNotEmpty) {
      FirestoreSyncService.syncUser(
        userId: result.userId!,
        displayName: userName.isNotEmpty ? userName : 'User',
        email: userEmail,
        photoUrl: result.photoUrl ?? '',
      );
    }

    // Navigate to dashboard immediately without blocking
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const Dashboard()),
    );

    // Fetch details in background - user profile and balance from expenses API
    Future.wait([
      if (userName.isEmpty)
        UserApi.getCurrentUser().catchError((_) => const UserProfileResult(success: false)),
      PremiumApi.getPremiumStatus().catchError((_) => const PremiumStatusResult(success: false, isPremium: false)),
      // Also fetch balance from expenses API for accurate data
      ExpenseApi.fetchExpenses(token: result.token!).catchError((_) => {'success': false}),
    ]).then((results) {
      if (!mounted) return;
      final userProvider = context.read<UserProvider>();

      // Update from user profile if available
      for (final result in results) {
        if (result is UserProfileResult && result.success) {
          userProvider.setUserFromLogin(
            name: result.name ?? 'User',
            email: result.email ?? userEmail,
            totalIncome: result.balance,
          );
        }
        if (result is PremiumStatusResult && result.success) {
          userProvider.setPremium(result.isPremium);
        }
        // Update balance and spent from expenses API
        if (result is Map && result['success'] == true) {
          final balance = result['balance'];
          if (balance != null) {
            double newBalance = 0;
            if (balance is num) {
              newBalance = balance.toDouble();
            } else if (balance is String) {
              newBalance = double.tryParse(balance) ?? 0;
            }
            userProvider.updateBalance(newBalance);
          }

          // Calculate total spent from expenses list
          final expensesList = result['expenses'] as List<dynamic>? ?? [];
          double totalSpent = 0;
          for (final expense in expensesList) {
            final amount = expense['amount'];
            if (amount != null) {
              if (amount is num) {
                totalSpent += amount.toDouble();
              } else if (amount is String) {
                totalSpent += double.tryParse(amount) ?? 0;
              }
            }
          }
          userProvider.updateSpent(totalSpent);

          // Try to get total income from server response
          final totalIncomeFromServer = result['total_income'] ?? result['totalIncome'];
          if (totalIncomeFromServer != null) {
            double parsedTotalIncome = 0;
            if (totalIncomeFromServer is num) {
              parsedTotalIncome = totalIncomeFromServer.toDouble();
            } else if (totalIncomeFromServer is String) {
              parsedTotalIncome = double.tryParse(totalIncomeFromServer) ?? 0;
            }
            userProvider.updateTotalIncome(parsedTotalIncome);
          } else {
            // Fallback: calculate from balance + spent
            double balanceVal = 0;
            final balance = result['balance'];
            if (balance is num) {
              balanceVal = balance.toDouble();
            } else if (balance is String) {
              balanceVal = double.tryParse(balance) ?? 0;
            }
            userProvider.updateTotalIncome(balanceVal + totalSpent);
          }
        }
      }
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF10B981), size: 23),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Center(
                  child: Icon(
                    Icons.login_rounded,
                    color: Color(0xFF10B981),
                    size: 100,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Welcome Back!',
                  style: TextStyle(
                    color: Color(0xFF1F2937),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to keep tracking your expenses',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'Email Address',
                  style: TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: AuthValidators.validateEmail,
                  style: const TextStyle(color: Color(0xFF1F2937)),
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF9CA3AF)),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Password',
                  style: TextStyle(
                    color: Color(0xFF374151),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  enabled: !_isLoading,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: AuthValidators.validatePassword,
                  onFieldSubmitted: (_) {
                    if (!_isLoading) _handleLogin();
                  },
                  style: const TextStyle(color: Color(0xFF1F2937)),
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF9CA3AF)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF9CA3AF),
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: _isLoading ? null : _handleLogin,
                  child: Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: _isLoading
                            ? [const Color(0xFF9CA3AF), const Color(0xFF9CA3AF)]
                            : const [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x5910B981),
                          blurRadius: 14,
                          spreadRadius: 1,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Log In',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: _isLoading
                            ? null
                            : () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => const Signup()),
                                );
                              },
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
