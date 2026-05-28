// lib/services/apis/res/res_api_service.dart
// Autor: Abraham Yance
// Fecha: 2025-12-29
// API Service: RES (estilo EXM, con auto-refresh y parsing tipado)

import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:tpg_attack_kiosko_muelle/models/res/res_models.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/authApi_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/secure_storage_service.dart';

class ResApiServiceException implements Exception {
  final String message;
  ResApiServiceException(this.message);
  @override
  String toString() => message;
}

class ResApiService {
  ResApiService._();
  static final ResApiService instance = ResApiService._();

  final _log = LogService.instance;

  // ✅ Cache de headers (igual EXM)
  static Map<String, String>? _cachedHeaders;
  static DateTime? _headersCacheTime;
  static const _headersCacheDuration = Duration(minutes: 4);

  static void invalidateHeadersCache() {
    _cachedHeaders = null;
    _headersCacheTime = null;
  }

  String get _baseUrl {
    final raw = dotenv.env['BASE_MIDDLEWARE_URL'] ?? '';
    if (raw.trim().isEmpty) {
      throw ResApiServiceException('BASE_MIDDLEWARE_URL no configurada');
    }
    return raw.endsWith('/') ? raw : '$raw/';
  }

  Future<Map<String, String>> _authHeaders() async {
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
        final storageRefreshToken =
            await SecureStorageService.getRefreshToken();
        appState.setTokens(storageToken, storageRefreshToken ?? '');
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

  /// ✅ POST con auto-refresh (igual EXM)
  Future<http.Response> _postWithAutoRefresh(
    Uri uri, {
    required String body,
    required String tag,
  }) async {
    var headers = await _authHeaders();

    final requestId = DateTime.now().millisecondsSinceEpoch;
    print('🌐 [HTTP-$requestId] POST $uri');
    print('📦 [HTTP-$requestId] Body length: ${body.length} bytes');
    print('🔑 [HTTP-$requestId] Headers: ${headers.keys.join(", ")}');

    try {
      var res = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      print(
        '✅ [HTTP-$requestId] Response: ${res.statusCode} (${res.body.length} bytes)',
      );

      if (res.statusCode == 401 || res.statusCode == 403) {
        print('🔄 [HTTP-$requestId] Auth error, refreshing token...');
        invalidateHeadersCache();

        final appState = AppStateManager.instance;
        final refreshed = await AuthApiService.refresh(appState);
        if (refreshed) {
          print('🔄 [HTTP-$requestId] RETRY con nuevo token');
          headers = await _authHeaders();
          res = await http
              .post(uri, headers: headers, body: body)
              .timeout(const Duration(seconds: 30));
          print('✅ [HTTP-$requestId] RETRY Response: ${res.statusCode}');
        }
      }

      return res;
    } on TimeoutException catch (e) {
      print('⏱️ [HTTP-$requestId] TIMEOUT después de 30s $e');
      rethrow;
    } catch (e) {
      print('❌ [HTTP-$requestId] ERROR: $e');
      rethrow;
    }
  }

  /// Helper: POST + parse ApiEnvelope<T>
  Future<ApiEnvelope<T>> _postEnvelope<T>({
    required String path, // ej: 'kiosk/api/res/init'
    required Map<String, dynamic> bodyMap,
    required T Function(Map<String, dynamic> json) dataParser,
    required String tag,
  }) async {
    final uri = Uri.parse('$_baseUrl$path');
    final bodyJson = json.encode(bodyMap);

    _log.logRequest('${tag}_PAYLOAD', bodyMap);

    final resp = await _postWithAutoRefresh(uri, body: bodyJson, tag: tag);

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw ResApiServiceException('HTTP ${resp.statusCode}');
    }

    final decoded =
        json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

    // Si quieres ver todo en consola tipo EXM
    // print('─────────────────────────────────────────────');
    // print('📥 [$tag] Respuesta completa del backend:');
    // print(const JsonEncoder.withIndent('  ').convert(decoded));
    // print('─────────────────────────────────────────────\n');

    return ApiEnvelope.fromJson(decoded, (data) => dataParser(data));
  }

  // ─────────────────────────────────────────────────────────────
  // ENDPOINTS RES
  // ─────────────────────────────────────────────────────────────

  Future<ApiEnvelope<ResInitData>> init(ResInitRequest req) {
    return _postEnvelope<ResInitData>(
      path: 'kiosk/api/res/init',
      bodyMap: req.toJson(),
      dataParser: (data) => ResInitData.fromJson(data),
      tag: 'RES_INIT',
    );
  }

  Future<ApiEnvelope<ResGuardarData>> guardar(ResGuardarRequest req) {
    return _postEnvelope<ResGuardarData>(
      path: 'kiosk/api/res/guardar',
      bodyMap: req.toJson(),
      dataParser: (data) => ResGuardarData.fromJson(data),
      tag: 'RES_GUARDAR',
    );
  }

  Future<ApiEnvelope<ResTerminarData>> terminar(ResTerminarRequest req) {
    return _postEnvelope<ResTerminarData>(
      path: 'kiosk/api/res/terminar',
      bodyMap: req.toJson(),
      dataParser: (data) => ResTerminarData.fromJson(data),
      tag: 'RES_TERMINAR',
    );
  }

  Future<ApiEnvelope<ResCancelarData>> cancelar(ResCancelarRequest req) async {
    try {
      return await _postEnvelope<ResCancelarData>(
        path: 'kiosk/api/res/cancelar',
        bodyMap: req.toJson(),
        dataParser: (data) => ResCancelarData.fromJson(data),
        tag: 'RES_CANCELAR',
      );
    } catch (e, st) {
      _log.logError('RES_CANCELAR_EX', e, st);
      return ApiEnvelope<ResCancelarData>(
        errorCode: 1,
        message: 'Error en cancelar RES: $e',
        data: null,
      );
    }
  }

  Future<ApiEnvelope<ResImprimirData>> imprimir(ResImprimirRequest req) {
    return _postEnvelope<ResImprimirData>(
      path: 'kiosk/api/res/imprimir',
      bodyMap: req.toJson(),
      dataParser: (data) => ResImprimirData.fromJson(data),
      tag: 'RES_IMPRIMIR',
    );
  }
}
