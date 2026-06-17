// lib/services/auth/keycloak_auth_service.dart

import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:tpg_attack_kiosko_muelle/models/auth/keycloak_token_model.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';

class KeycloakAuthService {
  static String get _tokenUrl => dotenv.env['KEYCLOAK_TOKEN_URL'] ?? '';
  static String get _clientId => dotenv.env['KEYCLOAK_CLIENT_ID'] ?? '';
  static String get _clientSecret => dotenv.env['KEYCLOAK_CLIENT_SECRET'] ?? '';
  static String get _scope =>
      dotenv.env['KEYCLOAK_SCOPE'] ?? 'openid profile email';
  static String get _grantType =>
      dotenv.env['KEYCLOAK_GRANT_TYPE'] ?? 'password';

  /// Hace login contra Keycloak (grant password) y guarda los tokens
  /// en [AppStateManager]. Devuelve el token parseado o null si falla.
  static Future<KeycloakTokenResponse?> login({
    required String username,
    required String password,
  }) async {
    final sw = Stopwatch()..start();

    if (_tokenUrl.isEmpty) {
      await LogService.instance.logError('KEYCLOAK_LOGIN_NO_URL', {
        'reason': 'KEYCLOAK_TOKEN_URL no está definido en .env',
      });
      return null;
    }

    final uri = Uri.parse(_tokenUrl);

    final headers = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
    };

    // Cuerpo x-www-form-urlencoded (igual que en Postman).
    final body = <String, String>{
      'username': username,
      'password': password,
      'client_id': _clientId,
      'client_secret': _clientSecret,
      'grant_type': _grantType,
      'scope': _scope,
    };

    await LogService.instance.logRequest('KEYCLOAK_LOGIN_START', {
      'url': _tokenUrl,
      'method': 'POST',
      'username': username,
      'clientId': _clientId,
      'grantType': _grantType,
      'scope': _scope,
      // No registramos password ni client_secret en claro.
    });

    try {
      final res = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 60));

      await LogService.instance.logRequest('KEYCLOAK_LOGIN_RESPONSE_RAW', {
        'statusCode': res.statusCode,
        'latencyMs': sw.elapsedMilliseconds,
        'bodyLength': res.body.length,
      });

      if (res.statusCode != 200) {
        await LogService.instance.logError('KEYCLOAK_LOGIN_HTTP_FAIL', {
          'statusCode': res.statusCode,
          'latencyMs': sw.elapsedMilliseconds,
          'rawBody': res.body,
        });
        return null;
      }

      final decoded = jsonDecode(utf8.decode(res.bodyBytes));

      if (decoded is! Map<String, dynamic>) {
        await LogService.instance.logWarning('KEYCLOAK_LOGIN_INVALID_JSON', {
          'statusCode': res.statusCode,
          'rawBody': res.body,
        });
        return null;
      }

      final token = KeycloakTokenResponse.fromJson(decoded);

      if (!token.isValid) {
        await LogService.instance.logWarning('KEYCLOAK_LOGIN_NO_TOKENS', {
          'hasAccess': token.accessToken.isNotEmpty,
          'hasRefresh': token.refreshToken.isNotEmpty,
        });
        return null;
      }

      // Guardar access + refresh en el manager global.
      AppStateManager.instance.setTokens(token.accessToken, token.refreshToken);

      await LogService.instance.logRequest('KEYCLOAK_LOGIN_DEBUG_ENV', {
        'tokenUrl': _tokenUrl,
        'clientId': _clientId,
        'clientSecretLen': _clientSecret.length, // si es 0 -> el .env no cargó
        'grantType': _grantType,
        'scope': _scope,
        'usernameLen': username.length,
        'passwordLen': password.length,
      });

      return token;
    } catch (e, st) {
      await LogService.instance.logError('KEYCLOAK_LOGIN_EXCEPTION', e, st);
      return null;
    }
  }

  static String _preview(String value) {
    if (value.length <= 16) return '***';
    return '${value.substring(0, 8)}...${value.substring(value.length - 6)}';
  }
}
