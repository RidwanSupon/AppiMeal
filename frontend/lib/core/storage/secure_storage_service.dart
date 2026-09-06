import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // In-memory fallback in case KeyStore throws on legacy/custom ROM devices
  static final Map<String, String> _memCache = {};

  static const String _keyToken = 'auth_token';
  static const String _keyRole = 'user_role';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserName = 'user_name';
  static const String _keyServerUrl = 'server_url';

  Future<void> _write(String key, String value) async {
    _memCache[key] = value;
    try {
      await _storage.write(key: key, value: value);
    } catch (_) {}
  }

  Future<String?> _read(String key) async {
    try {
      final val = await _storage.read(key: key);
      if (val != null) {
        _memCache[key] = val;
        return val;
      }
    } catch (_) {}
    return _memCache[key];
  }

  Future<void> saveServerUrl(String url) async {
    await _write(_keyServerUrl, url);
  }

  Future<String?> getServerUrl() async {
    return await _read(_keyServerUrl);
  }

  Future<void> saveAuthData({
    required String token,
    required String role,
    required String email,
    required String name,
  }) async {
    await _write(_keyToken, token);
    await _write(_keyRole, role);
    await _write(_keyUserEmail, email);
    await _write(_keyUserName, name);
  }

  Future<String?> getToken() async {
    return await _read(_keyToken);
  }

  Future<String?> getRole() async {
    return await _read(_keyRole);
  }

  Future<String?> getUserEmail() async {
    return await _read(_keyUserEmail);
  }

  Future<String?> getUserName() async {
    return await _read(_keyUserName);
  }

  Future<void> clearAuthData() async {
    final serverUrl = await getServerUrl();
    _memCache.remove(_keyToken);
    _memCache.remove(_keyRole);
    _memCache.remove(_keyUserEmail);
    _memCache.remove(_keyUserName);
    try {
      await _storage.deleteAll();
    } catch (_) {}
    if (serverUrl != null) {
      await saveServerUrl(serverUrl);
    }
  }
}
