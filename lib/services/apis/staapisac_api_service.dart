import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tpg_attack_kiosko_muelle/models/staapisac/staapisac_auth_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/staapisac/staapisac_foto_model.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';

class StaapisacApiService {
  StaapisacApiService();

  static const _loginPath = 'api/auth/login';
  static const _refreshPath = 'api/auth/refresh-status';
  static const _fotosPath = 'api/zk/fotos';

  String _baseUrl() => (dotenv.env['STAAPISAC'] ?? '').trim();
  String _username() => (dotenv.env['USERNAME_STAAPISAC'] ?? '').trim();
  String _password() => (dotenv.env['PASSWORD_STAAPISAC'] ?? '').trim();
  String _computerNameFallback() =>
      (dotenv.env['COMPUTERNAME_STAAPISAC'] ?? 'computer_disv').trim();

  Uri _uri(String path) {
    final base = _baseUrl();
    if (base.isEmpty) throw Exception('STAAPISAC está vacío en .env');

    // Normaliza slashes
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('$b/$p');
  }

  Map<String, String> _jsonHeaders({String? bearer}) {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (bearer != null && bearer.isNotEmpty) {
      h['Authorization'] = 'Bearer $bearer';
    }
    return h;
  }

  Future<Map<String, dynamic>> _postJsonObject({
    required Uri uri,
    required Map<String, dynamic> body,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final res = await http
        .post(uri, headers: headers ?? _jsonHeaders(), body: jsonEncode(body))
        .timeout(timeout);

    final raw = res.body;
    dynamic decoded;
    try {
      decoded = raw.isNotEmpty ? jsonDecode(raw) : null;
    } catch (_) {
      decoded = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception(
        'STAAPISAC: respuesta no es objeto JSON (${res.statusCode})',
      );
    }

    // Errores (incluye 401)
    throw _HttpFail(res.statusCode, raw);
  }

  Future<List<dynamic>> _postJsonList({
    required Uri uri,
    required Map<String, dynamic> body,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final res = await http
        .post(uri, headers: headers ?? _jsonHeaders(), body: jsonEncode(body))
        .timeout(timeout);

    final raw = res.body;
    dynamic decoded;
    try {
      decoded = raw.isNotEmpty ? jsonDecode(raw) : null;
    } catch (_) {
      decoded = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded is List) return decoded;
      throw Exception(
        'STAAPISAC: respuesta no es lista JSON (${res.statusCode})',
      );
    }

    // Errores (incluye 401)
    throw _HttpFail(res.statusCode, raw);
  }

  // ---------------------------
  // 1) LOGIN (llámalo en main)
  // ---------------------------
  Future<StaapisacAuthResponse> loginStaapisac({
    required AppStateManager appState,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final uri = _uri(_loginPath);
    final payload = {'username': _username(), 'password': _password()};

    final start = DateTime.now();
    const service = 'staapisac_login';

    await LogService.instance.logSpExec(
      service: service,
      path: uri.toString(),
      method: 'POST',
      payload: payload,
      context: {'target': 'STAAPISAC'},
    );

    final j = await _postJsonObject(
      uri: uri,
      body: payload,
      headers: _jsonHeaders(),
      timeout: timeout,
    );

    final ms = DateTime.now().difference(start).inMilliseconds;
    final auth = StaapisacAuthResponse.fromJson(j);

    final computerName = (auth.computerName?.trim().isNotEmpty == true)
        ? auth.computerName!.trim()
        : _computerNameFallback();

    appState.setStaapisacAuth(
      id: auth.id ?? '',
      username: auth.username ?? _username(),
      computerName: computerName,
      accessToken: auth.accessToken ?? '',
      refreshToken: auth.refreshToken ?? '',
    );

    await LogService.instance.logSpResult(
      service: service,
      path: uri.toString(),
      errorCode: 0,
      message: 'OK',
      latencyMs: ms,
      data: {
        'ok': true,
        'user': appState.staapisacUsername,
        'hasAccess': appState.staapisacAccessToken.isNotEmpty,
        'hasRefresh': appState.staapisacRefreshToken.isNotEmpty,
      },
    );

    return auth;
  }

  // -----------------------------------
  // 2) REFRESH (solo cuando fotos da 401)
  // -----------------------------------
  Future<void> refreshStaapisac({
    required AppStateManager appState,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final uri = _uri(_refreshPath);

    final start = DateTime.now();
    const service = 'staapisac_refresh';

    await LogService.instance.logSpExec(
      service: service,
      path: uri.toString(),
      method: 'GET', // ✅ CORRECTO
      payload: null,
      context: {'target': 'STAAPISAC'},
    );

    final j = await _getJsonObject(
      uri: uri,
      headers: _jsonHeaders(bearer: appState.staapisacRefreshToken),
      timeout: timeout,
    );

    final ms = DateTime.now().difference(start).inMilliseconds;
    final auth = StaapisacAuthResponse.fromJson(j);

    final computerName = (auth.computerName?.trim().isNotEmpty == true)
        ? auth.computerName!.trim()
        : (appState.staapisacComputerName.isNotEmpty
              ? appState.staapisacComputerName
              : _computerNameFallback());

    appState.setStaapisacAuth(
      id: auth.id ?? appState.staapisacId,
      username: auth.username ?? appState.staapisacUsername,
      computerName: computerName,
      accessToken: auth.accessToken ?? '',
      refreshToken: auth.refreshToken ?? '',
    );

    await LogService.instance.logSpResult(
      service: service,
      path: uri.toString(),
      errorCode: 0,
      message: 'OK',
      latencyMs: ms,
      data: {'ok': true},
    );
  }

  Future<Map<String, dynamic>> _getJsonObject({
    required Uri uri,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final res = await http
        .get(uri, headers: headers ?? _jsonHeaders())
        .timeout(timeout);

    final raw = res.body;
    dynamic decoded;
    try {
      decoded = raw.isNotEmpty ? jsonDecode(raw) : null;
    } catch (_) {
      decoded = null;
    }

    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      throw Exception(
        'STAAPISAC: respuesta no es objeto JSON (${res.statusCode})',
      );
    }

    throw _HttpFail(res.statusCode, raw);
  }

  // -------------------------
  // 3) FOTOS (Bearer + retry)
  // -------------------------
  Future<List<StaapisacFotoRow>> getFotos({
    required AppStateManager appState,
    required String id,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    if (appState.staapisacAccessToken.isEmpty) {
      throw Exception('No hay accessToken STAAPISAC. Ejecuta login primero.');
    }

    final uri = _uri(_fotosPath);
    final payload = {'ID': id.trim()};
    const service = 'staapisac_fotos';

    Future<List<StaapisacFotoRow>> callOnce() async {
      final start = DateTime.now();

      await LogService.instance.logRequest('STAAPISAC_FOTOS_START', {
        'url': uri.toString(),
        'id': id.trim(),
        'hasAccessToken': appState.staapisacAccessToken.isNotEmpty,
        'tokenLength': appState.staapisacAccessToken.length,
        'payload': payload,
      });

      await LogService.instance.logSpExec(
        service: service,
        path: uri.toString(),
        method: 'POST',
        payload: payload,
        context: {
          'target': 'STAAPISAC',
          'hasBearer': appState.staapisacAccessToken.isNotEmpty,
        },
      );

      final list = await _postJsonList(
        uri: uri,
        body: payload,
        headers: _jsonHeaders(bearer: appState.staapisacAccessToken),
        timeout: timeout,
      );

      final ms = DateTime.now().difference(start).inMilliseconds;

      final rows = list
          .whereType<Map>()
          .map((m) => StaapisacFotoRow.fromJson(m.cast<String, dynamic>()))
          .toList();

      await LogService.instance.logRequest('STAAPISAC_FOTOS_ROWS', {
        'id': id.trim(),
        'rows': rows.length,
        'items': rows.map((r) {
          return {
            'codeError': r.codeError,
            'message': r.message,
            'hasImg': (r.img ?? '').trim().isNotEmpty,
            'imgLength': r.img?.length ?? 0,
          };
        }).toList(),
      });

      await LogService.instance.logSpResult(
        service: service,
        path: uri.toString(),
        errorCode: 0,
        message: 'OK',
        latencyMs: ms,
        data: {
          'ok': true,
          'rows': rows.length,
          'hasAnyImage': rows.any((r) => (r.img ?? '').trim().isNotEmpty),
        },
      );

      return rows;
    }

    try {
      return await callOnce();
    } catch (e, st) {
      final is401 =
          (e is _HttpFail && e.statusCode == 401) ||
          e.toString().contains('401') ||
          e.toString().toLowerCase().contains('unauthorized');

      if (is401) {
        await LogService.instance.logWarning(
          'STAAPISAC_FOTOS_401_REFRESH_RETRY',
          {'id': id.trim(), 'error': e.toString()},
        );

        try {
          await refreshStaapisac(appState: appState);
          return await callOnce();
        } catch (e2, st2) {
          await LogService.instance.logError(
            'STAAPISAC_FOTOS_RETRY_FAIL',
            e2,
            st2,
          );
          rethrow;
        }
      }

      await LogService.instance.logError('STAAPISAC_FOTOS_EXCEPTION', e, st);
      rethrow;
    }
  }

  Future<String?> getFotoChoferBase64({
    required AppStateManager appState,
    required String choferId,
  }) async {
    await LogService.instance.logRequest('STAAPISAC_GET_FOTO_CHOFER_START', {
      'choferId': choferId,
    });

    final rows = await getFotos(appState: appState, id: choferId);

    for (final r in rows) {
      final img = r.img?.trim() ?? '';

      await LogService.instance.logRequest('STAAPISAC_GET_FOTO_CHOFER_ROW', {
        'choferId': choferId,
        'codeError': r.codeError,
        'message': r.message,
        'hasImg': img.isNotEmpty,
        'imgLength': img.length,
      });

      if ((r.codeError ?? 1) == 0 && img.isNotEmpty) {
        await LogService.instance.logRequest('STAAPISAC_GET_FOTO_CHOFER_OK', {
          'choferId': choferId,
          'imgLength': img.length,
        });

        return img;
      }
    }

    await LogService.instance.logWarning('STAAPISAC_GET_FOTO_CHOFER_EMPTY', {
      'choferId': choferId,
      'rows': rows.length,
    });

    return null;
  }
}

// Helper interno para distinguir errores HTTP
class _HttpFail implements Exception {
  final int statusCode;
  final String body;
  _HttpFail(this.statusCode, this.body);

  @override
  String toString() => 'HTTP_FAIL($statusCode): $body';
}
