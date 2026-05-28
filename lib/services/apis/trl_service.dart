// lib/services/apis/trl_service.dart
// OPTIMIZADO 2025-12-09 - Con mensajes de progreso (200ms cada paso)
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tpg_attack_kiosko_muelle/models/trl/trl_transaccion_response_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/trl/trl_transaction_request_model.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/secure_storage_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/authApi_service.dart';

class TrlServiceException implements Exception {
  final String message;
  TrlServiceException(this.message);
  @override
  String toString() => message;
}

class TrlService {
  final _log = LogService.instance;

  // ✅ Duración de cada mensaje de progreso
  static const _progressDelay = Duration(milliseconds: 200);

  // ✅ Cache de headers
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

  /// ✅ Helper para mostrar mensaje de progreso
  Future<void> _showProgress(
    AtkTransactionManager manager,
    String mensaje,
  ) async {
    manager.setManyWithoutNotify({'mensajeInferior': mensaje});
    await Future.delayed(_progressDelay);
  }

  Future<TrlTransaccionResponseModel> ejecutarTransaccionTrl(
    TrlTransaccionRequestModel req,
    AtkTransactionManager manager,
  ) async {
    final sw = Stopwatch()..start();

    final baseUrl = dotenv.env['BASE_MIDDLEWARE_URL'] ?? '';
    if (baseUrl.isEmpty) {
      throw TrlServiceException('BASE_MIDDLEWARE_URL no configurada');
    }

    final url = '${baseUrl}kiosk/api/trl/transaccion';

    try {
      // ═══════════════════════════════════════════════════════════════
      // PASO 1: Preparando conexión
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '🔐 Preparando conexión segura...');

      final headersFuture = _authHeaders();
      final bodyJson = json.encode(req.toJson());
      final headers = await headersFuture;

      // ═══════════════════════════════════════════════════════════════
      // PASO 2: Conectando con servidor
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '🌐 Conectando con servidor TPG...');

      var response = await http
          .post(Uri.parse(url), headers: headers, body: bodyJson)
          .timeout(const Duration(seconds: 30));

      // Token refresh si necesario
      if (response.statusCode == 401 || response.statusCode == 403) {
        await _showProgress(manager, '🔄 Renovando credenciales...');
        invalidateHeadersCache();

        final appState = AppStateManager.instance;

        final refreshed = await AuthApiService.refresh(appState);
        if (refreshed) {
          final newHeaders = await _authHeaders();
          response = await http
              .post(Uri.parse(url), headers: newHeaders, body: bodyJson)
              .timeout(const Duration(seconds: 30));
        }
      }

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw TrlServiceException('HTTP ${response.statusCode}');
      }

      // ═══════════════════════════════════════════════════════════════
      // PASO 3: Procesando respuesta
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '📦 Procesando respuesta del servidor...');

      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      final model = TrlTransaccionResponseModel.fromJson(jsonData);

      // ═══════════════════════════════════════════════════════════════
      // PASO 4: Validando RIDT
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '✅ Validando datos RIDT...');

      // ═══════════════════════════════════════════════════════════════
      // PASO 5: Consultando contenedores
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '📦 Consultando datos de contenedores...');

      // ═══════════════════════════════════════════════════════════════
      // PASO 6: Registrando transacción
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '📝 Registrando transacción TRL...');

      // ═══════════════════════════════════════════════════════════════
      // PASO 7: Aplicando datos
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '💾 Guardando información...');

      _handleResponse(model, manager);

      // Log resumido
      _log.logRequest('TRL_COMPLETE', {
        'latency_ms': sw.elapsedMilliseconds,
        'errorCode': model.errorCode,
      });

      return model;
    } catch (e, st) {
      _log.logError('TRL_SERVICE_EX', e, st);
      manager.setError('Error ejecutando servicio TRL: $e');
      rethrow;
    }
  }

  void _handleResponse(
    TrlTransaccionResponseModel model,
    AtkTransactionManager manager,
  ) {
    final allData = <String, dynamic>{};

    // ───────────────────────────────────────────────
    // 🔹 1) Verificar error global
    // ───────────────────────────────────────────────
    if (model.errorCode != 0) {
      String detalle = model.message.isNotEmpty
          ? model.message
          : 'Error general en servicio TRL';

      final services = model.data?.services ?? {};
      for (final entry in services.entries) {
        final step = entry.value;
        if (step.errorCode != 0) {
          final pasoMsg =
              (step.spMessage?.isNotEmpty == true
                      ? step.spMessage
                      : step.message)
                  ?.toString();
          if (pasoMsg != null && pasoMsg.isNotEmpty) {
            detalle = pasoMsg;
          }
          break;
        }
      }

      allData.addAll({
        'hasError': true,
        'errorMessage': detalle,
        'mensajeInferior': detalle,
        'tituloPantalla': 'Error en Transacción TRL',
      });
      manager.setMany(allData);
      return;
    }

    // ───────────────────────────────────────────────
    // 🔹 2) Procesar cada servicio
    // ───────────────────────────────────────────────
    final services = model.data?.services ?? {};

    // TRL Cons CNT 1 (datos principales)
    if (services.containsKey('trl_cons_cnt1')) {
      final step = services['trl_cons_cnt1']!;
      final data = step.dataAsMap;
      if (step.errorCode == 0 && data != null) {
        final trlData = TrlConsCntData.fromJson(data);
        allData.addAll({
          'trlAnoOperacion1': trlData.anoOperacion,
          'trlCorOperacion1': trlData.corOperacion,
          'trlOrigen1': trlData.origen,
          'trlDestino1': trlData.destino,
          'trlAreaOrigen1': trlData.areaOrigen,
          'trlAreaDestino1': trlData.areaDestino,
          'trlBl1': trlData.bl,
          'trlDocTransporte1': trlData.docTransporte,
          'trlRutaTraslado1': trlData.rutaTraslado,
          'trlSalidaNum1': trlData.salidaNum,
          'trlMaeId1': trlData.maeId,
          'trlZonaPrimariaOrigen1': trlData.zonaPrimariaOrigen,
          'trlZonaPrimariaDestino1': trlData.zonaPrimariaDestino,
          'trlFechaEstTraslado1': trlData.fechaestTraslado,
          'trlNotificarStm1': trlData.notificarStm,
          'trlDetalle1': trlData.detalle,
          'trlFecha1': trlData.fecha,
          'trlHora1': trlData.hora,
          'trlPeso1': trlData.peso,
          'trlTara1': trlData.tara,
          'trlRucEmpresaTransporte1': trlData.rucEmpresaTransporte,
          'trlNombreEmpresaTransporte1': trlData.nombreEmpresaTransporte,
          'origenTrl': trlData.origen,
          'destinoTrl': trlData.destino,
          'contenedor1': trlData.bl,
          'detalle1': trlData.detalle,
          'pesoIngreso': trlData.peso?.toString(),
          'pesoTara': trlData.tara?.toString(),
        });
      }
    }

    // TRL Cons CNT 2 (si existe segundo contenedor)
    if (services.containsKey('trl_cons_cnt2')) {
      final step = services['trl_cons_cnt2']!;
      final data = step.dataAsMap;
      if (step.errorCode == 0 && data != null) {
        final trlData = TrlConsCntData.fromJson(data);
        allData.addAll({
          'trlAnoOperacion2': trlData.anoOperacion,
          'trlCorOperacion2': trlData.corOperacion,
          'trlOrigen2': trlData.origen,
          'trlDestino2': trlData.destino,
          'trlAreaOrigen2': trlData.areaOrigen,
          'trlAreaDestino2': trlData.areaDestino,
          'trlBl2': trlData.bl,
          'trlDocTransporte2': trlData.docTransporte,
          'trlDetalle2': trlData.detalle,
          'contenedor2': trlData.bl,
          'detalle2': trlData.detalle,
        });
      }
    }

    // Transacción EXP CNT1
    if (services.containsKey('transaccion_exp_cnt1')) {
      final step = services['transaccion_exp_cnt1']!;
      final data = step.dataAsMap;
      if (step.errorCode == 0 && data != null) {
        final transExp = TrlTransaccionExpData.fromJson(data);
        if (transExp.numero != null) {
          allData['atkId'] = transExp.numero.toString();
          allData['trlNumeroTransaccion1'] = transExp.numero;
        }
      }
    }

    // Transacción EXP CNT2
    if (services.containsKey('transaccion_exp_cnt2')) {
      final step = services['transaccion_exp_cnt2']!;
      final data = step.dataAsMap;
      if (step.errorCode == 0 && data != null) {
        final transExp = TrlTransaccionExpData.fromJson(data);
        allData['trlNumeroTransaccion2'] = transExp.numero;
      }
    }

    // Monitor ATK
    if (services.containsKey('monitor_attack')) {
      final step = services['monitor_attack']!;
      final data = step.dataAsMap;
      if (data != null) {
        final monitorData = TrlMonitorAtkData.fromJson(data);
        allData.addAll({
          'trlMonitorSent': monitorData.sent,
          'trlMonitorTransaccion': monitorData.transaccion,
          'trlMonitorTipoMov': monitorData.tipoMov,
          'trlMonitorBarrera': monitorData.barrera,
          'trlMonitorFechaBarrera': monitorData.fechaBarrera,
        });
      }
    }

    // ───────────────────────────────────────────────
    // 🔹 3) Procesar UI Hints
    // ───────────────────────────────────────────────
    final uiHints = model.data?.uiHints ?? [];
    for (final hint in uiHints) {
      if (hint.key == 'panel.contenedor2.visible') {
        allData['trlShowContenedor2'] = hint.value as bool?;
      }
    }

    // ───────────────────────────────────────────────
    // 🔹 4) Guardar número de transacción principal
    // ───────────────────────────────────────────────
    final numero = model.data?.numero;
    if (numero != null && !allData.containsKey('atkId')) {
      allData['atkId'] = numero.toString();
    }

    // ✅ Un solo notifyListeners
    manager.setMany(allData);
  }
}
