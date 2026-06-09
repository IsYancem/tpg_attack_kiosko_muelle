import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/authApi_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/secure_storage_service.dart';

class OcrApiServiceException implements Exception {
  final String message;

  OcrApiServiceException(this.message);

  @override
  String toString() => message;
}

class OcrApiService {
  final _log = LogService.instance;

  static Map<String, String>? _cachedHeaders;
  static DateTime? _headersCacheTime;
  static const _headersCacheDuration = Duration(minutes: 4);

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

  static void invalidateHeadersCache() {
    _cachedHeaders = null;
    _headersCacheTime = null;
  }

  Future<http.Response> _postWithAutoRefresh(
    Uri uri, {
    required String body,
    required String tag,
  }) async {
    var headers = await _authHeaders();

    var res = await http
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 401 || res.statusCode == 403) {
      invalidateHeadersCache();

      final appState = AppStateManager.instance;
      final refreshed = await AuthApiService.refresh(appState);

      if (refreshed) {
        headers = await _authHeaders();
        res = await http
            .post(uri, headers: headers, body: body)
            .timeout(const Duration(seconds: 30));
      }
    }

    return res;
  }

  Future<Map<String, dynamic>> updateStatus({
    required String uuid,
    required String status,
    String? baseUrl,
  }) async {
    final cleanUuid = uuid.trim();
    final cleanStatus = status.trim();

    if (cleanUuid.isEmpty) {
      throw OcrApiServiceException('UUID OCR vacío');
    }

    if (cleanStatus.isEmpty) {
      throw OcrApiServiceException('Estado OCR vacío');
    }

    final resolvedBaseUrl = _resolveOcrBaseUrl(baseUrl);
    final uri = Uri.parse('${resolvedBaseUrl}api/ocr/update-status');

    final body = {
      'uuid': cleanUuid,
      'status': cleanStatus,
    };

    final bodyJson = jsonEncode(body);

    await _log.logRequest('OCR_UPDATE_STATUS_REQUEST', {
      'url': uri.toString(),
      'method': 'POST',
      'body': body,
    });

    final resp = await _postWithAutoRefresh(
      uri,
      body: bodyJson,
      tag: 'OCR_UPDATE_STATUS',
    );

    final rawBody = utf8.decode(resp.bodyBytes);

    await _log.logRequest('OCR_UPDATE_STATUS_HTTP_RESPONSE', {
      'statusCode': resp.statusCode,
      'rawBody': rawBody,
    });

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      throw OcrApiServiceException(
        'Error actualizando estado OCR. HTTP ${resp.statusCode}: $rawBody',
      );
    }

    final decoded = jsonDecode(rawBody);

    if (decoded is! Map<String, dynamic>) {
      throw OcrApiServiceException(
        'Respuesta inválida actualizando estado OCR',
      );
    }

    return decoded;
  }

  String _resolveOcrBaseUrl(String? baseUrl) {
    final configured =
        baseUrl?.trim().isNotEmpty == true
            ? baseUrl!.trim()
            : (dotenv.env['OCR_BASE_URL'] ?? '').trim();

    if (configured.isEmpty) {
      throw OcrApiServiceException(
        'No existe URL OCR. Configure kioskConfig.ocrService u OCR_BASE_URL',
      );
    }

    var clean = configured;

    clean = clean.replaceFirst('ws://', 'http://');
    clean = clean.replaceFirst('wss://', 'https://');

    if (clean.endsWith('/ocr')) {
      clean = clean.substring(0, clean.length - 4);
    }

    if (!clean.endsWith('/')) {
      clean = '$clean/';
    }

    return clean;
  }
}