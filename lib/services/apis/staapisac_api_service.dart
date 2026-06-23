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

  Future<StaapisacAuthResponse> loginStaapisac({
    required AppStateManager appState,
    required String username,
    required String password,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final uri = _uri(_loginPath);

    final rawUsername = username.trim();
    final cleanUsername = _normalizeStaapisacUsername(rawUsername);
    final cleanPassword = password.trim();

    if (cleanUsername.isEmpty) {
      throw Exception('STAAPISAC: username vacío');
    }

    if (cleanPassword.isEmpty) {
      throw Exception('STAAPISAC: password vacío');
    }

    final payload = <String, dynamic>{
      'username': cleanUsername,
      'password': cleanPassword,
    };

    final start = DateTime.now();
    const service = 'staapisac_login';

    await LogService.instance.logSpExec(
      service: service,
      path: uri.toString(),
      method: 'POST',
      payload: {
        'rawUsername': rawUsername,
        'username': cleanUsername,
        'password': '***',
      },
      context: {'target': 'STAAPISAC', 'source': 'login_screen'},
    );

    try {
      final j = await _postJsonObject(
        uri: uri,
        body: payload,
        headers: _jsonHeaders(),
        timeout: timeout,
      );

      LogService.instance.logRequest('STAAPISAC_LOGIN_RAW_RESPONSE', {
        'raw': j,
        'keys': j.keys.toList(),
        'hasAccessToken': j.containsKey('accessToken'),
        'hasAccess_token': j.containsKey('access_token'),
        'hasToken': j.containsKey('token'),
        'hasData': j.containsKey('data'),
      });

      final ms = DateTime.now().difference(start).inMilliseconds;
      final auth = StaapisacAuthResponse.fromJson(j);

      final computerName = (auth.computerName?.trim().isNotEmpty == true)
          ? auth.computerName!.trim()
          : _computerNameFallback();

      appState.setStaapisacAuth(
        id: auth.id ?? '',
        username: auth.username ?? cleanUsername,
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
          'rawUsername': rawUsername,
          'usernameSent': cleanUsername,
          'user': appState.staapisacUsername,
          'hasAccess': appState.staapisacAccessToken.isNotEmpty,
          'hasRefresh': appState.staapisacRefreshToken.isNotEmpty,
        },
      );

      return auth;
    } catch (e, st) {
      final ms = DateTime.now().difference(start).inMilliseconds;

      await LogService.instance.logSpResult(
        service: service,
        path: uri.toString(),
        errorCode: -1,
        message: 'EXCEPTION',
        latencyMs: ms,
        data: {
          'rawUsername': rawUsername,
          'usernameSent': cleanUsername,
          'password': '***',
          'error': e.toString(),
        },
      );

      await LogService.instance.logError('STAAPISAC_LOGIN_EXCEPTION', e, st);
      rethrow;
    }
  }

  String _normalizeStaapisacUsername(String value) {
    final input = value.trim();

    if (input.isEmpty) return '';

    final atIndex = input.indexOf('@');

    if (atIndex > 0) {
      return input.substring(0, atIndex).trim();
    }

    return input;
  }

  Future<bool> loginStaapisacFromSavedCredentials({
    required AppStateManager appState,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final username = _normalizeStaapisacUsername(
      appState.staapisacLoginUsername,
    );
    final password = appState.staapisacLoginPassword;

    if (username.isEmpty || password.isEmpty) {
      LogService.instance.logWarning('STAAPISAC_LOGIN_SAVED_SKIPPED', {
        'reason': 'No hay credenciales guardadas en AppStateManager',
        'hasUsername': username.isNotEmpty,
        'hasPassword': password.isNotEmpty,
      });

      return false;
    }

    try {
      await loginStaapisac(
        appState: appState,
        username: username,
        password: password,
        timeout: timeout,
      );

      LogService.instance.logRequest('STAAPISAC_LOGIN_SAVED_OK', {
        'username': username,
        'hasAccessToken': appState.staapisacAccessToken.isNotEmpty,
        'hasRefreshToken': appState.staapisacRefreshToken.isNotEmpty,
      });

      return true;
    } catch (e, st) {
      LogService.instance.logError('STAAPISAC_LOGIN_SAVED_FAIL', e, st);
      return false;
    }
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

    LogService.instance.logSpExec(
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

    LogService.instance.logSpResult(
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
      LogService.instance.logWarning('STAAPISAC_FOTOS_NO_TOKEN_LOGIN', {
        'id': id.trim(),
        'hasSavedCredentials': appState.hasStaapisacCredentials,
      });

      final loginOk = await loginStaapisacFromSavedCredentials(
        appState: appState,
      );

      if (!loginOk) {
        throw Exception(
          'No hay accessToken STAAPISAC y no se pudo iniciar sesión nuevamente.',
        );
      }
    }

    final uri = _uri(_fotosPath);
    final payload = {'ID': id.trim()};
    const service = 'staapisac_fotos';

    Future<List<StaapisacFotoRow>> callOnce() async {
      final start = DateTime.now();

      LogService.instance.logRequest('STAAPISAC_FOTOS_START', {
        'url': uri.toString(),
        'id': id.trim(),
        'hasAccessToken': appState.staapisacAccessToken.isNotEmpty,
        'tokenLength': appState.staapisacAccessToken.length,
        'payload': payload,
      });

      LogService.instance.logSpExec(
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

      LogService.instance.logRequest('STAAPISAC_FOTOS_ROWS', {
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

      LogService.instance.logSpResult(
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
        LogService.instance
            .logWarning('STAAPISAC_FOTOS_AUTH_FAIL_LOGIN_RETRY', {
              'id': id.trim(),
              'error': e.toString(),
              'hasSavedCredentials': appState.hasStaapisacCredentials,
            });

        final loginOk = await loginStaapisacFromSavedCredentials(
          appState: appState,
        );

        if (!loginOk) {
          LogService.instance.logWarning('STAAPISAC_FOTOS_RETRY_SKIPPED', {
            'reason': 'No se pudo renovar sesión con login guardado',
            'id': id.trim(),
          });

          rethrow;
        }

        try {
          return await callOnce();
        } catch (e2, st2) {
          LogService.instance.logError('STAAPISAC_FOTOS_RETRY_FAIL', e2, st2);
          rethrow;
        }
      }

      LogService.instance.logError('STAAPISAC_FOTOS_EXCEPTION', e, st);
      rethrow;
    }
  }

  Future<String?> getFotoChoferBase64({
    required AppStateManager appState,
    required String choferId,
  }) async {
    LogService.instance.logRequest('STAAPISAC_GET_FOTO_CHOFER_START', {
      'choferId': choferId,
    });

    final rows = await getFotos(appState: appState, id: choferId);

    for (final r in rows) {
      final img = r.img?.trim() ?? '';

      LogService.instance.logRequest('STAAPISAC_GET_FOTO_CHOFER_ROW', {
        'choferId': choferId,
        'codeError': r.codeError,
        'message': r.message,
        'hasImg': img.isNotEmpty,
        'imgLength': img.length,
      });

      if ((r.codeError ?? 1) == 0 && img.isNotEmpty) {
        LogService.instance.logRequest('STAAPISAC_GET_FOTO_CHOFER_OK', {
          'choferId': choferId,
          'imgLength': img.length,
        });

        return img;
      }
    }

    LogService.instance.logWarning('STAAPISAC_GET_FOTO_CHOFER_EMPTY', {
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
