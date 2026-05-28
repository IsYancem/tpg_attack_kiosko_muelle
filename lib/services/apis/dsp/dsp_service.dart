// lib/services/apis/dsp_service.dart
// OPTIMIZADO 2025-12-09 - Con mensajes de progreso (200ms cada paso)
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tpg_attack_kiosko_muelle/models/dsp/dsp_transaccion_response_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/dsp/dsp_transaccion_request_model.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/image_cache_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/secure_storage_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/authApi_service.dart';

class DspServiceException implements Exception {
  final String message;
  DspServiceException(this.message);
  @override
  String toString() => message;
}

class DspService {
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

  Future<DspTransaccionResponseModel> ejecutarTransaccionDsp(
    DspTransaccionRequestModel req,
    AtkTransactionManager manager,
  ) async {
    final sw = Stopwatch()..start();

    final baseUrl = dotenv.env['BASE_MIDDLEWARE_URL'] ?? '';
    if (baseUrl.isEmpty) {
      throw DspServiceException('BASE_MIDDLEWARE_URL no configurada');
    }

    final url = '${baseUrl}kiosk/api/dsp/transaccion';

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
        throw DspServiceException('HTTP ${response.statusCode}');
      }

      // ═══════════════════════════════════════════════════════════════
      // PASO 3: Procesando respuesta
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '📦 Procesando respuesta del servidor...');

      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      final model = DspTransaccionResponseModel.fromJson(jsonData);

      // ═══════════════════════════════════════════════════════════════
      // PASO 4: Validando datos de ponchado
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '✅ Validando datos de ponchado...');

      // ═══════════════════════════════════════════════════════════════
      // PASO 5: Registrando transacción
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '📝 Registrando transacción DSP...');

      // ═══════════════════════════════════════════════════════════════
      // PASO 6: Aplicando datos
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '💾 Guardando información...');

      _applyResponseToManager(model, manager);

      // Log resumido
      _log.logRequest('DSP_COMPLETE', {
        'latency_ms': sw.elapsedMilliseconds,
        'errorCode': model.errorCode,
      });

      return model;
    } catch (e, st) {
      _log.logError('DSP_SERVICE_EX', e, st);
      manager.setError('Error ejecutando servicio DSP: $e');
      rethrow;
    }
  }

  void _applyResponseToManager(
    DspTransaccionResponseModel model,
    AtkTransactionManager manager,
  ) {
    final meta = model.data?.metadata;
    final services = model.data?.services ?? {};

    final allData = <String, dynamic>{
      'metadataElapsedMs': meta?.elapsedMs,
      'metadataTotalSteps': meta?.totalSteps,
      'metadataSuccessfulSteps': meta?.successfulSteps,
      'metadataFailures': meta?.failures ?? const <String>[],
    };

    // Error global
    if (model.errorCode != 0) {
      var detalle = model.message.isNotEmpty
          ? model.message
          : 'Error general en servicio DSP';

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
            break;
          }
        }
      }

      allData.addAll({
        'hasError': true,
        'errorMessage': detalle,
        'mensajeInferior': detalle,
        'tituloPantalla': 'Error en Transacción DSP',
      });
      manager.setMany(allData);
      return;
    }

    // Procesar servicios
    _processPonchado(services, allData);
    _processPeso(services, allData);
    _processTransaccion(model, services, allData);
    _processContenedor(services, allData);

    // ✅ Un solo notifyListeners
    manager.setMany(allData);

    // Mapa diferido
    _loadMapaAsync(services, manager);
  }

  void _processPonchado(
    Map<String, dynamic> services,
    Map<String, dynamic> allData,
  ) {
    final step = services['ponchado'];
    if (step == null) return;
    final data = step.data;
    if (step.errorCode != 0 || data == null) return;

    allData.addAll({
      'importador': data['importador']?.toString() ?? '',
      'ubicacion': data['ubicacion']?.toString() ?? '',
      'turno': data['turno']?.toString() ?? '',
      'contenedor1': data['contenedor1']?.toString() ?? '',
      'contenedor2': data['contenedor2']?.toString() ?? '',
      'ponchadoCodChofer': (data['cod_chofer'] as num?)?.toInt(),
      'ponchadoCargaSuelta': data['carga_suelta']?.toString(),
      'ponchadoPatio': (data['patio'] as num?)?.toInt(),
      'ponchadoAniodres1': (data['aniodres1'] as num?)?.toInt(),
      'ponchadoCordres1': (data['cordres1'] as num?)?.toInt(),
      'ponchadoAniodres2': (data['aniodres2'] as num?)?.toInt(),
      'ponchadoCordres2': (data['cordres2'] as num?)?.toInt(),
      'ponchadoPesoBultos': (data['peso_bultos'] as num?)?.toDouble(),
      'ponchadoTotalBultos': (data['total_bultos'] as num?)?.toInt(),
      'ponchadoNumregAtk': (data['numreg_atk'] as num?)?.toInt(),
      'ponchadoCargaNoPesable': (data['carga_no_pesable'] as num?)?.toInt(),
      'ponchadoDai': data['dai']?.toString(),
      'ponchadoPonchadoWeb': data['ponchado_web']?.toString(),
      'ponchadoFechaProgramado': data['fecha_programado']?.toString(),
    });
  }

  void _processPeso(
    Map<String, dynamic> services,
    Map<String, dynamic> allData,
  ) {
    final step = services['validar_peso'];
    if (step == null) return;
    final data = step.data;
    if (data == null) return;

    allData.addAll({
      'validarPesoRecibido': (data['pesoRecibido'] as num?)?.toDouble(),
      'validarPesoValidado': (data['pesoValidado'] as num?)?.toDouble(),
      'validarPesoParseado': (data['pesoParseado'] as num?)?.toDouble(),
      'validarPesoEsValido': data['esValido'] as bool?,
    });
  }

  void _processTransaccion(
    DspTransaccionResponseModel model,
    Map<String, dynamic> services,
    Map<String, dynamic> allData,
  ) {
    final step = services['transaccion_dsp'];
    if (step == null || step.errorCode != 0) return;
    final numero = model.data?.numero;
    if (numero != null) {
      allData['atkId'] = numero.toString();
    }
  }

  void _processContenedor(
    Map<String, dynamic> services,
    Map<String, dynamic> allData,
  ) {
    final step = services['cons_contenedor_x_dres'];
    if (step == null) return;
    final data = step.data;
    if (data == null) return;

    allData.addAll({
      'consCntCodError': (data['codError'] as num?)?.toInt(),
      'consCntDesError': data['desError']?.toString(),
      'consCntAnoOperacion': (data['ano_operacion'] as num?)?.toInt(),
      'consCntCorOperacion': (data['cor_operacion'] as num?)?.toInt(),
      'consCntCodSigla': data['cod_sigla']?.toString(),
      'consCntCodNumero': (data['cod_numero'] as num?)?.toInt(),
      'consCntCodDigito': data['cod_digito']?.toString(),
      'consCntUbicacion': data['ubicacion']?.toString(),
    });
  }

  /// ✅ Carga el mapa con caché (solo si NO es not_found)
  void _loadMapaAsync(
    Map<String, dynamic> services,
    AtkTransactionManager manager,
  ) {
    final step = services['mapa'];
    if (step == null || step.errorCode != 0) return;

    final ruta = step.data?['ruta'] as String?;
    if (ruta == null || ruta.isEmpty) return;

    // ✅ Si contiene "not_found", no hacer nada (mantener imagen default)
    if (ruta.contains('not_found')) {
      print('🗺️ [DSP_MAPA] URL contiene not_found, usando imagen default');
      return;
    }

    // ✅ Guardar URL en manager
    manager.setManyWithoutNotify({'mapaUrl': ruta});

    // ✅ Cargar imagen con caché (fire-and-forget pero con notificación)
    Future.microtask(() async {
      try {
        final bytes = await ImageCacheService.instance.getImage(ruta);
        if (bytes != null) {
          manager.setManyWithoutNotify({
            'mapaBytes': bytes,
            'mapaUbicacion': MemoryImage(
              bytes,
            ), 
          });
        }
      } catch (e) {
        print('❌ [DSP_MAPA] Error cargando mapa: $e');
      }
    });
  }
}
