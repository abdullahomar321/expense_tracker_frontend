import 'dart:async';
import 'package:flutter/material.dart';

class SplashProvider extends ChangeNotifier {
  bool _isFinished = false;

  bool get isFinished => _isFinished;

  /// Starts the 3-second timer and sets isFinished to true once completed.
  void startTimer() {
    Timer(const Duration(seconds: 3), () {
      _isFinished = true;
      notifyListeners();
    });
  }
}
