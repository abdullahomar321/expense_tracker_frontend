import 'package:hive_flutter/hive_flutter.dart';

class PinService {
  static const String _boxName = 'settings';
  static const String _pinKey = 'user_pin';
  static const String _lastBackgroundKey = 'last_background_time';

  static Box get _box => Hive.box(_boxName);

  static bool hasPin() {
    return _box.containsKey(_pinKey);
  }

  static Future<void> savePin(String pin) async {
    await _box.put(_pinKey, pin);
  }

  static Future<void> removePin() async {
    await _box.delete(_pinKey);
  }

  static bool verifyPin(String pin) {
    return _box.get(_pinKey) == pin;
  }

  static Future<void> recordBackgroundTime() async {
    await _box.put(_lastBackgroundKey, DateTime.now().millisecondsSinceEpoch);
  }

  static bool shouldPromptPin() {
    if (!hasPin()) return false;
    
    final lastTime = _box.get(_lastBackgroundKey) as int?;
    if (lastTime == null) return true; // Cold start

    final lastDate = DateTime.fromMillisecondsSinceEpoch(lastTime);
    final diff = DateTime.now().difference(lastDate);
    
    // Clear the timestamp so we don't keep prompting unless put in background again
    _box.delete(_lastBackgroundKey);
    
    return diff.inMinutes >= 5;
  }
}
