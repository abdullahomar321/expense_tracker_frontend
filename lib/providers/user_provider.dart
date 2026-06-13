import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  String _name = '';
  String _email = '';
  double _balance = 0;
  double _totalIncome = 0;
  double _spent = 0;
  bool _isLoggedIn = false;
  bool _isPremium = false;

  String get name => _name;
  String get email => _email;
  double get balance => _balance;
  double get totalIncome => _totalIncome;
  double get spent => _spent;
  bool get isLoggedIn => _isLoggedIn;
  bool get isPremium => _isPremium;

  void setUserFromLogin({
    required String name,
    required String email,
    required double totalIncome,
    bool? isPremium,
  }) {
    _name = name;
    _email = email;
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
    _name = '';
    _email = '';
    _balance = 0;
    _totalIncome = 0;
    _spent = 0;
    _isLoggedIn = false;
    _isPremium = false;
    notifyListeners();
  }
}
