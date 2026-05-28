// lib/services/apis/facial_service.dart
// Autor: Abraham Yance
// Fecha: 2025-12-09 (OPTIMIZADO)
// Descripción: Servicio facial OPTIMIZADO
//  - Cache de headers (4 minutos)
//  - Logs mínimos y no bloqueantes
//  - setMany para reducir notifyListeners
//  - Timing logs para diagnóstico

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tpg_attack_kiosko_muelle/models/facial/facial_request_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/facial/facial_response_model.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/secure_storage_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/authApi_service.dart';

class FacialServiceException implements Exception {
  final String message;
  FacialServiceException(this.message);
  @override
  String toString() => message;
}

class FacialService {
  final _log = LogService.instance;

  // ✅ Cache de headers para evitar SecureStorage en cada request
  static Map<String, String>? _cachedHeaders;
  static DateTime? _headersCacheTime;
  static const _headersCacheDuration = Duration(minutes: 4);

  /// ✅ Headers con cache
  Future<Map<String, String>> _authHeaders() async {
    // Usar cache si está válido
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

    // Guardar en cache
    _cachedHeaders = headers;
    _headersCacheTime = DateTime.now();

    return headers;
  }

  /// ✅ Invalidar cache (llamar después de refresh)
  static void invalidateHeadersCache() {
    _cachedHeaders = null;
    _headersCacheTime = null;
  }

  /// ✅ POST con auto-refresh optimizado
  Future<http.Response> _postWithAutoRefresh(
    Uri uri, {
    required String body,
    required String tag,
  }) async {
    var headers = await _authHeaders();

    var res = await http
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 30));

    // Token refresh si es necesario
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

  /// ✅ Ejecutar flujo facial OPTIMIZADO
  Future<FacialResponseModel> ejecutarFacial(
    FacialRequestModel req,
    AtkTransactionManager manager,
  ) async {
    final sw = Stopwatch()..start();

    final baseUrl = dotenv.env['BASE_MIDDLEWARE_URL'] ?? '';
    if (baseUrl.isEmpty) {
      throw FacialServiceException('BASE_MIDDLEWARE_URL no configurada');
    }

    final uri = Uri.parse('${baseUrl}kiosk/api/facial/validarTransaccion');

    manager.clearError();

    try {
      // ═══════════════════════════════════════════════════════════════
      // PASO 1: Preparar body
      // ═══════════════════════════════════════════════════════════════
      final bodyJson = json.encode(req.toJson());

      // ═══════════════════════════════════════════════════════════════
      // PASO 2: HTTP POST
      // ═══════════════════════════════════════════════════════════════
      final resp = await _postWithAutoRefresh(
        uri,
        body: bodyJson,
        tag: 'FACIAL',
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        final msg = 'HTTP ${resp.statusCode}';
        manager.setError(msg);
        throw FacialServiceException(msg);
      }

      // ═══════════════════════════════════════════════════════════════
      // PASO 3: Parse JSON
      // ═══════════════════════════════════════════════════════════════
      final decoded =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
      final model = FacialResponseModel.fromJson(decoded);

      // ═══════════════════════════════════════════════════════════════
      // PASO 4: Aplicar respuesta
      // ═══════════════════════════════════════════════════════════════
      _handleResponse(model, manager);

      // ✅ Log resumido (fire-and-forget, sin await)
      _log.logRequest('FACIAL_COMPLETE', {
        'latency_ms': sw.elapsedMilliseconds,
        'errorCode': model.errorCode,
      });

      return model;
    } catch (e, st) {
      _log.logError('FACIAL_SERVICE_EX', e, st);

      String cleanMsg = e
          .toString()
          .replaceAll(RegExp(r'(?i)Exception[:\- ]*'), '')
          .replaceAll(RegExp(r'(?i)error[:\- ]*'), '')
          .trim();

      if (cleanMsg.isEmpty) cleanMsg = 'Error en el servicio facial.';

      manager.setError(cleanMsg);
      rethrow;
    }
  }

  /// ✅ Procesar respuesta con setMany (un solo notifyListeners)
  void _handleResponse(
    FacialResponseModel model,
    AtkTransactionManager manager,
  ) {
    // ───────────────────────────────────────────────
    // 1) Error global
    // ───────────────────────────────────────────────
    if (model.errorCode != 0) {
      StepEnvelope? spFallido;
      String? nombreSp;

      model.services.forEach((k, v) {
        if (spFallido == null && v.errorCode != 0) {
          spFallido = v;
          nombreSp = k;
        }
      });

      final detalle = spFallido?.spMessage?.isNotEmpty == true
          ? spFallido!.spMessage!
          : spFallido?.message ?? model.message;

      final msgFinal = nombreSp != null
          ? detalle
          : (model.message.isNotEmpty
                ? model.message
                : 'Error general en facial');

      manager.setMany({
        'hasError': true,
        'errorMessage': msgFinal,
        'mensajeInferior': msgFinal,
        'tituloPantalla': nombreSp != null ? 'Fallo en $nombreSp' : 'Error',
      });
      return;
    }

    // ───────────────────────────────────────────────
    // 2) Buscar SP fallido específico
    // ───────────────────────────────────────────────
    StepEnvelope? spFallido;
    String? nombreSp;

    model.services.forEach((k, v) {
      if (spFallido == null && v.errorCode == 1) {
        spFallido = v;
        nombreSp = k;
      }
    });

    // ───────────────────────────────────────────────
    // 3) Datos del chofer
    // ───────────────────────────────────────────────
    final choferStep = model['getChofer'];
    final choferData = choferStep?.data ?? {};

    final allData = <String, dynamic>{};

    if (choferData.isNotEmpty) {
      final idNumber = choferData['IDENTIFICATIONNUMBER']?.toString() ?? '';
      final idChofer = choferData['ID']?.toString() ?? '';
      final firstName = choferData['FIRSTNAME'] ?? '';
      final lastName = choferData['LASTNAME'] ?? '';
      final empresa = choferData['NAME'] ?? choferData['COMPANY'] ?? '';
      final licenciaTipo = choferData['LICENCETYPE'] ?? '';
      final licenciaExp = choferData['LICENSEEXPIRATIONDATE'] ?? '';
      final fotoUrl = choferData['FACE_URL'] ?? '';
      final fullName = '$firstName $lastName'.trim();

      allData.addAll({
        'driverId': idChofer,
        'driverCedula': idNumber,
        'driverName': fullName,
        'driverEmpresa': empresa,
        'driverLicenciaExp': licenciaExp,
        'driverLicenciaTipo': licenciaTipo,
        'driverPhotoUrl': fotoUrl,
        'tituloPantalla': 'Chofer: $fullName',
      });
    }

    // ───────────────────────────────────────────────
    // 4) SP fallido → error
    // ───────────────────────────────────────────────
    if (spFallido != null) {
      final msg = spFallido!.spMessage?.isNotEmpty == true
          ? spFallido!.spMessage!
          : spFallido!.message;

      allData.addAll({
        'hasError': true,
        'errorMessage': msg,
        'mensajeInferior': 'Error en $nombreSp: $msg',
        'tituloPantalla': 'Fallo en $nombreSp',
      });

      manager.setMany(allData);
      return;
    }

    // ───────────────────────────────────────────────
    // 5) Validar transacciones pendientes
    // ───────────────────────────────────────────────
    final pendienteStep = model['getPendiente'];
    if (pendienteStep != null) {
      final spErr = pendienteStep.spErrorCode ?? 0;
      final spMsg = pendienteStep.spMessage ?? pendienteStep.message;

      if (spErr > 0) {
        allData.addAll({
          'hasError': true,
          'errorMessage': spMsg,
          'mensajeInferior': spMsg,
          'tituloPantalla': 'Transacción Pendiente',
        });

        manager.setMany(allData);
        return;
      }
    }

    // ───────────────────────────────────────────────
    // ✅ 6) OK
    // ───────────────────────────────────────────────
    allData.addAll({
      'hasError': false,
      'errorMessage': null,
      'mensajeInferior': 'Chofer validado correctamente',
    });

    // ✅ Un solo notifyListeners
    manager.setMany(allData);
  }
}
