import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tpg_attack_kiosko_muelle/services/apis/ocr_client_auth_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';

class OcrApiServiceException implements Exception {
  final String message;

  OcrApiServiceException(this.message);

  @override
  String toString() => message;
}

class OcrApiService {
  final _log = LogService.instance;

  Future<Map<String, String>> _authHeaders({bool forceRefresh = false}) async {
    final token = await OcrClientAuthService.instance.getAccessToken(
      forceRefresh: forceRefresh,
    );

    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    await _log.logRequest('OCR_API_AUTH_HEADERS', {
      'hasToken': token != null && token.isNotEmpty,
      'tokenSource': 'OCR_CLIENT_ID',
      'forceRefresh': forceRefresh,
    });

    return headers;
  }

  Future<http.Response> _postWithOcrClientToken(
    Uri uri, {
    required String body,
    required String tag,
  }) async {
    var headers = await _authHeaders();

    var res = await http
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 30));

    if (res.statusCode == 401 || res.statusCode == 403) {
      final firstRaw = utf8.decode(res.bodyBytes);

      await _log.logRequest('${tag}_AUTH_FAIL_RETRY_WITH_OCR_CLIENT', {
        'firstStatusCode': res.statusCode,
        'firstBody': firstRaw,
        'tokenSource': 'OCR_CLIENT_ID',
        'reason': 'Se renueva token técnico OCR y se reintenta una sola vez',
      });

      OcrClientAuthService.instance.clearCache();

      headers = await _authHeaders(forceRefresh: true);

      res = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
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

    final body = {'uuid': cleanUuid, 'status': cleanStatus};

    final bodyJson = jsonEncode(body);

    await _log.logRequest('OCR_UPDATE_STATUS_REQUEST', {
      'url': uri.toString(),
      'method': 'POST',
      'body': body,
      'tokenSource': 'OCR_CLIENT_ID',
    });

    final resp = await _postWithOcrClientToken(
      uri,
      body: bodyJson,
      tag: 'OCR_UPDATE_STATUS',
    );

    final rawBody = utf8.decode(resp.bodyBytes);

    await _log.logRequest('OCR_UPDATE_STATUS_HTTP_RESPONSE', {
      'statusCode': resp.statusCode,
      'rawBody': rawBody,
      'tokenSource': 'OCR_CLIENT_ID',
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
    final configured = (baseUrl ?? '').trim();

    if (configured.isEmpty) {
      throw OcrApiServiceException(
        'No existe URL OCR. Configure kioskConfig.ocrService',
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
