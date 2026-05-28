// lib/services/apis/psc/psc_api_service.dart

import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tpg_attack_kiosko_muelle/models/psc/psc_models.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/authApi_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/secure_storage_service.dart';

class PscApiService {
  const PscApiService();

  static Map<String, String>? _cachedHeaders;
  static DateTime? _headersCacheTime;
  static const _headersCacheDuration = Duration(minutes: 4);

  Future<PscApiEnvelope<PscNavegarData>> navegar({
    required AppStateManager appState,
    required JsonMap body,
  }) {
    return _post<PscNavegarData>(
      path: '/psc/navegar',
      body: body,
      mapper: PscNavegarData.fromJson,
      tag: 'PSC_NAVEGAR',
    );
  }

  Future<PscApiEnvelope<PscInicializarData>> inicializar({
    required AppStateManager appState,
    required JsonMap body,
  }) {
    return _post<PscInicializarData>(
      path: '/psc/psc/inicializar',
      body: body,
      mapper: PscInicializarData.fromJson,
      tag: 'PSC_INICIALIZAR',
    );
  }

  Future<PscApiEnvelope<PscGuardarData>> guardar({
    required AppStateManager appState,
    required JsonMap body,
  }) {
    return _post<PscGuardarData>(
      path: '/psc/psc/guardar',
      body: body,
      mapper: PscGuardarData.fromJson,
      tag: 'PSC_GUARDAR',
    );
  }

  Future<PscApiEnvelope<PscTerminarData>> terminar({
    required AppStateManager appState,
    required JsonMap body,
  }) {
    return _post<PscTerminarData>(
      path: '/psc/psc/terminar',
      body: body,
      mapper: PscTerminarData.fromJson,
      tag: 'PSC_TERMINAR',
    );
  }

  Future<PscApiEnvelope<T>> _post<T>({
    required String path,
    required JsonMap body,
    required T Function(JsonMap json) mapper,
    required String tag,
  }) async {
    final url = '$_baseUrl$path';
    final uri = Uri.parse(url);
    final sw = Stopwatch()..start();

    await LogService.instance.logConnStart(
      kind: 'http',
      target: url,
      extra: {
        'method': 'POST',
        'tag': tag,
        'path': path,
      },
    );

    try {
      var headers = await _headers();

      await LogService.instance.logSpExec(
        service: tag,
        path: path,
        method: 'POST',
        payload: body,
        context: {
          'url': url,
          'headers': _safeHeaders(headers),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      await LogService.instance.logRequest('${tag}_FULL_REQUEST', {
        'url': url,
        'method': 'POST',
        'path': path,
        'headers': _safeHeaders(headers),
        'body': body,
        'bodyPretty': _prettyJson(body),
      });

      var response = await http
          .post(
            uri,
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode == 401 || response.statusCode == 403) {
        await LogService.instance.logWarning('${tag}_TOKEN_EXPIRED', {
          'url': url,
          'path': path,
          'statusCode': response.statusCode,
          'body': response.body,
        });

        invalidateHeadersCache();

        final appState = AppStateManager.instance;
        final refreshed = await AuthApiService.refresh(appState);

        await LogService.instance.logRequest('${tag}_REFRESH_TOKEN_RESULT', {
          'refreshed': refreshed,
          'url': url,
          'path': path,
        });

        if (refreshed) {
          headers = await _headers();

          await LogService.instance.logRequest('${tag}_RETRY_REQUEST', {
            'url': url,
            'method': 'POST',
            'path': path,
            'headers': _safeHeaders(headers),
            'body': body,
            'bodyPretty': _prettyJson(body),
          });

          response = await http
              .post(
                uri,
                headers: headers,
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 90));
        }
      }

      await LogService.instance.logConnEnd(
        kind: 'http',
        target: url,
        ok: response.statusCode == 200 || response.statusCode == 201,
        ms: sw.elapsedMilliseconds,
        extra: {
          'statusCode': response.statusCode,
          'tag': tag,
          'path': path,
        },
      );

      await LogService.instance.logRequest('${tag}_FULL_RESPONSE', {
        'url': url,
        'path': path,
        'statusCode': response.statusCode,
        'latencyMs': sw.elapsedMilliseconds,
        'rawBody': response.body,
      });

      if (response.statusCode != 200 && response.statusCode != 201) {
        await LogService.instance.logSpResult(
          service: tag,
          path: path,
          errorCode: 1,
          message: 'HTTP ${response.statusCode}',
          data: {
            'url': url,
            'statusCode': response.statusCode,
            'rawBody': response.body,
            'requestPayload': body,
          },
          latencyMs: sw.elapsedMilliseconds,
          levelOverride: 'ERROR',
        );

        throw Exception('$tag HTTP ${response.statusCode}: ${response.body}');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));

      if (decoded is! JsonMap) {
        await LogService.instance.logSpResult(
          service: tag,
          path: path,
          errorCode: 1,
          message: 'Respuesta JSON inválida',
          data: {
            'url': url,
            'rawBody': response.body,
            'requestPayload': body,
          },
          latencyMs: sw.elapsedMilliseconds,
          levelOverride: 'ERROR',
        );

        throw Exception('$tag respondió un JSON inválido.');
      }

      await LogService.instance.logRequest('${tag}_DECODED_RESPONSE', {
        'url': url,
        'path': path,
        'decoded': decoded,
        'decodedPretty': _prettyJson(decoded),
      });

      final env = PscApiEnvelope<T>.fromJson(decoded, mapper);

      await LogService.instance.logSpResult(
        service: tag,
        path: path,
        errorCode: env.errorCode,
        message: env.message,
        data: {
          'url': url,
          'requestPayload': body,
          'responseRaw': decoded,
          'responseData': decoded['data'],
        },
        latencyMs: sw.elapsedMilliseconds,
      );

      return env;
    } catch (e, st) {
      await LogService.instance.logConnEnd(
        kind: 'http',
        target: url,
        ok: false,
        ms: sw.elapsedMilliseconds,
        error: e,
        extra: {
          'tag': tag,
          'path': path,
        },
      );

      await LogService.instance.logSpResult(
        service: tag,
        path: path,
        errorCode: 1,
        message: _cleanError(e),
        data: {
          'url': url,
          'requestPayload': body,
        },
        latencyMs: sw.elapsedMilliseconds,
        levelOverride: 'ERROR',
      );

      await LogService.instance.logError('${tag}_ERROR', e, st);
      rethrow;
    }
  }

  Future<Map<String, String>> _headers() async {
    if (_cachedHeaders != null &&
        _headersCacheTime != null &&
        DateTime.now().difference(_headersCacheTime!) < _headersCacheDuration) {
      return _cachedHeaders!;
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    final appState = AppStateManager.instance;
    var token = appState.accessToken;

    if (token == null || token.isEmpty) {
      final storageToken = await SecureStorageService.getToken();

      if (storageToken != null && storageToken.isNotEmpty) {
        final refresh = await SecureStorageService.getRefreshToken();
        appState.setTokens(storageToken, refresh ?? '');
        token = storageToken;
      }
    }

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    _cachedHeaders = headers;
    _headersCacheTime = DateTime.now();

    return headers;
  }

  static void invalidateHeadersCache() {
    _cachedHeaders = null;
    _headersCacheTime = null;
  }

  String get _baseUrl {
    final raw = dotenv.env['BASE_MIDDLEWARE_URL'] ?? '';

    if (raw.trim().isEmpty) {
      throw Exception('BASE_MIDDLEWARE_URL no configurada');
    }

    final base = raw.trim().replaceAll(RegExp(r'/+$'), '');

    return '$base/kiosk/api';
  }

  String _prettyJson(dynamic value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  Map<String, String> _safeHeaders(Map<String, String> headers) {
    final copy = Map<String, String>.from(headers);

    if (copy.containsKey('Authorization')) {
      final token = copy['Authorization'] ?? '';
      copy['Authorization'] = token.length > 20
          ? '${token.substring(0, 20)}...'
          : '***';
    }

    return copy;
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('Error:', '')
        .trim();
  }
}