import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStore {
  static const _key = 'auth_token';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: _key, value: token);

    // Remove the legacy copy after a successful secure write.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Future<String?> getToken() async {
    final secureToken = await _secureStorage.read(key: _key);
    if (secureToken != null && secureToken.isNotEmpty) {
      return secureToken;
    }

    // One-time migration path for users upgrading from SharedPreferences storage.
    final prefs = await SharedPreferences.getInstance();
    final legacyToken = prefs.getString(_key);
    if (legacyToken == null || legacyToken.isEmpty) {
      return null;
    }

    await _secureStorage.write(key: _key, value: legacyToken);
    await prefs.remove(_key);
    return legacyToken;
  }

  Future<void> clear() async {
    await _secureStorage.delete(key: _key);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
