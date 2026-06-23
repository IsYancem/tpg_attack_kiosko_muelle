import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/secure_storage_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/env_utils.dart';

/// ------------------------------------------------------------
/// AuthApiService
/// ------------------------------------------------------------Mi funcion de
class AuthApiService {
  AuthApiService._();

  static final _client = LogService.instance.httpClient;
  static String get _baseUrl => dotenv.env['BASE_MIDDLEWARE_URL'] ?? '';

  /* =================== Login =================== */
  static Future<bool> login(String username) async {
    final uri = Uri.parse('${_baseUrl}ldap/tpg/by-username/$username');

    try {
      final res = await _client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      );

      if (res.statusCode == 200) {
        final userData = jsonDecode(res.body);

        final data = userData['data'];
        if (data == null) {
          // 🔴 Usuario no encontrado aunque la respuesta sea 200
          LogService.instance
              .logWarning('GET /ldap/tpg/by-username/$username', {
                'status': 200,
                'user': username,
                'msg': 'Usuario no encontrado (data=null)',
                'body': userData,
              });
          return false;
        }

        // ✅ Usuario encontrado correctamente
        LogService.instance.logRequest('GET /ldap/tpg/by-username/$username', {
          'status': 200,
          'user': username,
          'user_data': data,
        });

        return true;
      }

      LogService.instance.logWarning('GET /ldap/tpg/by-username/$username', {
        'status': res.statusCode,
        'body': res.body,
      });
      return false;
    } catch (e, st) {
      LogService.instance.logError(
        'GET /ldap/tpg/by-username/$username',
        e,
        st,
      );
      return false;
    }
  }

  /// Refresca *access* y *refresh* tokens usando el endpoint
  /// GET /auth/middleware/refresh (requiere enviar el refresh token
  /// en el header Authorization)
  static Future<bool> refresh(AppStateManager _appManager) async {
    // 1. Recuperar el refresh token sin borrarlo
    final refreshToken = _appManager.refreshToken;

    if (refreshToken == null) {
      LogService.instance.logWarning('AuthApiService.refresh', {
        'event': 'refresh_token_missing',
      });
      return false;
    }

    // 2. Construir la URI correcta
    final uri = Uri.parse('${_baseUrl}auth/middleware/refresh');
    LogService.instance.logRequest('ENTER GET /auth/middleware/refresh', {
      'withHeader': true,
    });

    try {
      // 3. Llamada GET con el refresh token
      final res = await _client.get(
        uri,
        headers: {
          'Authorization': 'Bearer $refreshToken',
          'Content-Type': 'application/json',
        },
      );

      // 4. Si es exitoso, parsear y persistir tokens
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;

        // Extraer datos
        final user = body['user'] as Map<String, dynamic>;
        final newAccess = body['accessToken'] as String?;
        final newRefresh = body['refreshToken'] as String?;

        // Persistir de forma atómica
        await _persistAuth(
          user,
          accessToken: newAccess,
          refreshToken: newRefresh,
        );

        LogService.instance.logRequest('EXIT GET /auth/middleware/refresh', {
          'status': 200,
        });
        return true;
      }

      // 5. Si falla (401, 500, etc.), limpiar credenciales
      await SecureStorageService.clearAuthData();
      LogService.instance.logWarning('EXIT GET /auth/middleware/refresh', {
        'status': res.statusCode,
        'body': res.body,
      });
      return false;
    } catch (e, st) {
      // 6. En excepción, también limpiar credenciales
      await SecureStorageService.clearAuthData();
      LogService.instance.logError('GET /auth/middleware/refresh', e, st);
      return false;
    }
  }

  /* =================== Helpers ================= */
  /// Borra credenciales antiguas y guarda las nuevas de forma atómica.
  static Future<void> _persistAuth(
    Map<String, dynamic> data, {
    String? accessToken,
    String? refreshToken,
  }) async {
    try {
      await SecureStorageService.clearAuthData();

      // Usar los tokens pasados como parámetros o los que vienen en data
      final token = accessToken ?? data['accessToken'];
      final refToken = refreshToken ?? data['refreshToken'];

      // Obtener username de diferentes posibles campos
      final username =
          data['sAMAccountName'] ??
          data['username'] ??
          data['user']?['username'] ??
          'unknown';

      // 👇 AQUÍ EL CAMBIO CRÍTICO - ACTUALIZAR AppStateManager
      final appState = AppStateManager.instance;

      // Guardar en SecureStorage
      await SecureStorageService.saveAuthData(
        token: token,
        refreshToken: refToken,
        username: username,
      );

      // 👇 ACTUALIZAR AppStateManager CON LOS NUEVOS TOKENS
      appState.setTokens(token, refToken);

      LogService.instance.logRequest('AuthApiService._persistAuth', {
        'event': 'tokens_updated',
        'userId': data['id'] ?? 'no_id',
        'username': username,
        'has_access_token': token != null,
        'has_refresh_token': refToken != null,
        'appstate_updated': true, // 👈 Nuevo campo para tracking
      });
    } catch (e, st) {
      LogService.instance.logError('AuthApiService._persistAuth', e, st);
      await SecureStorageService.clearAuthData();
      rethrow;
    }
  }
}
