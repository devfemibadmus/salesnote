import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  static const _key = 'auth_token';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const Duration _storageTimeout = Duration(seconds: 3);

  Future<void> saveToken(String token) async {
    await _secureStorage
        .write(key: _key, value: token)
        .timeout(_storageTimeout);

    // Remove the legacy copy after a successful secure write.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<String?> getToken() async {
    try {
      final secureToken = await _secureStorage
          .read(key: _key)
          .timeout(_storageTimeout);
      if (secureToken != null && secureToken.isNotEmpty) {
        return secureToken;
      }
    } catch (_) {
      try {
        await _secureStorage.delete(key: _key).timeout(_storageTimeout);
      } catch (_) {}
    }

    // One-time migration path for users upgrading from SharedPreferences storage.
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_key);
    if (legacyToken == null || legacyToken.isEmpty) {
      return null;
    }

    try {
      await _secureStorage
          .write(key: _key, value: legacyToken)
          .timeout(_storageTimeout);
    } catch (_) {
      return null;
    }
    await prefs.remove(_key);
    return legacyToken;
  }

  Future<void> clear() async {
    try {
      await _secureStorage.delete(key: _key).timeout(_storageTimeout);
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
