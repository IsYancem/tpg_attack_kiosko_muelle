// lib/services/apis/dspcs_service.dart
// OPTIMIZADO 2025-12-09 - Con mensajes de progreso (200ms cada paso)
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tpg_attack_kiosko_muelle/models/dspcs/dspcs_transaccion_request_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/dspcs/dspcs_transaccion_response_model.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/secure_storage_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/authApi_service.dart';

class DspCsServiceException implements Exception {
  final String message;
  DspCsServiceException(this.message);
  @override
  String toString() => message;
}

class DspCsService {
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

  Future<DspCsTransaccionResponseModel> ejecutarTransaccionDspCs(
    DspCsTransaccionRequestModel req,
    AtkTransactionManager manager,
  ) async {
    final sw = Stopwatch()..start();

    final baseUrl = dotenv.env['BASE_MIDDLEWARE_URL'] ?? '';
    if (baseUrl.isEmpty) {
      throw DspCsServiceException('BASE_MIDDLEWARE_URL no configurada');
    }

    final url = '${baseUrl}kiosk/api/dspcs/transaccion';

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
        throw DspCsServiceException('HTTP ${response.statusCode}');
      }

      // ═══════════════════════════════════════════════════════════════
      // PASO 3: Procesando respuesta
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '📦 Procesando respuesta del servidor...');

      final jsonData = json.decode(response.body) as Map<String, dynamic>;
      final model = DspCsTransaccionResponseModel.fromJson(jsonData);

      // ═══════════════════════════════════════════════════════════════
      // PASO 4: Validando ponchado
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '✅ Validando datos de ponchado...');

      // ═══════════════════════════════════════════════════════════════
      // PASO 5: Procesando DRES
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '📋 Procesando documentos DRES...');

      // ═══════════════════════════════════════════════════════════════
      // PASO 6: Registrando transacción
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '📝 Registrando transacción DSP-CS...');

      // ═══════════════════════════════════════════════════════════════
      // PASO 7: Aplicando datos
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '💾 Guardando información...');

      _handleResponse(model, manager);

      // Log resumido
      _log.logRequest('DSPCS_COMPLETE', {
        'latency_ms': sw.elapsedMilliseconds,
        'errorCode': model.errorCode,
      });

      return model;
    } catch (e, st) {
      _log.logError('DSPCS_SERVICE_EX', e, st);
      manager.setError('Error ejecutando servicio DSP-CS: $e');
      rethrow;
    }
  }

  void _handleResponse(
    DspCsTransaccionResponseModel model,
    AtkTransactionManager manager,
  ) {
    final allData = <String, dynamic>{
      'metadataElapsedMs': model.data?.elapsedMs,
    };

    // ───────────────────────────────────────────────
    // 🔹 1) Verificar error global
    // ───────────────────────────────────────────────
    if (model.errorCode != 0) {
      String detalle = model.message.isNotEmpty
          ? model.message
          : 'Error general en servicio DSP-CS';

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
        'tituloPantalla': 'Error en Transacción DSP-CS',
      });
      manager.setMany(allData);
      return;
    }

    // ───────────────────────────────────────────────
    // 🔹 2) Procesar cada servicio
    // ───────────────────────────────────────────────
    final services = model.data?.services ?? {};

    // Ponchado
    if (services.containsKey('ponchado')) {
      final step = services['ponchado']!;
      final data = step.dataAsMap;
      if (step.errorCode == 0 && data != null) {
        final ponchado = DspCsPonchadoData.fromJson(data);
        allData.addAll({
          'importador': ponchado.importador ?? '',
          'turno': ponchado.turno?.toString() ?? '',
          'ponchadoCodChofer': ponchado.codChofer,
          'ponchadoCargaSuelta': ponchado.cargaSuelta,
          'ponchadoPatio': ponchado.patio,
          'ponchadoAniodres1': ponchado.aniodres1,
          'ponchadoCordres1': ponchado.cordres1,
          'ponchadoAniodres2': ponchado.aniodres2,
          'ponchadoCordres2': ponchado.cordres2,
          'ponchadoPesoBultos': ponchado.pesoBultos,
          'ponchadoTotalBultos': ponchado.totalBultos,
          'ponchadoNumregAtk': ponchado.numregAtk,
          'ponchadoCargaNoPesable': ponchado.cargaNoPesable,
          'ponchadoFechaProgramado': ponchado.fechaProgramado,
        });
      }
    }

    // Validar peso
    if (services.containsKey('validar_peso')) {
      final step = services['validar_peso']!;
      final data = step.dataAsMap;
      if (data != null) {
        final validarPeso = DspCsValidarPesoData.fromJson(data);
        allData.addAll({
          'validarPesoRecibido': validarPeso.peso,
          'validarPesoEsValido': validarPeso.valid,
        });
      }
    }

    // Transacción EXP
    if (services.containsKey('transaccion_exp')) {
      final step = services['transaccion_exp']!;
      final data = step.dataAsMap;
      if (step.errorCode == 0 && data != null) {
        final transExp = DspCsTransaccionExpData.fromJson(data);
        if (transExp.numero != null) {
          allData['atkId'] = transExp.numero.toString();
        }
      }
    }

    // DRES Cons (lista de DRES)
    if (services.containsKey('dres_cons')) {
      final step = services['dres_cons']!;
      final dataList = step.dataAsList;
      if (step.errorCode == 0 && dataList != null && dataList.isNotEmpty) {
        final firstDres = DspCsDresConsItem.fromJson(
          dataList.first as Map<String, dynamic>,
        );
        allData.addAll({
          'dres': '${firstDres.anodres ?? ''}-${firstDres.cordres ?? ''}',
          'ponchadoAniodres1': firstDres.anodres,
          'ponchadoCordres1': firstDres.cordres,
        });

        if (dataList.length > 1) {
          final secondDres = DspCsDresConsItem.fromJson(
            dataList[1] as Map<String, dynamic>,
          );
          allData.addAll({
            'ponchadoAniodres2': secondDres.anodres,
            'ponchadoCordres2': secondDres.cordres,
          });
        }
      }
    }

    // Barrera Unlock
    if (services.containsKey('barrera_unlock')) {
      final step = services['barrera_unlock']!;
      if (step.dataAsMap != null) {
        allData['barreraUnlocked'] = step.errorCode == 0;
      }
    }

    // ───────────────────────────────────────────────
    // 🔹 3) Guardar número de transacción principal
    // ───────────────────────────────────────────────
    final numero = model.data?.numero;
    if (numero != null && !allData.containsKey('atkId')) {
      allData['atkId'] = numero.toString();
    }

    // ✅ Un solo notifyListeners
    manager.setMany(allData);
  }
}
