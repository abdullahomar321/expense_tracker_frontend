import 'package:expense_tracker/api_calls/expense_api.dart';
import 'package:expense_tracker/api_calls/login_api.dart';
import 'package:expense_tracker/api_calls/logout_api.dart';
import 'package:expense_tracker/api_calls/premium_api.dart';
import 'package:expense_tracker/api_calls/user_api.dart';
import 'package:expense_tracker/providers/user_provider.dart';
import 'package:expense_tracker/services/secure_token_storage.dart';

class AuthService {
  static Future<void> saveSession(LoginResult result) async {
    final token = result.token;
    if (token == null || token.isEmpty) {
      throw const AuthException('No authentication token received from server.');
    }

    await SecureTokenStorage.saveToken(token);
  }

  static Future<void> clearSession() async {
    // Always delete local token — server revocation is best-effort
    await LogoutApi.logout(); // revokes Sanctum token server-side
    await SecureTokenStorage.deleteToken();
    await SecureTokenStorage.deleteGeminiKey();
  }

  static Future<bool> restoreSession(UserProvider userProvider) async {
    final hasToken = await SecureTokenStorage.hasToken();
    if (!hasToken) return false;

    final token = await SecureTokenStorage.getToken();
    if (token == null || token.isEmpty) return false;

    final results = await Future.wait([
      UserApi.getCurrentUser(),
      PremiumApi.getPremiumStatus(),
      ExpenseApi.fetchExpenses(token: token),
    ]);

    final profile = results[0] as UserProfileResult;
    final premiumStatus = results[1] as PremiumStatusResult;
    final expenseData = results[2] as Map<String, dynamic>;

    if (!profile.success) {
      await SecureTokenStorage.deleteToken();
      return false;
    }

    final isPremium = premiumStatus.success && premiumStatus.isPremium;

    // If premium, try to fetch and save the Gemini API key if not already stored
    if (isPremium) {
      final hasStoredKey = await SecureTokenStorage.hasGeminiKey();
      if (!hasStoredKey) {
        final apiKey = await PremiumApi.getGeminiApiKey();
        if (apiKey != null && apiKey.isNotEmpty) {
          await SecureTokenStorage.saveGeminiKey(apiKey);
        }
      }
    }

    userProvider.setUserFromLogin(
      name: profile.name ?? 'User',
      email: profile.email ?? '',
      totalIncome: profile.balance,
      isPremium: isPremium,
    );

    if (expenseData['success'] == true) {
      final expensesList = expenseData['expenses'] as List<dynamic>? ?? [];
      double totalSpent = 0;
      for (final expense in expensesList) {
        final amount = expense['amount'];
        if (amount is num) {
          totalSpent += amount.toDouble();
        } else if (amount is String) {
          totalSpent += double.tryParse(amount) ?? 0;
        }
      }
      userProvider.updateSpent(totalSpent);

      final balance = expenseData['balance'];
      if (balance != null) {
        double parsedBalance = profile.balance;
        if (balance is num) {
          parsedBalance = balance.toDouble();
        } else if (balance is String) {
          parsedBalance = double.tryParse(balance) ?? profile.balance;
        }
        userProvider.updateBalance(parsedBalance);
      }
    }

    return true;
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
