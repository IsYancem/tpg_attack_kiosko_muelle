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
    var headers = await _authHeaders();
    final bodyJson = json.encode(body);

    _log.logRequest('${tag}_REQUEST', {'uri': uri.toString(), 'body': body});

    try {
      var res = await http
          .post(uri, headers: headers, body: bodyJson)
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 401 || res.statusCode == 403) {
        invalidateCache();
        final appState = AppStateManager.instance;
        final refreshed = await AuthApiService.refresh(appState);
        if (refreshed) {
          headers = await _authHeaders();
          res = await http
              .post(uri, headers: headers, body: bodyJson)
              .timeout(const Duration(seconds: 30));
        }
      }

      if (res.statusCode != 200 && res.statusCode != 201) {
        throw ExpMuelleRepesajeServiceException(
          'HTTP ${res.statusCode}',
          step: tag,
        );
      }

      final decoded =
          json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      _log.logRequest('${tag}_RESPONSE', {
        'errorCode': decoded['errorCode'],
        'message': decoded['message'],
      });

      return decoded;
    } on TimeoutException catch (e) {
      _log.logError('${tag}_TIMEOUT', e, StackTrace.current);
      rethrow;
    } catch (e) {
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

    final req = ExpMuelleInicializarRequest(
      placa: _safePlaca(manager),
      cedula: manager.driverCedula ?? '',
      nombreConductor: manager.driverName,
      vehicleAccessId: int.tryParse(manager.atkId ?? '0') ?? 0,
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

    // numtrans → vehicleAccessId para los siguientes pasos
    if (data.numtrans != null) {
      all['atkId'] = data.numtrans.toString();
    }

    // Sellos (preservar los del pregate si vienen)
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

    await _log.logRequest('EXP_MUELLE_VALIDAR_CONTENEDOR_START', {
      'contenedorOcr': contenedorOcr,
      'contenedorDisv': contenedorDisv,
    });

    // ── Paso 2a: Comparación local ──────────────────────────────────────────
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

    // ── Paso 2b: Validación remota ──────────────────────────────────────────
    final kiosk = appManager.kioskConfig;
    final vehicleAccessId = int.tryParse(manager.atkId ?? '0') ?? 0;

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

    final tara = double.tryParse(manager.pesoTara ?? '0') ?? 0.0;
    final pesoIngreso = manager.pesoActualBascula;
    final numTrans = int.tryParse(manager.atkId ?? '0') ?? 0;

    final req = ExpMuelleGuardarRequest(
      placa: _safePlaca(manager),
      cedula: manager.driverCedula ?? '',
      nombreConductor: manager.driverName,
      vehicleAccessId: numTrans,
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
      pesoSalida: null, // repesaje = entrada
      sello1: manager.sello1Exp ?? manager.sello1,
      sello2: manager.sello2Exp ?? manager.sello2,
      sello3: manager.sello3Exp ?? manager.sello3,
      sello4: manager.sello4Exp ?? manager.sello4,
      sello5: manager.sello5,
      tipoTran: 'I',
      numTrans: numTrans > 0 ? numTrans : null,
      deviceId: kiosk?.gate,
      inOut: 'I',
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

    // Persistir en manager
    _applyGuardarResponse(response, manager);

    return response;
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
