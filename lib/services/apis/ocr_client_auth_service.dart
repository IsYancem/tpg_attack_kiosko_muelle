import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';

class OcrClientAuthResult {
  final String accessToken;
  final int expiresIn;

  OcrClientAuthResult({
    required this.accessToken,
    required this.expiresIn,
  });

  factory OcrClientAuthResult.fromJson(Map<String, dynamic> json) {
    return OcrClientAuthResult(
      accessToken: (json['access_token'] ?? '').toString(),
      expiresIn: int.tryParse((json['expires_in'] ?? '0').toString()) ?? 0,
    );
  }
}

class OcrClientAuthService {
  OcrClientAuthService._();

  static final OcrClientAuthService instance = OcrClientAuthService._();

  String? _cachedToken;
  DateTime? _tokenExpiresAt;
  bool _authInProgress = false;

  bool get _hasValidCachedToken {
    if (_cachedToken == null || _cachedToken!.isEmpty) return false;
    if (_tokenExpiresAt == null) return false;

    return DateTime.now().isBefore(
      _tokenExpiresAt!.subtract(const Duration(seconds: 30)),
    );
  }

  Future<String?> getAccessToken({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _hasValidCachedToken) {
      return _cachedToken;
    }

    return _loginAndGetTokenWithRetry();
  }

  void clearCache() {
    _cachedToken = null;
    _tokenExpiresAt = null;

    LogService.instance.logRequest('OCR_CLIENT_AUTH_CACHE_CLEARED', {
      'cleared': true,
    });
  }

  Future<String?> _loginAndGetTokenWithRetry() async {
    if (_authInProgress) {
      await Future.delayed(const Duration(milliseconds: 500));

      if (_hasValidCachedToken) {
        return _cachedToken;
      }
    }

    _authInProgress = true;

    try {
      const maxAttempts = 3;

      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final auth = await _loginAndGetTokenOnce(attempt: attempt);

          if (auth != null && auth.accessToken.isNotEmpty) {
            _cachedToken = auth.accessToken;

            final safeExpiresIn =
                auth.expiresIn > 60 ? auth.expiresIn - 30 : auth.expiresIn;

            _tokenExpiresAt = DateTime.now().add(
              Duration(seconds: safeExpiresIn),
            );

            LogService.instance.logRequest('OCR_CLIENT_AUTH_CACHE_SET', {
              'expiresIn': auth.expiresIn,
              'tokenExpiresAt': _tokenExpiresAt?.toIso8601String(),
            });

            return _cachedToken;
          }
        } catch (e, st) {
          LogService.instance.logError('OCR_CLIENT_AUTH_ATTEMPT_ERROR', e, st);
        }

        if (attempt < maxAttempts) {
          await Future.delayed(Duration(seconds: attempt));
        }
      }

      LogService.instance.logWarning('OCR_CLIENT_AUTH_RETRY_EXHAUSTED', {
        'attempts': maxAttempts,
      });

      return null;
    } finally {
      _authInProgress = false;
    }
  }

  Future<OcrClientAuthResult?> _loginAndGetTokenOnce({
    required int attempt,
  }) async {
    final authUrl = (dotenv.env['KEYCLOAK_TOKEN_URL'] ?? '').trim();
    final clientId = (dotenv.env['OCR_CLIENT_ID'] ?? '').trim();
    final clientSecret = (dotenv.env['OCR_CLIENT_SECRET'] ?? '').trim();

    if (authUrl.isEmpty || clientId.isEmpty || clientSecret.isEmpty) {
      LogService.instance.logWarning('OCR_CLIENT_AUTH_CONFIG_MISSING', {
        'hasAuthUrl': authUrl.isNotEmpty,
        'hasClientId': clientId.isNotEmpty,
        'hasClientSecret': clientSecret.isNotEmpty,
      });

      return null;
    }

    LogService.instance.logRequest('OCR_CLIENT_AUTH_START', {
      'url': authUrl,
      'clientId': clientId,
      'hasClientSecret': clientSecret.isNotEmpty,
      'clientSecretLength': clientSecret.length,
      'grantType': 'client_credentials',
      'attempt': attempt,
    });

    final response = await http
        .post(
          Uri.parse(authUrl),
          headers: const {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Accept': 'application/json',
          },
          body: {
            'grant_type': 'client_credentials',
            'client_id': clientId,
            'client_secret': clientSecret,
          },
        )
        .timeout(const Duration(seconds: 15));

    LogService.instance.logRequest('OCR_CLIENT_AUTH_RESPONSE', {
      'statusCode': response.statusCode,
      'bodyLength': response.body.length,
      'attempt': attempt,
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      LogService.instance.logWarning('OCR_CLIENT_AUTH_FAILED', {
        'statusCode': response.statusCode,
        'body': response.body,
        'attempt': attempt,
      });

      return null;
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      LogService.instance.logWarning('OCR_CLIENT_AUTH_INVALID_JSON', {
        'attempt': attempt,
      });

      return null;
    }

    final auth = OcrClientAuthResult.fromJson(decoded);

    if (auth.accessToken.isEmpty) {
      LogService.instance.logWarning('OCR_CLIENT_AUTH_TOKEN_EMPTY', {
        'attempt': attempt,
      });

      return null;
    }

    LogService.instance.logRequest('OCR_CLIENT_AUTH_OK', {
      'clientId': clientId,
      'expiresIn': auth.expiresIn,
      'tokenLength': auth.accessToken.length,
      'attempt': attempt,
    });

    return auth;
  }
}