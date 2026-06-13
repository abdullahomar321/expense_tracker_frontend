import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStorage {
  SecureTokenStorage._();

  static const _tokenKey = 'sanctum_token';
  static const _geminiKey = 'gemini_api_key';
  static String? _memoryToken;
  static String? _memoryGeminiKey;

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static File get _fallbackFile {
    return File('${Directory.systemTemp.path}/.expense_tracker_token');
  }

  static Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
    } catch (_) {
      _memoryToken = token;
      try {
        await _fallbackFile.writeAsString(token);
      } catch (_) {}
    }
  }

  static Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (_) {
      if (_memoryToken != null) return _memoryToken;
      try {
        final file = _fallbackFile;
        if (await file.exists()) {
          final content = await file.readAsString();
          return content.trim();
        }
      } catch (_) {}
      return null;
    }
  }

  static Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> saveGeminiKey(String key) async {
    try {
      await _storage.write(key: _geminiKey, value: key);
    } catch (_) {
      _memoryGeminiKey = key;
      try {
        await _fallbackFile.parent.create(recursive: true);
        final geminiFile = File('${Directory.systemTemp.path}/.expense_tracker_gemini_key');
        await geminiFile.writeAsString(key);
      } catch (_) {}
    }
  }

  static Future<String?> getGeminiKey() async {
    try {
      return await _storage.read(key: _geminiKey);
    } catch (_) {
      if (_memoryGeminiKey != null) return _memoryGeminiKey;
      try {
        final geminiFile = File('${Directory.systemTemp.path}/.expense_tracker_gemini_key');
        if (await geminiFile.exists()) {
          final content = await geminiFile.readAsString();
          return content.trim();
        }
      } catch (_) {}
      return null;
    }
  }

  static Future<bool> hasGeminiKey() async {
    final key = await getGeminiKey();
    return key != null && key.isNotEmpty;
  }

  static Future<void> deleteGeminiKey() async {
    try {
      await _storage.delete(key: _geminiKey);
    } catch (_) {
      _memoryGeminiKey = null;
      try {
        final geminiFile = File('${Directory.systemTemp.path}/.expense_tracker_gemini_key');
        if (await geminiFile.exists()) {
          await geminiFile.delete();
        }
      } catch (_) {}
    }
  }

  static Future<void> deleteToken() async {
    try {
      await _storage.delete(key: _tokenKey);
    } catch (_) {
      _memoryToken = null;
      try {
        final file = _fallbackFile;
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
  }
}
