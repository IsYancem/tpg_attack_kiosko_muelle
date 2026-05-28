// lib/services/apis/descarga/descarga_service.dart
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tpg_attack_kiosko_muelle/models/descarga/descarga_api_model.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/authApi_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/secure_storage_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/env_utils.dart';

class DescargaService {
  final _log = LogService.instance;

  // ─────────────────────────────────────────────
  // 🔐 Cache de headers + refresh
  // ─────────────────────────────────────────────
  static Map<String, String>? _cachedHeaders;
  static DateTime? _headersCacheTime;
  static const _headersCacheDuration = Duration(minutes: 4);

  // ─────────────────────────────────────────────
  // HEADERS
  // ─────────────────────────────────────────────
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

  String get _baseUrl => dotenv.env['BASE_MIDDLEWARE_URL'] ?? '';

  // ─────────────────────────────────────────────
  // INICIALIZAR
  // ─────────────────────────────────────────────
  Future<DescargaApiResponse> inicializar(
    AtkTransactionManager manager,
    AppStateManager app,
  ) async {
    final body = {
      'placa': manager.vehiculoPlaca,
      'peso': manager.pesoActualBascula,
    };

    await _log.logRequest('DESCARGA_INICIALIZAR_REQ', body);

    final sw = Stopwatch()..start();
    try {
      final res = await _post('/descarga/initial', body);

      await _log.logRequest('DESCARGA_INICIALIZAR_RES', {
        'latency_ms': sw.elapsedMilliseconds,
        'errorCode': res['errorCode'],
        'message': res['message'],
      });

      return DescargaApiResponse.fromJson(res);
    } catch (e, st) {
      await _log.logError('DESCARGA_INICIALIZAR_EX', e, st);
      rethrow;
    }
  }

  static void invalidateHeadersCache() {
    _cachedHeaders = null;
    _headersCacheTime = null;
  }

  int _extractTpgNumber(dynamic patio) {
    final raw = patio?.toString().trim().toUpperCase() ?? '';
    final onlyNumbers = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(onlyNumbers) ?? 0;
  }

  // ─────────────────────────────────────────────
  // GUARDAR
  // ─────────────────────────────────────────────
  Future<DescargaApiResponse> guardar(
    AtkTransactionManager manager,
    AppStateManager app,
  ) async {
    final tpgNumber = _extractTpgNumber(app.kioskConfig?.patio);

    final body = {
      'tipoTran': 'I',
      'codtipo': 'I',
      'codProducto': 'P01',
      'codTipoCarga': 'DES',
      'placa': manager.vehiculoPlaca,
      'contenedor': manager.contenedor,
      'tara': manager.pesoTara != null ? double.tryParse(manager.pesoTara!) : 0,
      'pesoIngreso': manager.pesoActualBascula,
      'pesoActual': manager.pesoActualBascula,
      'pesoPorteo': manager.pesoPorteo != null
          ? double.tryParse(manager.pesoPorteo!)
          : 0,
      'pesoCarga':
          manager.pesoActualBascula -
          (double.tryParse(manager.pesoPorteo ?? '0') ?? 0) -
          (double.tryParse(manager.pesoTara ?? '0') ?? 0),
      'choferRuc': manager.driverCedula,
      'choferNombres': manager.driverName,
      'deviceId': app.kioskConfig?.gate,
      'usuarioNombre': KioskUserEnv.usuario,
      'tpg': tpgNumber,
      'garitaLetra': app.kioskConfig?.gateLetter,
      'garitaNumero': app.kioskConfig?.gate,
      'doorNumber': _doorNumber(manager),
      'fechaBarrera': DateTime.now().toString().substring(0, 19),
      'ruc': manager.driverCedula,
      'ciaTransporte': manager.vehiculoEmpresa,
      '_placa': manager.vehiculoPlaca,
      'codEmpresa': app.kioskConfig?.gateLetter,
      'codEmpresaF': app.kioskConfig?.gateLetter,
    };

    await _log.logRequest('DESCARGA_GUARDAR_REQ', body);

    final sw = Stopwatch()..start();
    try {
      final res = await _post('/descarga/guardar', body);

      await _log.logRequest('DESCARGA_GUARDAR_RES', {
        'latency_ms': sw.elapsedMilliseconds,
        'errorCode': res['errorCode'],
        'message': res['message'],
        'numero_transaccion': res['data']?['numero_transaccion'],
      });

      return DescargaApiResponse.fromJson(res);
    } catch (e, st) {
      await _log.logError('DESCARGA_GUARDAR_EX', e, st);
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // HTTP HELPER (CON LOGS DE CONEXIÓN)
  // ─────────────────────────────────────────────
  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final url = '${_baseUrl}kiosk/api$path';
    final sw = Stopwatch()..start();

    await _log.logConnStart(
      kind: 'http',
      target: url,
      extra: {'method': 'POST'},
    );

    try {
      var headers = await _headers();

      await _log.logRequest('DESCARGA_HTTP_FULL_REQUEST', {
        'url': url,
        'method': 'POST',
        'headers': _safeHeaders(headers),
        'body': body,
        'bodyPretty': _prettyJson(body),
      });

      var response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 401 || response.statusCode == 403) {
        await _log.logWarning('DESCARGA_TOKEN_EXPIRED', {
          'status': response.statusCode,
          'body': response.body,
        });

        invalidateHeadersCache();

        final appState = AppStateManager.instance;
        final refreshed = await AuthApiService.refresh(appState);

        await _log.logRequest('DESCARGA_REFRESH_TOKEN_RESULT', {
          'refreshed': refreshed,
        });

        if (refreshed) {
          headers = await _headers();

          await _log.logRequest('DESCARGA_HTTP_FULL_RETRY_REQUEST', {
            'url': url,
            'method': 'POST',
            'headers': _safeHeaders(headers),
            'body': body,
            'bodyPretty': _prettyJson(body),
          });

          response = await http.post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(body),
          );
        }
      }

      await _log.logConnEnd(
        kind: 'http',
        target: url,
        ok: response.statusCode == 200 || response.statusCode == 201,
        ms: sw.elapsedMilliseconds,
        extra: {'statusCode': response.statusCode},
      );

      await _log.logRequest('DESCARGA_HTTP_FULL_RESPONSE', {
        'url': url,
        'statusCode': response.statusCode,
        'latencyMs': sw.elapsedMilliseconds,
        'rawBody': response.body,
      });

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('HTTP ${response.statusCode} | ${response.body}');
      }

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Respuesta inválida: ${response.body}');
      }

      await _log.logRequest('DESCARGA_HTTP_DECODED_RESPONSE', {
        'url': url,
        'decoded': decoded,
        'decodedPretty': _prettyJson(decoded),
      });

      return decoded;
    } catch (e) {
      await _log.logConnEnd(
        kind: 'http',
        target: url,
        ok: false,
        ms: sw.elapsedMilliseconds,
        error: e,
      );

      await _log.logError('DESCARGA_HTTP_FULL_ERROR', e);

      rethrow;
    }
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

  int _doorNumber(AtkTransactionManager manager) {
    return _int(
          manager.get('side') ?? manager.get('doorNumber') ?? manager.sideGate,
        ) ??
        0;
  }

  int? _int(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
