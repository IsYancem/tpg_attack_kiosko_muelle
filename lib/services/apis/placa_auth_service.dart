// lib/services/apis/placa_auth_service.dart
// Autor: Abraham Yance
// Fecha: 2025-12-02
// Servicio para ejecutar placa-auth (atk_get_placa_auth + atk_verifica_placa)
// ✅ Con auto-refresh de token cuando expira (401/403)

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/secure_storage_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/status_log_bus.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/authApi_service.dart';

class PlacaAuthService {
  final _log = LogService.instance;

  /// Obtiene headers con token JWT almacenado
  /// ✅ Usa AppStateManager como fuente principal
  Future<Map<String, String>> _authHeaders() async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    // Obtener el token de AppStateManager (fuente principal)
    final appState = AppStateManager.instance;
    final token = appState.accessToken;

    // Si no hay token en AppStateManager, intentar obtener de SecureStorage (respaldo)
    if (token == null || token.isEmpty) {
      final storageToken = await SecureStorageService.getToken();
      if (storageToken != null && storageToken.isNotEmpty) {
        // Sincronizar AppStateManager con el token de SecureStorage
        final storageRefreshToken =
            await SecureStorageService.getRefreshToken();
        appState.setTokens(storageToken, storageRefreshToken ?? '');
        headers['Authorization'] = 'Bearer $storageToken';
      } 
    } else {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  /// POST con reintento automático si el accessToken está vencido
  /// ✅ Auto-refresh de token cuando recibe 401/403
  Future<http.Response> _postWithAutoRefresh(
    Uri uri, {
    required Map<String, dynamic> body,
    required String tag,
  }) async {
    var headers = await _authHeaders();

    _log.logConnStart(
      kind: 'HTTP',
      target: uri.toString(),
      extra: {'tag': tag, 'try': 1, 'method': 'POST'},
    );

    var res = await http.post(uri, headers: headers, body: json.encode(body));

    _log.logConnEnd(
      kind: 'HTTP',
      target: uri.toString(),
      ok: res.statusCode == 200 || res.statusCode == 201,
      extra: {'tag': tag, 'status': res.statusCode, 'try': 1},
    );

    // ════════════════════════════════════════════════════════════════
    // 🔄 Si expira el token (401/403), refrescar y reintentar
    // ════════════════════════════════════════════════════════════════
    if (res.statusCode == 401 || res.statusCode == 403) {
      _log.logWarning('AUTH_EXPIRED', {
        'tag': tag,
        'uri': uri.toString(),
        'status': res.statusCode,
        'action': 'refresh',
      });

      final appState = AppStateManager.instance;

      // 🔑 Llamar al servicio de refresh
      final refreshed = await AuthApiService.refresh(appState);

      if (!refreshed) {
        _log.logWarning('AUTH_REFRESH_FAIL', {'tag': tag});
        return res;
      }

      _log.logRequest('AUTH_REFRESH_OK', {'tag': tag});

      // 🔑 Obtener headers con el NUEVO token
      headers = await _authHeaders();

      _log.logConnStart(
        kind: 'HTTP',
        target: uri.toString(),
        extra: {'tag': tag, 'try': 2, 'method': 'POST'},
      );

      res = await http.post(uri, headers: headers, body: json.encode(body));

      _log.logConnEnd(
        kind: 'HTTP',
        target: uri.toString(),
        ok: res.statusCode == 200 || res.statusCode == 201,
        extra: {'tag': tag, 'status': res.statusCode, 'try': 2},
      );
    }

    return res;
  }

  /// Retorna `true` si puede continuar, `false` si debe abortar flujo
  Future<bool> ejecutarPlacaAuth({required String placa}) async {
    final baseUrl = dotenv.env['BASE_MIDDLEWARE_URL'] ?? '';
    if (baseUrl.isEmpty) {
      _log.logWarning('PLACA_AUTH_CONFIG', {
        'msg': 'BASE_MIDDLEWARE_URL vacía',
      });
      return false;
    }

    final uri = Uri.parse('${baseUrl}kiosk/api/datos/placa-auth');
    final body = {'placa': placa};

    _log.logRequest('PLACA_AUTH_START', {
      'placa': placa,
      'url': uri.toString(),
    });

    try {
      // ✅ Usar _postWithAutoRefresh en lugar de http.post directo
      final response = await _postWithAutoRefresh(
        uri,
        body: body,
        tag: 'PLACA_AUTH',
      );

      final responseBody = utf8.decode(response.bodyBytes);
      final decoded = json.decode(responseBody);

      _log.logRequest('PLACA_AUTH_RESPONSE', {
        'status': response.statusCode,
        'response': decoded,
      });

      // Formatear log visual más descriptivo
      // final auth = decoded['data']?['placaAuth'] ?? {};
      // final regNumber = auth['placa'] ?? placa;
      // final autorizado = auth['msg'] ?? 'Desconocido';
      // final hasta = auth['autorizado_hasta'] ?? 'N/D';
      // final cod = decoded['errorCode'];
      // final detalle = auth['transaccion'] ?? 'N/A';

      // final resumen = [
      //   '🔎 PlacaAuth:',
      //   '• Placa: $regNumber',
      //   '• Estado: $autorizado',
      //   '• Hasta: $hasta',
      //   '• Movimiento: $detalle',
      //   '• Code: $cod',
      // ].join('\n');

      // StatusLogBus.instance.addText('RFID', resumen);

      // Si errorCode global es 1, abortar
      final errorCode = decoded['errorCode'];
      return errorCode == 0;
    } catch (e, st) {
      _log.logError('PLACA_AUTH_ERROR', e, st);
      StatusLogBus.instance.addText('RFID', '❌ Error PlacaAuth: $e');
      return false;
    }
  }
}
