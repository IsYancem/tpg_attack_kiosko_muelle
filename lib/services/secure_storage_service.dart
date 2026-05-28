import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';

class SecureStorageService {
  SecureStorageService._();

  static final _storage = const FlutterSecureStorage();
  static const _tag = 'SecureStorageService';

  /* ─── Claves únicas y coherentes ─── */
  static const _tokenKey = 'accessToken';
  static const _refreshTokenKey = 'refreshToken';
  static const _usernameKey = '_usernameKey';

  /* ───────────────── Auth helpers ───────────────── */

  static Future<void> saveAuthData({
    required String token,
    required String refreshToken,
    required String username
  }) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _refreshTokenKey, value: refreshToken);
      await _storage.write(key: _usernameKey, value: username);

      LogService.instance.logRequest('$_tag.saveAuthData', {
        'saved': true,
        'username': username,
      });
    } catch (e, st) {
      LogService.instance.logError('$_tag.saveAuthData', e, st);
      rethrow;
    }
  }

  static Future<String?> getToken() => _readKey(_tokenKey, 'getToken');
  static Future<String?> getRefreshToken() =>
      _readKey(_refreshTokenKey, 'getRefreshToken');

  static Future<void> clearAuthData() async {
    try {
      await Future.wait([
        _storage.delete(key: _tokenKey),
        _storage.delete(key: _refreshTokenKey),
        _storage.delete(key: _usernameKey),
      ]);
      LogService.instance.logRequest('$_tag.clearAuthData', {'cleared': true});
    } catch (e, st) {
      LogService.instance.logError('$_tag.clearAuthData', e, st);
    }
  }

  /* ───────────────── Genéricos ───────────────── */

  static Future<void> save(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      LogService.instance.logRequest('$_tag.save', {
        'key': key,
        'length': value.length,
      });
    } catch (e, st) {
      LogService.instance.logError('$_tag.save', e, st);
      rethrow;
    }
  }

  static Future<String?> read(String key) => _readKey(key, 'read');

  /* ───────────────── Privado ───────────────── */

  static Future<String?> _readKey(String key, String method) async {
    try {
      final value = await _storage.read(key: key);
      value == null
          ? LogService.instance.logWarning('$_tag.$method', {
            'key': key,
            'value': 'null',
          })
          : LogService.instance.logRequest('$_tag.$method', {
            'key': key,
            'length': value.length,
          });
      return value;
    } catch (e, st) {
      LogService.instance.logError('$_tag.$method', e, st);
      rethrow;
    }
  }
}
