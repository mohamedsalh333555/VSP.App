import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'logger_service.dart';

class SecureStorageService {
  static const _authTokenKey = 'vsp_auth_token';
  static const _refreshTokenKey = 'vsp_refresh_token';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static Future<void> saveAuthToken(String token) async {
    try {
      await _storage.write(key: _authTokenKey, value: token);
    } catch (e) {
      VSPLogger.w('Failed to write secure token: $e');
    }
  }

  static Future<String?> getAuthToken() async {
    try {
      return await _storage.read(key: _authTokenKey);
    } catch (e) {
      VSPLogger.w('Failed to read secure token: $e');
      return null;
    }
  }

  static Future<void> saveRefreshToken(String token) async {
    try {
      await _storage.write(key: _refreshTokenKey, value: token);
    } catch (e) {
      VSPLogger.w('Failed to write refresh token: $e');
    }
  }

  static Future<void> writeSecure(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      VSPLogger.w('Failed to write secure key $key: $e');
    }
  }

  static Future<String?> readSecure(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      VSPLogger.w('Failed to read secure key $key: $e');
      return null;
    }
  }

  static Future<void> deleteSecure(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      VSPLogger.w('Failed to delete secure key $key: $e');
    }
  }

  static Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      VSPLogger.w('Failed to clear secure storage: $e');
    }
  }
}
