// lib/services/apis/expRepesaje/exp_muelle_repesaje_service.dart
// Autor: Abraham Yance
// Servicio para el flujo EXP REPESAJE:
//   PASO 1 → inicializar
//   PASO 2 → validar-contenedor  (OCR vs DISV — cliente + servidor)
//   PASO 3 → guardar
//   PASO 4 → terminar
//
// Si cualquier paso falla se lanza una excepción y no se continúa.

import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tpg_attack_kiosko_muelle/models/exp_muelle/exp_muelle_models.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/authApi_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/secure_storage_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/env_utils.dart';

class ExpMuelleRepesajeServiceException implements Exception {
  final String message;
  final String? step;
  ExpMuelleRepesajeServiceException(this.message, {this.step});
  @override
  String toString() => step != null ? '[$step] $message' : message;
}

class ExpMuelleRepesajeService {
  final _log = LogService.instance;

  // ── Auth headers con cache ───────────────────────────────────────────────
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
      final stored = await SecureStorageService.getToken();
      if (stored != null && stored.isNotEmpty) {
        final refresh = await SecureStorageService.getRefreshToken();
        appState.setTokens(stored, refresh ?? '');
        token = stored;
      }
    }

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    _cachedHeaders = headers;
    _headersCacheTime = DateTime.now();
    return headers;
  }

  static void invalidateCache() {
    _cachedHeaders = null;
    _headersCacheTime = null;
  }

  String get _baseUrl {
    final url = dotenv.env['BASE_MIDDLEWARE_URL'] ?? '';
    if (url.isEmpty) {
      throw ExpMuelleRepesajeServiceException(
        'BASE_MIDDLEWARE_URL no configurada',
      );
    }
    return url;
  }

  // ── POST con auto-refresh ────────────────────────────────────────────────
  Future<Map<String, dynamic>> _post({
    required String path,
    required Map<String, dynamic> body,
    required String tag,
  }) async {
    final uri = Uri.parse('${_baseUrl}kiosk/api/$path');
    final sw = Stopwatch()..start();

    var headers = await _authHeaders();
    final bodyJson = json.encode(body);

    Map<String, dynamic> safeHeaders(Map<String, String> h) {
      return {
        ...h,
        if (h['Authorization'] != null)
          'Authorization': 'Bearer ***${h['Authorization']!.length}',
      };
    }

    await _log.logRequest('${tag}_FULL_REQUEST', {
      'uri': uri.toString(),
      'method': 'POST',
      'headers': safeHeaders(headers),
      'body': body,
      'bodyJson': bodyJson,
    });

    try {
      var res = await http
          .post(uri, headers: headers, body: bodyJson)
          .timeout(const Duration(seconds: 30));

      await _log.logRequest('${tag}_HTTP_RESPONSE_RAW', {
        'statusCode': res.statusCode,
        'elapsedMs': sw.elapsedMilliseconds,
        'rawBody': utf8.decode(res.bodyBytes),
      });

      if (res.statusCode == 401 || res.statusCode == 403) {
        await _log.logWarning('${tag}_AUTH_RETRY', {
          'statusCode': res.statusCode,
          'message': 'Token vencido o no autorizado. Intentando refresh.',
        });

        invalidateCache();

        final appState = AppStateManager.instance;
        final refreshed = await AuthApiService.refresh(appState);

        await _log.logRequest('${tag}_AUTH_REFRESH_RESULT', {
          'refreshed': refreshed,
        });

        if (refreshed) {
          headers = await _authHeaders();

          await _log.logRequest('${tag}_RETRY_REQUEST', {
            'uri': uri.toString(),
            'method': 'POST',
            'headers': safeHeaders(headers),
            'body': body,
            'bodyJson': bodyJson,
          });

          res = await http
              .post(uri, headers: headers, body: bodyJson)
              .timeout(const Duration(seconds: 30));

          await _log.logRequest('${tag}_RETRY_RESPONSE_RAW', {
            'statusCode': res.statusCode,
            'elapsedMs': sw.elapsedMilliseconds,
            'rawBody': utf8.decode(res.bodyBytes),
          });
        }
      }

      if (res.statusCode != 200 && res.statusCode != 201) {
        throw ExpMuelleRepesajeServiceException(
          'HTTP ${res.statusCode}: ${utf8.decode(res.bodyBytes)}',
          step: tag,
        );
      }

      final decoded =
          json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      sw.stop();

      await _log.logRequest('${tag}_FULL_RESPONSE', {
        'elapsedMs': sw.elapsedMilliseconds,
        'statusCode': res.statusCode,
        'errorCode': decoded['errorCode'],
        'message': decoded['message'],
        'data': decoded['data'],
        'fullDecoded': decoded,
      });

      return decoded;
    } on TimeoutException catch (e, st) {
      sw.stop();

      await _log.logError('${tag}_TIMEOUT', e, st);
      await _log.logRequest('${tag}_TIMEOUT_CONTEXT', {
        'elapsedMs': sw.elapsedMilliseconds,
        'uri': uri.toString(),
        'body': body,
      });

      rethrow;
    } catch (e, st) {
      sw.stop();

      await _log.logError('${tag}_FULL_EXCEPTION', e, st);
      await _log.logRequest('${tag}_FULL_EXCEPTION_CONTEXT', {
        'elapsedMs': sw.elapsedMilliseconds,
        'uri': uri.toString(),
        'body': body,
        'error': e.toString(),
      });

      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PASO 1 — INICIALIZAR
  // ─────────────────────────────────────────────────────────────────────────
  Future<ExpMuelleInicializarResponse> inicializar({
    required AtkTransactionManager manager,
    required AppStateManager appManager,
  }) async {
    final kiosk = appManager.kioskConfig;
    final now = _fechaBarrera();

    // ── vehicleAccessId: usar el ID del movimiento DISV guardado por el OCR ──
    // Se prefiere ocrDiSvVehicleAccessId porque es el ID correcto del acceso
    // vehicular. manager.atkId puede contener un valor de sesión RFID o estar
    // vacío. Si ninguno está disponible se envía 0.
    final vehicleAccessId =
        int.tryParse(
          manager.get('ocrDiSvVehicleAccessId')?.toString() ??
              manager.atkId ??
              '0',
        ) ??
        0;

    final req = ExpMuelleInicializarRequest(
      placa: _safePlaca(manager),
      cedula: manager.driverCedula ?? '',
      nombreConductor: manager.driverName,
      vehicleAccessId: vehicleAccessId,
      tpg: int.tryParse((kiosk?.patio ?? '1').replaceAll('TPG', '')) ?? 1,
      garitaLetra: kiosk?.gateLetter,
      garitaNumero: int.tryParse(kiosk?.gate ?? '1'),
      doorNumber: _int(manager.get('doorNumber')) ?? 1,
      fechaBarrera: now,
      tipoMov: 'EXP',
      contenedor: manager.contenedor1 ?? manager.contenedorExp,
      buqueDisv: manager.naveExp,
      bookingDisv: manager.bookingExp,
      clienteDisv: manager.clienteExp,
      productoDisv: manager.productoExp,
      tipoCarga: manager.vehiculoTipoCarga,
      cargaIMO: manager.vehiculoCargaImo,
      refrigeradoDisv: manager.vehiculoRefrigerado,
      pesoCenso: manager.pesoActualBascula.toInt(),
      fotoConductor: manager.driverPhotoUrl,
      usuarioNombre: KioskUserEnv.usuario,
      emailJefe: KioskUserEnv.usuario,
      ip: kiosk?.kioskServer,
    );

    await _log.logRequest('EXP_MUELLE_INICIALIZAR_PRE', {
      'vehicleAccessId': vehicleAccessId,
      'ocrDiSvVehicleAccessId': manager.get('ocrDiSvVehicleAccessId'),
      'atkIdPrevio': manager.atkId,
      'placa': req.placa,
      'contenedor': req.contenedor,
    });

    final raw = await _post(
      path: 'exp-muelle/inicializar',
      body: req.toJson(),
      tag: 'EXP_MUELLE_INICIALIZAR',
    );

    final response = ExpMuelleInicializarResponse.fromJson(raw);

    if (!response.isOk) {
      throw ExpMuelleRepesajeServiceException(
        response.message.isNotEmpty
            ? response.message
            : 'Error al inicializar la transacción EXP',
        step: 'INICIALIZAR',
      );
    }

    // Persistir en manager
    _applyInicializarResponse(response, manager);

    return response;
  }

  void _applyInicializarResponse(
    ExpMuelleInicializarResponse response,
    AtkTransactionManager manager,
  ) {
    final data = response.data;
    if (data == null) return;

    final all = <String, dynamic>{
      // Transacción principal
      'expMuelleNumtrans': data.numtrans?.toString(),
      'expMuelleEstado': data.estado,
      'expMuelleInicializarResponse': data.toJson(),

      // Peso y tara
      'pesoTara': data.tara?.toString(),
      'pesoIngreso': data.pesoIngreso,

      // Contenedor DISV (para comparar con OCR en paso 2)
      'expMuelleContenedorDisv': data.contenedor,

      // Panel
      'expMuellePanelSalidaVisible': data.panelSalidaVisible,
    };

    // IMPORTANTE: atkId ahora pasa a ser el numtrans del SP.
    // ocrDiSvVehicleAccessId NO se modifica aquí, conservando el ID del
    // movimiento DISV para que validarContenedor() pueda usarlo.
    if (data.numtrans != null) {
      all['atkId'] = data.numtrans.toString();
    }

    // Sellos del pregate
    if (data.sellos.isNotEmpty) {
      if (data.sellos.length > 0) all['sello1Exp'] = data.sellos[0];
      if (data.sellos.length > 1) all['sello2Exp'] = data.sellos[1];
      if (data.sellos.length > 2) all['sello3Exp'] = data.sellos[2];
      if (data.sellos.length > 3) all['sello4Exp'] = data.sellos[3];
    }

    // DISV
    final disv = data.disv;
    if (disv != null) {
      if (disv.cliente != null) all['clienteExp'] = disv.cliente;
      if (disv.producto != null) all['productoExp'] = disv.producto;
      if (disv.tipoCarga != null) all['vehiculoTipoCarga'] = disv.tipoCarga;
      if (disv.cargaIMO != null) all['vehiculoCargaImo'] = disv.cargaIMO;
      if (disv.refrigerado != null)
        all['vehiculoRefrigerado'] = disv.refrigerado;
      if (disv.booking != null) all['bookingExp'] = disv.booking;
      if (disv.buque != null) all['naveExp'] = disv.buque;
    }

    manager.setManyWithoutNotify(all);

    _log.logRequest('EXP_MUELLE_INICIALIZAR_MANAGER_APPLIED', {
      'numtrans': data.numtrans,
      'atkIdAhora': data.numtrans?.toString(), // ← atkId sobreescrito
      'ocrDiSvVehicleAccessId': manager.get(
        'ocrDiSvVehicleAccessId',
      ), // ← intacto
      'estado': data.estado,
      'contenedorDisv': data.contenedor,
      'tara': data.tara,
      'sellos': data.sellos.length,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PASO 2 — VALIDAR CONTENEDOR
  //   a) Comparación local OCR vs DISV (client-side, rápida)
  //   b) Validación remota vía SP atk_valida_exportacion_datos
  // ─────────────────────────────────────────────────────────────────────────
  Future<ExpMuelleValidarContenedorResponse> validarContenedor({
    required AtkTransactionManager manager,
    required AppStateManager appManager,
  }) async {
    final contenedorOcr = (manager.get('contenedor1') as String? ?? '')
        .trim()
        .toUpperCase();
    final contenedorDisv =
        (manager.get('expMuelleContenedorDisv') as String? ?? '')
            .trim()
            .toUpperCase();

    // ── vehicleAccessId para atk_valida_exportacion_datos ──────────────────
    // CRÍTICO: manager.atkId ya tiene el numtrans (sobreescrito por inicializar).
    // El ID correcto del acceso vehicular está en ocrDiSvVehicleAccessId.
    // Fallback: expMuelleNumtrans (= numtrans) si no hay ID de movimiento DISV.
    final vehicleAccessIdStr =
        manager.get('ocrDiSvVehicleAccessId')?.toString().trim() ??
        manager.get('expMuelleNumtrans')?.toString().trim() ??
        '0';
    final vehicleAccessId = int.tryParse(vehicleAccessIdStr) ?? 0;

    await _log.logRequest('EXP_MUELLE_VALIDAR_CONTENEDOR_START', {
      'contenedorOcr': contenedorOcr,
      'contenedorDisv': contenedorDisv,
      'vehicleAccessId': vehicleAccessId,
      'source_ocrDiSvVehicleAccessId': manager.get('ocrDiSvVehicleAccessId'),
      'source_atkId_actual': manager.atkId, // numtrans después de inicializar
      'source_expMuelleNumtrans': manager.get('expMuelleNumtrans'),
    });

    // ── Comparación local (rápida, sin red) ──────────────────────────────────
    if (contenedorOcr.isEmpty) {
      throw ExpMuelleRepesajeServiceException(
        'El contenedor OCR está vacío. No se puede validar.',
        step: 'VALIDAR_CONTENEDOR',
      );
    }

    if (contenedorDisv.isNotEmpty && contenedorOcr != contenedorDisv) {
      throw ExpMuelleRepesajeServiceException(
        'El contenedor leído por OCR ($contenedorOcr) no coincide '
        'con el contenedor del DISV ($contenedorDisv).',
        step: 'VALIDAR_CONTENEDOR',
      );
    }

    // ── Validación remota (SP atk_valida_exportacion_datos) ──────────────────
    final req = ExpMuelleValidarContenedorRequest(
      contenedor: contenedorOcr,
      placa: _safePlaca(manager),
      cedula: manager.driverCedula,
      vehicleAccessId: vehicleAccessId > 0 ? vehicleAccessId : null,
    );

    final raw = await _post(
      path: 'exp-muelle/validar-contenedor',
      body: req.toJson(),
      tag: 'EXP_MUELLE_VALIDAR_CONTENEDOR',
    );

    final response = ExpMuelleValidarContenedorResponse.fromJson(raw);

    if (!response.isOk) {
      throw ExpMuelleRepesajeServiceException(
        response.data?.mensajeError ??
            (response.message.isNotEmpty
                ? response.message
                : 'Contenedor no válido en DISV'),
        step: 'VALIDAR_CONTENEDOR',
      );
    }

    manager.setManyWithoutNotify({
      'expMuelleContenedorValidado': response.data?.contenedorValidado,
      'expMuelleValidarContenedorOk': true,
    });

    await _log.logRequest('EXP_MUELLE_VALIDAR_CONTENEDOR_OK', {
      'contenedorOcr': contenedorOcr,
      'contenedorValidado': response.data?.contenedorValidado,
      'vehicleAccessId': vehicleAccessId,
    });

    return response;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PASO 3 — GUARDAR
  // ─────────────────────────────────────────────────────────────────────────
  Future<ExpMuelleGuardarResponse> guardar({
    required AtkTransactionManager manager,
    required AppStateManager appManager,
  }) async {
    final kiosk = appManager.kioskConfig;
    final now = _fechaBarrera();

    final contenedor =
        (manager.get('contenedor1') as String? ?? manager.contenedorExp ?? '')
            .trim()
            .toUpperCase();

    final contenedorDisv =
        (manager.get('expMuelleContenedorDisv') as String? ?? contenedor)
            .trim()
            .toUpperCase();

    // ID real del acceso vehicular recuperado desde consultar-transaccion.
    // Este SÍ debe viajar como vehicleAccessId.
    final vehicleAccessId =
        int.tryParse(
          manager.get('ocrDiSvVehicleAccessId')?.toString() ??
              manager.atkId ??
              '0',
        ) ??
        0;

    // Tara real leída por OCR.
    final tara = _ocrTaraForContainer(manager, contenedor);

    final pesoIngreso = manager.pesoActualBascula;

    // Por ahora:
    // ENTRADA => 0
    // SALIDA  => 1
    final isSalida =
        manager.expMuellePanelSalidaVisible ||
        (manager.expMuelleEstado ?? '').trim().toUpperCase() == 'SALIENDO';

    final numTransFlag = isSalida ? 1 : 0;
    final tipoTran = isSalida ? 'O' : 'I';
    final inOut = isSalida ? 'O' : 'I';

    await _log.logRequest('EXP_MUELLE_GUARDAR_BUILD_REQUEST', {
      'placa': _safePlaca(manager),
      'contenedor': contenedor,
      'contenedorDisv': contenedorDisv,
      'vehicleAccessId': vehicleAccessId,
      'source_ocrDiSvVehicleAccessId': manager.get('ocrDiSvVehicleAccessId'),
      'source_atkId': manager.atkId,
      'taraFromOcr': tara,
      'ocrContainer1Tare': manager.get('ocrContainer1Tare'),
      'ocrContainer2Tare': manager.get('ocrContainer2Tare'),
      'pesoIngreso': pesoIngreso,
      'expMuelleEstado': manager.expMuelleEstado,
      'expMuellePanelSalidaVisible': manager.expMuellePanelSalidaVisible,
      'numTransFlag': numTransFlag,
      'tipoTran': tipoTran,
      'inOut': inOut,
    });

    final req = ExpMuelleGuardarRequest(
      placa: _safePlaca(manager),
      cedula: manager.driverCedula ?? '',
      nombreConductor: manager.driverName,
      vehicleAccessId: vehicleAccessId,
      tpg: int.tryParse((kiosk?.patio ?? '1').replaceAll('TPG', '')) ?? 1,
      garitaLetra: kiosk?.gateLetter,
      garitaNumero: int.tryParse(kiosk?.gate ?? '1'),
      doorNumber: _int(manager.get('doorNumber')) ?? 1,
      fechaBarrera: now,
      tipoMov: 'EXP',
      contenedor: contenedor,
      contenedorDisv: contenedorDisv,
      booking: manager.bookingExp,
      tara: tara,
      pesoIngreso: pesoIngreso,
      pesoSalida: isSalida ? pesoIngreso : null,
      sello1: manager.sello1Exp ?? manager.sello1,
      sello2: manager.sello2Exp ?? manager.sello2,
      sello3: manager.sello3Exp ?? manager.sello3,
      sello4: manager.sello4Exp ?? manager.sello4,
      sello5: manager.sello5,
      tipoTran: tipoTran,
      numTrans: numTransFlag,
      deviceId: kiosk?.gate,
      inOut: inOut,
      estadoVal: 1,
      huellaJefe: '',
      garitaOut: 2,
      observaciones: '',
      pesoBulto: 0,
      ip: kiosk?.kioskServer,
      idTraslados: manager.idTraslados,
      pesoContenedor: pesoIngreso,
      aniodisv: manager.aniodisv ?? DateTime.now().year,
      numdisv: manager.numdisv,
    );

    final raw = await _post(
      path: 'exp-muelle/guardar',
      body: req.toJson(),
      tag: 'EXP_MUELLE_GUARDAR',
    );

    final response = ExpMuelleGuardarResponse.fromJson(raw);

    if (!response.isOk) {
      throw ExpMuelleRepesajeServiceException(
        response.message.isNotEmpty
            ? response.message
            : 'Error al guardar la transacción EXP',
        step: 'GUARDAR',
      );
    }

    _applyGuardarResponse(response, manager);

    return response;
  }

  double _ocrTaraForContainer(
    AtkTransactionManager manager,
    String contenedor,
  ) {
    final c1 = (manager.get('contenedor1') ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final c2 = (manager.get('contenedor2') ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final target = contenedor.trim().toUpperCase();

    dynamic rawTara;

    if (target.isNotEmpty && target == c2) {
      rawTara = manager.get('ocrContainer2Tare');
    } else {
      rawTara = manager.get('ocrContainer1Tare');
    }

    final tara = _doubleFromAny(rawTara);

    if (tara > 0) return tara;

    return _doubleFromAny(manager.pesoTara);
  }

  double _doubleFromAny(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();

    final cleaned = value
        .toString()
        .trim()
        .replaceAll(',', '.')
        .replaceAll(RegExp(r'[^0-9.]'), '');

    return double.tryParse(cleaned) ?? 0.0;
  }

  void _applyGuardarResponse(
    ExpMuelleGuardarResponse response,
    AtkTransactionManager manager,
  ) {
    final data = response.data;
    if (data == null) return;

    manager.setManyWithoutNotify({
      'expMuelleGuardarNumero': data.numero?.toString(),
      'expMuelleGuardarOk': true,
      'expMuelleGuardarResponse': data.toJson(),
      if (data.numero != null) 'numTrans': data.numero.toString(),
    });

    _log.logRequest('EXP_MUELLE_GUARDAR_MANAGER_APPLIED', {
      'numero': data.numero,
      'contenedorValidadoDisv': data.contenedorValidadoDisv,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PASO 4 — TERMINAR
  // ─────────────────────────────────────────────────────────────────────────
  Future<ExpMuelleTerminarResponse> terminar({
    required AtkTransactionManager manager,
    required AppStateManager appManager,
  }) async {
    final kiosk = appManager.kioskConfig;
    final now = _fechaBarrera();

    final tara = double.tryParse(manager.pesoTara ?? '0') ?? 0.0;
    final vehicleAccessId = int.tryParse(manager.atkId ?? '0') ?? 0;

    final req = ExpMuelleTerminarRequest(
      placa: _safePlaca(manager),
      vehicleAccessId: vehicleAccessId > 0 ? vehicleAccessId : null,
      btnGuardarEnabled: false,
      btnCancelarEnabled: true,
      ver: 0,
      imprimir: 1,
      pesoSalida: null, // repesaje = entrada, sin peso salida aún
      pesoIngreso: manager.pesoActualBascula,
      tara: tara,
      contenedor: manager.contenedor1 ?? manager.contenedorExp,
      booking: manager.bookingExp,
      cedula: manager.driverCedula,
      nombreConductor: manager.driverName,
      cargaIMO: manager.vehiculoCargaImo,
      garitaLetra: kiosk?.gateLetter,
      garitaNumero: int.tryParse(kiosk?.gate ?? '1'),
      usuarioNombre: KioskUserEnv.usuario,
      emailJefe: KioskUserEnv.usuario,
      ip: kiosk?.kioskServer,
      tpg: int.tryParse((kiosk?.patio ?? '1').replaceAll('TPG', '')),
      doorNumber: _int(manager.get('doorNumber')) ?? 1,
      tipoMov: 'EXP',
      fechaBarrera: now,
      bodegueroUser: KioskUserEnv.usuario,
    );

    final raw = await _post(
      path: 'exp-muelle/terminar',
      body: req.toJson(),
      tag: 'EXP_MUELLE_TERMINAR',
    );

    final response = ExpMuelleTerminarResponse.fromJson(raw);

    if (!response.isOk) {
      throw ExpMuelleRepesajeServiceException(
        response.message.isNotEmpty
            ? response.message
            : 'Error al terminar la transacción EXP',
        step: 'TERMINAR',
      );
    }

    // Persistir en manager
    _applyTerminarResponse(response, manager);

    return response;
  }

  void _applyTerminarResponse(
    ExpMuelleTerminarResponse response,
    AtkTransactionManager manager,
  ) {
    final data = response.data;

    manager.setManyWithoutNotify({
      'expMuelleTerminarEstado': data?.estado,
      'expMuelleTerminarOk': true,
      'expMuelleTerminarResponse': data?.toJson(),
    });

    _log.logRequest('EXP_MUELLE_TERMINAR_MANAGER_APPLIED', {
      'estado': data?.estado,
      'isAutorizado': data?.isAutorizado,
      'isBloqueado': data?.isBloqueado,
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  String _safePlaca(AtkTransactionManager manager) {
    for (final v in [
      manager.vehiculoPlaca,
      manager.get('placa'),
      manager.get('rfidPlaca'),
      manager.get('conseguirConductorPlaca'),
    ]) {
      final s = (v ?? '').toString().trim().toUpperCase();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String _fechaBarrera() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }
}
