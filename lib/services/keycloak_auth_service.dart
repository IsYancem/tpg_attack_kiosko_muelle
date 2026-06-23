// lib/services/auth/keycloak_auth_service.dart

import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:tpg_attack_kiosko_muelle/models/auth/keycloak_token_model.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';

class KeycloakAuthService {
  static Future<KeycloakTokenResponse?> login({
    required String username,
    required String password,
  }) async {
    final tokenUrl = dotenv.env['KEYCLOAK_TOKEN_URL'] ?? '';
    final clientId = dotenv.env['KEYCLOAK_CLIENT_ID'] ?? '';
    final clientSecret = dotenv.env['KEYCLOAK_CLIENT_SECRET'] ?? '';
    final grantType = dotenv.env['KEYCLOAK_GRANT_TYPE'] ?? 'password';
    final scope = dotenv.env['KEYCLOAK_SCOPE'] ?? 'openid profile email';

    if (tokenUrl.isEmpty || clientId.isEmpty || clientSecret.isEmpty) {
      LogService.instance.logWarning('KEYCLOAK_LOGIN_ENV_MISSING', {
        'hasTokenUrl': tokenUrl.isNotEmpty,
        'hasClientId': clientId.isNotEmpty,
        'hasClientSecret': clientSecret.isNotEmpty,
      });
      return null;
    }

    LogService.instance.logRequest('KEYCLOAK_LOGIN_START', {
      'url': tokenUrl,
      'method': 'POST',
      'username': username,
      'clientId': clientId,
      'grantType': grantType,
      'scope': scope,
    });

    final sw = Stopwatch()..start();

    final response = await http.post(
      Uri.parse(tokenUrl),
      headers: const {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
      },
      body: {
        'username': username.trim(),
        'password': password,
        'client_id': clientId,
        'client_secret': clientSecret,
        'grant_type': grantType,
        'scope': scope,
      },
    );

    sw.stop();

    LogService.instance.logRequest('KEYCLOAK_LOGIN_RESPONSE_RAW', {
      'statusCode': response.statusCode,
      'latencyMs': sw.elapsedMilliseconds,
      'bodyLength': response.body.length,
    });

    LogService.instance.logRequest('KEYCLOAK_LOGIN_DEBUG_ENV', {
      'tokenUrl': tokenUrl,
      'clientId': clientId,
      'clientSecretLen': clientSecret.length,
      'grantType': grantType,
      'scope': scope,
      'usernameLen': username.length,
      'passwordLen': password.length,
    });

    if (response.statusCode != 200) {
      String error = response.body;

      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          error =
              '${decoded['error'] ?? ''} ${decoded['error_description'] ?? ''}'
                  .trim();
        }
      } catch (_) {}

      LogService.instance.logWarning('KEYCLOAK_LOGIN_FAILED', {
        'statusCode': response.statusCode,
        'error': error,
      });

      return null;
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      LogService.instance.logWarning('KEYCLOAK_LOGIN_INVALID_JSON', {});
      return null;
    }

    final token = KeycloakTokenResponse.fromJson(decoded);

    if (token.accessToken.isEmpty) {
      LogService.instance.logWarning('KEYCLOAK_LOGIN_EMPTY_TOKEN', {});
      return null;
    }

    LogService.instance.logRequest('KEYCLOAK_LOGIN_OK', {
      'hasAccessToken': token.accessToken.isNotEmpty,
      'hasRefreshToken': token.refreshToken.isNotEmpty,
      'expiresIn': token.expiresIn,
      'sessionState': token.sessionState,
    });

    return token;
  }
}