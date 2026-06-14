import 'package:hive_flutter/hive_flutter.dart';

class PinService {
  static const String _boxName = 'settings';
  static const String _lastBackgroundKey = 'last_background_time';

  // In-memory flags to track app states
  static bool _pickerWasOpened = false;
  static bool _paymentInProgress = false;
  static String? _currentUserId;

  static Box get _box => Hive.box(_boxName);

  /// Set the current user ID (call this when user logs in)
  static void setCurrentUserId(String userId) {
    _currentUserId = userId;
  }

  /// Clear the current user ID (call this when user logs out)
  static void clearCurrentUserId() {
    _currentUserId = null;
  }

  /// Get the PIN key for the current user
  static String _getPinKeyForUser(String userId) {
    return 'pin_$userId';
  }

  /// Check if current user has PIN enabled
  static bool hasPin() {
    if (_currentUserId == null || _currentUserId!.isEmpty) return false;
    return _box.containsKey(_getPinKeyForUser(_currentUserId!));
  }

  /// Save PIN for current user
  static Future<void> savePin(String pin) async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    await _box.put(_getPinKeyForUser(_currentUserId!), pin);
  }

  /// Remove PIN for current user
  static Future<void> removePin() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    await _box.delete(_getPinKeyForUser(_currentUserId!));
  }

  /// Verify PIN for current user
  static bool verifyPin(String pin) {
    if (_currentUserId == null || _currentUserId!.isEmpty) return false;
    return _box.get(_getPinKeyForUser(_currentUserId!)) == pin;
  }

  /// Mark that the image picker (gallery/camera) was opened.
  /// This prevents PIN prompts from gallery/camera access.
  static void markPickerOpened() {
    _pickerWasOpened = true;
  }

  /// Reset the picker flag after checking.
  static void resetPickerFlag() {
    _pickerWasOpened = false;
  }

  /// Mark that payment/subscription flow is in progress.
  /// This prevents PIN prompts during payment processing.
  static void markPaymentInProgress() {
    _paymentInProgress = true;
  }

  /// Reset the payment flag when flow completes or cancels.
  static void resetPaymentFlag() {
    _paymentInProgress = false;
  }

  static Future<void> recordBackgroundTime() async {
    await _box.put(_lastBackgroundKey, DateTime.now().millisecondsSinceEpoch);
  }

  static bool shouldPromptPin() {
    // Check if current user exists and has PIN enabled
    if (_currentUserId == null || _currentUserId!.isEmpty || !hasPin()) {
      return false;
    }

    // If payment is in progress, skip PIN
    if (_paymentInProgress) {
      return false;
    }

    // If picker was opened, skip PIN (it's just gallery/camera access)
    if (_pickerWasOpened) {
      resetPickerFlag();
      return false;
    }

    final lastTime = _box.get(_lastBackgroundKey) as int?;
    if (lastTime == null) return false; // No background time recorded

    final lastDate = DateTime.fromMillisecondsSinceEpoch(lastTime);
    final diff = DateTime.now().difference(lastDate);
    
    // Clear the timestamp so we don't keep prompting unless put in background again
    _box.delete(_lastBackgroundKey);
    
    return diff.inMinutes >= 5;
  }
}
