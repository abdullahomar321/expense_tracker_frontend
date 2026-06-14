import 'package:flutter/material.dart';
import 'package:expense_tracker/services/pin_service.dart';

class UserProvider extends ChangeNotifier {
  String _userId = '';
  String _name = '';
  String _email = '';
  String _photoUrl = '';
  double _balance = 0;
  double _totalIncome = 0;
  double _spent = 0;
  bool _isLoggedIn = false;
  bool _isPremium = false;

  String get userId => _userId;
  String get name => _name;
  String get email => _email;
  String get photoUrl => _photoUrl;
  double get balance => _balance;
  double get totalIncome => _totalIncome;
  double get spent => _spent;
  bool get isLoggedIn => _isLoggedIn;
  bool get isPremium => _isPremium;

  void setUserFromLogin({
    required String name,
    required String email,
    required double totalIncome,
    String? userId,
    String? photoUrl,
    bool? isPremium,
  }) {
    if (userId != null && userId.isNotEmpty) {
      _userId = userId;
      // Set current user in PIN service for user-specific PIN handling
      PinService.setCurrentUserId(userId);
    }
    _name = name;
    _email = email;
    if (photoUrl != null) _photoUrl = photoUrl;
    _balance = totalIncome;
    _totalIncome = totalIncome;
    _spent = 0;
    _isLoggedIn = true;
    if (isPremium != null) {
      _isPremium = isPremium;
    }
    notifyListeners();
  }

  void updateBalance(double balance) {
    _balance = balance;
    notifyListeners();
  }

  void updateTotalIncome(double totalIncome) {
    _totalIncome = totalIncome;
    notifyListeners();
  }

  void updateSpent(double spent) {
    _spent = spent;
    notifyListeners();
  }

  void setPremium(bool isPremium) {
    _isPremium = isPremium;
    notifyListeners();
  }

  void logout() {
    // Clear current user from PIN service
    PinService.clearCurrentUserId();

    _userId = '';
    _name = '';
    _email = '';
    _photoUrl = '';
    _balance = 0;
    _totalIncome = 0;
    _spent = 0;
    _isLoggedIn = false;
    _isPremium = false;
    notifyListeners();
  }
}
