// lib/services/apis/confirm_service.dart
// Autor: Abraham Yance
// Fecha: 2025-12-09 (OPTIMIZADO)
// Descripción: Servicio Confirm OPTIMIZADO
//  - Cache de headers compartido con FacialService
//  - Logs mínimos y no bloqueantes
//  - setMany para reducir notifyListeners
//  - Timing logs para diagnóstico

import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tpg_attack_kiosko_muelle/models/confirm/confirm_response_model.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/secure_storage_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/authApi_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/windows_user_service.dart';

class ConfirmServiceException implements Exception {
  final String message;
  ConfirmServiceException(this.message);
  @override
  String toString() => message;
}

class ConfirmService {
  final _log = LogService.instance;

  // ? Cache de headers (compartido a nivel de clase)
  static Map<String, String>? _cachedHeaders;
  static DateTime? _headersCacheTime;
  static const _headersCacheDuration = Duration(minutes: 4);

  /// ? Headers con cache
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

    _cachedHeaders = headers;
    _headersCacheTime = DateTime.now();

    return headers;
  }

  /// ? Invalidar cache
  static void invalidateHeadersCache() {
    _cachedHeaders = null;
    _headersCacheTime = null;
  }

  /// ? POST con auto-refresh optimizado
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

  /// ? Ejecutar transacción Confirm OPTIMIZADO con LOGS DETALLADOS
  Future<Map<String, dynamic>> ejecutarConfirm(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) async {
    final sw = Stopwatch()..start();

    final baseUrl = dotenv.env['BASE_MIDDLEWARE_URL'] ?? '';
    if (baseUrl.isEmpty) {
      throw ConfirmServiceException('BASE_MIDDLEWARE_URL no configurada');
    }

    final uri = Uri.parse('${baseUrl}kiosk/api/confirm/transaccion');
    manager.clearError();

    final winUser = WindowsUserService.instance.getUserInfo()['username'] ?? 'Unknown';

    try {
      // ---------------------------------------------------------------
      // PASO 1: Preparar body
      // ---------------------------------------------------------------
      final body = {
        "placa": manager.vehiculoPlaca ?? "",
        "choferIdentificacion": manager.driverCedula ?? "",
        "pesoin": manager.pesoActualBascula,
        "device": appManager.kioskConfig!.gate,
        "kioskServer": appManager.kioskConfig!.kioskServer,
        "kioskPort": appManager.kioskConfig!.kioskServerPort,
        "usuario_nombre": winUser,
      };

      final bodyJson = json.encode(body);

      _log.logRequest('CONFIRM_FULL_REQUEST', {
        'url': uri.toString(),
        'method': 'POST',
        'body': body,
        'bodyJson': bodyJson,
      });

      final resp = await _postWithAutoRefresh(
        uri,
        body: bodyJson,
        tag: 'CONFIRM',
      );

      _log.logRequest('CONFIRM_FULL_HTTP_RESPONSE', {
        'statusCode': resp.statusCode,
        'headers': resp.headers,
        'rawBody': utf8.decode(resp.bodyBytes),
      });

      // ---------------------------------------------------------------
      // PASO 3: Validar y parsear respuesta
      // ---------------------------------------------------------------
      if (resp.statusCode != 200 && resp.statusCode != 201) {
        final msg = 'HTTP ${resp.statusCode}';
        manager.setError(msg);
        throw ConfirmServiceException(msg);
      }

      final decoded =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

      _log.logRequest('CONFIRM_FULL_RESPONSE_DECODED', {
        'elapsedMs': sw.elapsedMilliseconds,
        'decoded': decoded,
      });

      // ---------------------------------------------------------------
      // PASO 4: Aplicar respuesta (flujo de COLA, sí usa _handleResponse)
      // ---------------------------------------------------------------
      final model = ConfirmResponseModel.fromJson(decoded);
      _handleResponse(model, manager);

      // ? Log resumido final (fire-and-forget)
      _log.logRequest('CONFIRM_COMPLETE', {
        'latency_ms': sw.elapsedMilliseconds,
        'errorCode': model.errorCode,
        'numero': model.numero,
      });

      return decoded;
    } catch (e, st) {
      _log.logError('CONFIRM_SERVICE_EX', e, st);
      manager.setError('Error ejecutando servicio Confirm: $e');
      print('? [CONFIRM_SERVICE] ERROR: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> ejecutarConfirmMuelle(
    AtkTransactionManager manager,
    AppStateManager appManager,
    String tipoMov,
  ) async {
    final sw = Stopwatch()..start();

    final baseUrl = dotenv.env['BASE_MIDDLEWARE_URL'] ?? '';
    if (baseUrl.isEmpty) {
      throw ConfirmServiceException('BASE_MIDDLEWARE_URL no configurada');
    }

    final cleanTipoMov = tipoMov.trim().toUpperCase();
    final uri = Uri.parse('${baseUrl}kiosk/api/confirm-muelle/$cleanTipoMov');

    manager.clearError();

    final winUser = WindowsUserService.instance.getUserInfo()['username'] ?? 'Unknown';

    try {
      final movementActive = manager.get('movement_active');
      final ocrMovementActive = manager.get('ocrMovementActive');

      final atkId = _toInt(
        manager.get('atkId') ??
            _mapValue(movementActive, 'id') ??
            _mapValue(ocrMovementActive, 'id'),
      );

      final numTran = _toInt(
        manager.get('numTran')
      );

      final doorNumber = _toInt(
        manager.get('doorNumber') ??
            manager.get('side') ??
            manager.get('sideGate'),
      );

      final bascula = _toInt(appManager.kioskConfig?.gate);

      // ?? FIX: placa resiliente. Antes el confirm anterior dejaba
      // vehiculoPlaca = '' (por _handleResponse) y el segundo confirm
      // mandaba "placa":"". Ahora se resuelve con fallback.
      final body = {
        "placa": _resolvePlaca(manager),
        "choferIdentificacion": manager.driverCedula ?? "",
        "atk_id": atkId,
        "numTran": numTran,
        "door_number": doorNumber,
        "bascula": bascula,
        "pesoin": manager.pesoActualBascula,
        "device": appManager.kioskConfig!.gate,
        "kioskServer": appManager.kioskConfig!.kioskServer,
        "kioskPort": appManager.kioskConfig!.kioskServerPort,
        "usuario_nombre": winUser,
      };

      final bodyJson = json.encode(body);

      _log.logRequest('CONFIRM_MUELLE_FULL_REQUEST', {
        'url': uri.toString(),
        'method': 'POST',
        'tipoMov': cleanTipoMov,
        'body': body,
        'bodyJson': bodyJson,
      });

      final resp = await _postWithAutoRefresh(
        uri,
        body: bodyJson,
        tag: 'CONFIRM_MUELLE_$cleanTipoMov',
      );

      final rawBody = utf8.decode(resp.bodyBytes);

      _log.logRequest('CONFIRM_MUELLE_FULL_HTTP_RESPONSE', {
        'statusCode': resp.statusCode,
        'headers': resp.headers,
        'rawBody': rawBody,
      });

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        final msg = 'HTTP ${resp.statusCode}';
        manager.setError(msg);

        _log.logRequest('CONFIRM_MUELLE_FULL_HTTP_ERROR', {
          'statusCode': resp.statusCode,
          'body': rawBody,
          'elapsedMs': sw.elapsedMilliseconds,
        });

        throw ConfirmServiceException(msg);
      }

      final decoded = json.decode(rawBody) as Map<String, dynamic>;

      _log.logRequest('CONFIRM_MUELLE_FULL_RESPONSE_DECODED', {
        'elapsedMs': sw.elapsedMilliseconds,
        'decoded': decoded,
      });

      final model = ConfirmResponseModel.fromJson(decoded);

      // ?? FIX CRÍTICO: confirm-muelle NO trae getCola. Antes _handleResponse
      // leía un getCola vacío y sobrescribía placa/atkId/contenedor/sellos/
      // tipoCarga con strings vacíos, y caía en _handleDspTrlTransaction.
      // Aquí solo validamos errores. El DISV se extrae aparte
      // (OcrScannerScreen._applyDiSvFromConfirmRaw / runner._aplicarDisvDesdeConfirm).
      _handleMuelleErrorsOnly(model, manager);

      _log.logRequest('CONFIRM_MUELLE_COMPLETE', {
        'latency_ms': sw.elapsedMilliseconds,
        'errorCode': model.errorCode,
        'numero': model.numero,
        'tipoMov': cleanTipoMov,
        'atkId': atkId,
        'numTran': numTran,
        'doorNumber': doorNumber,
        'bascula': bascula,
      });

      return decoded;
    } catch (e, st) {
      _log.logError('CONFIRM_MUELLE_SERVICE_EX', e, st);
      manager.setError('Error ejecutando servicio Confirm Muelle: $e');
      rethrow;
    }
  }

  // ?? NUEVO: resuelve la placa con varios fallbacks (incluye movement_active).
  String _resolvePlaca(AtkTransactionManager manager) {
    final candidates = <dynamic>[
      manager.vehiculoPlaca,
      manager.get('placa'),
      manager.get('rfidPlaca'),
      manager.conseguirConductorPlaca,
      _mapValue(manager.get('movement_active'), 'placa'),
    ];
    for (final c in candidates) {
      final s = (c ?? '').toString().trim().toUpperCase();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  // ?? NUEVO: solo valida errores de confirm-muelle, sin tocar datos.
  void _handleMuelleErrorsOnly(
    ConfirmResponseModel model,
    AtkTransactionManager manager,
  ) {
    // 1) Error global
    if (model.errorCode != 0) {
      String? detalle;
      for (final entry in model.services.entries) {
        final sp = entry.value;
        if (sp.errorCode == 1) {
          if (sp.spMessage != null && sp.spMessage!.isNotEmpty) {
            detalle = sp.spMessage;
          } else if (sp.message.isNotEmpty) {
            detalle = sp.message;
          } else if (sp.data != null) {
            final dataMap = _tryConvertToMap(sp.data);
            if (dataMap != null) {
              detalle =
                  dataMap['des_error'] ??
                  dataMap['msg_error'] ??
                  dataMap['message'];
            }
          }
          break;
        }
      }

      final msg = detalle?.isNotEmpty == true
          ? 'Error: $detalle'
          : (model.message.isNotEmpty
                ? model.message
                : 'Error global en Confirm Muelle');

      manager.setMany({
        'hasError': true,
        'errorMessage': msg,
        'mensajeInferior': msg,
        'tituloPantalla': 'Error en Confirmación',
      });
      return;
    }

    // 2) SP específico fallido (errorCode == 1)
    StepEnvelope? spFallido;
    model.services.forEach((k, v) {
      if (v.errorCode == 1 && spFallido == null) {
        spFallido = v;
      }
    });

    if (spFallido != null) {
      final msg = spFallido!.spMessage ?? spFallido!.message;
      manager.setMany({
        'hasError': true,
        'errorMessage': msg,
        'mensajeInferior': msg,
        'tituloPantalla': 'Error en Confirmación',
      });
      return;
    }

    // 3) OK: no se sobrescribe nada (placa, atkId, contenedor, DISV).
    manager.clearError();
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  dynamic _mapValue(dynamic source, String key) {
    if (source is Map<String, dynamic>) return source[key];
    if (source is Map) return source[key];
    return null;
  }

  void _handleResponse(
    ConfirmResponseModel model,
    AtkTransactionManager manager,
  ) {
    // -----------------------------------------------
    // 1) Verificar error global
    // -----------------------------------------------
    if (model.errorCode != 0) {
      String? mensajeDetallado;

      if (model.services.isNotEmpty) {
        for (final entry in model.services.entries) {
          final sp = entry.value;
          if (sp.errorCode == 1) {
            // ?? PRIORIDAD 1: spMessage del SP
            if (sp.spMessage != null && sp.spMessage!.isNotEmpty) {
              mensajeDetallado = sp.spMessage;
            }
            // ?? PRIORIDAD 2: message del envelope
            else if (sp.message.isNotEmpty) {
              mensajeDetallado = sp.message;
            }
            // ?? PRIORIDAD 3: data del SP si contiene mensaje
            else if (sp.data != null) {
              // Intentar extraer mensaje del data
              final dataMap = _tryConvertToMap(sp.data);
              if (dataMap != null) {
                mensajeDetallado =
                    dataMap['des_error'] ??
                    dataMap['msg_error'] ??
                    dataMap['message'];
              }
            }
            break;
          }
        }
      }

      final msg = mensajeDetallado?.isNotEmpty == true
          ? 'Error: $mensajeDetallado'
          : (model.message.isNotEmpty
                ? model.message
                : 'Error global en Confirm');

      manager.setMany({
        'hasError': true,
        'errorMessage': msg,
        'mensajeInferior': msg,
        'tituloPantalla': 'Error en Confirmación',
      });
      return;
    }

    // -----------------------------------------------
    // 2) SP específico fallido
    // -----------------------------------------------
    StepEnvelope? spFallido;

    model.services.forEach((k, v) {
      if (v.errorCode == 1 && spFallido == null) {
        spFallido = v;
      }
    });

    if (spFallido != null) {
      final msg = spFallido!.spMessage ?? spFallido!.message;

      manager.setMany({
        'hasError': true,
        'errorMessage': msg,
        'mensajeInferior': msg,
        'tituloPantalla': 'Error en Confirmación',
      });
      return;
    }

    // -----------------------------------------------
    // 3) Extraer datos de la cola (FIX: desde services)
    // -----------------------------------------------
    final getCola = model.services['getCola'];
    final cola = getCola?.dataAsMap ?? {};

    final tipoMov = (cola['tipo_mov'] ?? '').toString().trim();
    final atkId = (cola['atk_id'] ?? model.numero ?? '').toString().trim();
    final placa = (cola['placa'] ?? '').toString().trim();

    // ? (opcional) título humano desde catalogoTitulo
    final catalogo = model.services['catalogoTitulo']?.dataAsMap ?? {};
    final tituloHumano = (catalogo['title'] ?? '').toString().trim();

    final baseData = <String, dynamic>{
      'transactionType': tipoMov,
      'atkId': atkId,
      'vehiculoPlaca': placa,
      'tituloPantalla': tituloHumano.isNotEmpty ? tituloHumano : tipoMov,
      'hasError': false,
      'errorMessage': null,
    };

    // -----------------------------------------------
    // 4) Manejar según tipo de transacción
    // -----------------------------------------------
    if (tipoMov == 'EXP') {
      _handleExpTransaction(model, manager, baseData, cola);
    } else if (tipoMov == 'RES') {
      _handleResTransaction(model, manager, baseData, cola);
    } else if (tipoMov == 'EXM' || tipoMov == 'XMD') {
      _handleExmTransaction(model, manager, baseData, cola);
    } else {
      _handleDspTrlTransaction(model, manager, baseData, cola);
    }
  }

  void _handleExmTransaction(
    ConfirmResponseModel model,
    AtkTransactionManager manager,
    Map<String, dynamic> baseData,
    Map<String, dynamic> cola,
  ) {
    final servicios = model.services;

    final permisos = servicios['atkPaConsPermisosVaciosEx']?.dataAsMap ?? {};
    final pendientes = servicios['consultaTransPendientes']?.dataAsMap ?? {};
    final decisionMsg = (servicios['decisionExm']?.message ?? '')
        .toString()
        .trim();

    final ruc = (cola['cedula'] ?? '').toString().trim();
    final cont = (cola['contenedor1'] ?? '').toString().trim();

    final countPen = pendientes['countPen'];
    final numTran1 = pendientes['numTranPen1'];
    final tara1 = pendientes['taraPen1'];
    final pesoIng1 = pendientes['pesoIngPen'];
    final pesa = (pendientes['pesa'] ?? '').toString().trim();
    final fechaIng1 = (pendientes['fechaIng1'] ?? '').toString().trim();

    final msgInferior = [
      'EXM confirmado (#${baseData['atkId']})',
      if (countPen != null) 'Pendientes=$countPen',
      if (numTran1 != null) 'NumTran1=$numTran1',
      if (pesa.isNotEmpty) 'Pesa=$pesa',
      if (fechaIng1.isNotEmpty) 'FechaIng1=$fechaIng1',
      if (decisionMsg.isNotEmpty) decisionMsg,
    ].join(' | ');

    manager.setMany({
      ...baseData,
      'driverCedula': ruc,
      'vehiculoPlaca': (cola['placa'] ?? '').toString().trim(),
      'contenedor1': cont,
      'contenedor2': (cola['contenedor2'] ?? '').toString().trim(),
      'aniodisv': permisos['aniodisv'],
      'numdisv': permisos['numdisv'],
      'idTraslados': permisos['id_maestro'],
      'pesoIngreso': pesoIng1?.toString(),
      'pesoTara': tara1?.toString(),
      'mensajeInferior': msgInferior,
    });
  }

  void _handleResTransaction(
    ConfirmResponseModel model,
    AtkTransactionManager manager,
    Map<String, dynamic> baseData,
    Map<String, dynamic> cola,
  ) {
    final inOut = model.services['atkInOut']?.dataAsMap ?? {};
    final entrada = (inOut['entrada'] ?? '').toString().trim();
    final salida = (inOut['salida'] ?? '').toString().trim();

    final reg = model.services['registroEntrada']?.dataAsMap ?? {};
    final tieneEntrada = reg['tieneEntrada'] == true;
    final tieneSalida = reg['tieneSalida'] == true;

    final bypass = model.services['atkBypassHuella']?.dataAsMap ?? {};
    final bypassCod = bypass['cod_error'];

    manager.setMany({
      ...baseData,
      'driverCedula': (cola['cedula'] ?? '').toString().trim(),
      'vehiculoTipoCarga': (cola['carga_suelta'] ?? '').toString().trim(),
      'contenedor1': (cola['contenedor1'] ?? '').toString().trim(),
      'contenedor2': (cola['contenedor2'] ?? '').toString().trim(),
      'mensajeInferior': [
        'RES confirmado (#${baseData['atkId']})',
        if (entrada.isNotEmpty) 'Entrada=$entrada',
        if (salida.isNotEmpty) 'Salida=$salida',
        'TieneEntrada=${tieneEntrada ? "SI" : "NO"}',
        'TieneSalida=${tieneSalida ? "SI" : "NO"}',
        if (bypassCod != null) 'BypassHuellaCod=$bypassCod',
      ].join(' | '),
    });
  }

  Map<String, dynamic>? _tryConvertToMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  void _handleExpTransaction(
    ConfirmResponseModel model,
    AtkTransactionManager manager,
    Map<String, dynamic> baseData,
    Map<String, dynamic> cola,
  ) {
    final disv = model['atkPaConsDisvExp1'];
    final disvList = disv?.dataAsList;
    Map<String, dynamic> disvData = {};
    if (disvList != null && disvList.isNotEmpty) {
      disvData = disvList[0] as Map<String, dynamic>? ?? {};
    }

    final vacios = model['atkConsDetTras_vacios']?.dataAsMap ?? {};
    final conducto = model['atkConsDetTras_conducto']?.dataAsMap ?? {};

    final idTraslados = [
      vacios['id_traslados'],
      vacios['id_porteo'],
      vacios['id_vacio'],
      vacios['id_despacho'],
      conducto['id_traslados'],
      conducto['id_porteo'],
      conducto['id_vacio'],
      conducto['id_despacho'],
    ].firstWhere((v) => (v is num && v != 0), orElse: () => 0);

    final dataToSet = {
      ...baseData,
      'driverCedula': cola['cedula'],
      'contenedor1': cola['contenedor1'],
      'clienteExp': disvData['nombre'],
      'productoExp': disvData['producto'],
      'vehiculoTipoCarga': disvData['tipocarga'],
      'bookingExp': disvData['booking'],
      'naveExp': disvData['nave'],
      'contenedorExp': disvData['numcontenedor'],
      'sello1Exp': disvData['sello1']?.toString().trim(),
      'sello2Exp': disvData['sello2']?.toString().trim(),
      'sello3Exp': disvData['sello3']?.toString().trim(),
      'sello4Exp': disvData['sello4']?.toString().trim(),
      'pesoTara': disvData['tara']?.toString(),
      'vehiculoRefrigerado': disvData['refrigerado'],
      'vehiculoCargaImo': disvData['carga_imo'],
      'vehiculoObservaciones': disvData['observaciones'],
      'aniodisv': disvData['aniodisv'],
      'numdisv': disvData['numdisv'],
      'idTraslados': idTraslados,
      'mensajeInferior': 'Transacción EXP completada (#${baseData['atkId']})',
    };

    manager.setMany(dataToSet);
  }

  /// ? Manejo para DSP, TRL, DSP-CS (código existente)
  void _handleDspTrlTransaction(
    ConfirmResponseModel model,
    AtkTransactionManager manager,
    Map<String, dynamic> baseData,
    Map<String, dynamic> cola,
  ) {
    manager.setMany({
      ...baseData,
      'vehiculoTipoCarga': cola['tipo_carga'],
      'vehiculoProducto': cola['producto'],
      'vehiculoRefrigerado': cola['refrigerado'],
      'vehiculoCargaImo': cola['carga_imo'],
      'vehiculoBooking': cola['booking'],
      'vehiculoNave': cola['nave'],
      'vehiculoObservaciones': cola['observaciones'],
      'contenedor1': cola['contenedor1'],
      'contenedor2': cola['contenedor2'],
      'sello1': cola['sello1'],
      'sello2': cola['sello2'],
      'sello3': cola['sello3'],
      'sello4': cola['sello4'],
      'sello5': cola['sello5'],
      'pesoIngreso': cola['peso_ingreso']?.toString(),
      'pesoSalida': cola['peso_salida']?.toString(),
      'pesoTara': cola['tara']?.toString(),
      'pesoPorteo': model['getPorteo']?.dataAsMap?['porteo']?.toString(),
      'dres': cola['dres'],
      'contenedor': cola['contenedor1'],
      'ubicacion': cola['ubicacion'],
      'turno': cola['turno']?.toString(),
      'mensajeInferior':
          'Transacción ${baseData['transactionType']} completada (#${baseData['atkId']})',
    });
  }
}