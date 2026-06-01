// lib/services/apis/expDoble/exp_doble_service.dart
// Autor: Abraham Yance
// Descripción: Servicio para los endpoints del controller `exp-muelle-destare`
//   (inicializar, validar-contenedor, guardar, terminar, ruta).
import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/secure_storage_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/authApi_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/env_utils.dart';

class ExpDobleServiceException implements Exception {
  final String message;
  ExpDobleServiceException(this.message);
  @override
  String toString() => message;
}

class ExpDobleService {
  final _log = LogService.instance;

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

  Future<http.Response> _postWithAutoRefresh(
    Uri uri, {
    required String body,
    required String tag,
  }) async {
    var headers = await _authHeaders();

    final requestId = DateTime.now().millisecondsSinceEpoch;
    _log.logRequest('${tag}_REQUEST', {
      'uri': uri.toString(),
      'headers': headers,
      'body': json.decode(body),
      'requestId': requestId,
    });

    try {
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
    } on TimeoutException catch (e) {
      _log.logError('${tag}_TIMEOUT_EX', e, StackTrace.current);
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  String get _baseUrl {
    final url = dotenv.env['BASE_MIDDLEWARE_URL'] ?? '';
    if (url.isEmpty) {
      throw ExpDobleServiceException('BASE_MIDDLEWARE_URL no configurada');
    }
    return url;
  }

  String get _root => '${_baseUrl}kiosk/api/exp-muelle-destare';

  // ---------------------------------------------------------------
  // INICIALIZAR
  // ---------------------------------------------------------------
  Future<Map<String, dynamic>> inicializar(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) async {
    final uri = Uri.parse('$_root/inicializar');

    try {
      final body = _buildInicializarRequest(manager, appManager);
      final bodyJson = json.encode(body);

      final resp = await _postWithAutoRefresh(
        uri,
        body: bodyJson,
        tag: 'EXP_INICIALIZAR',
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw ExpDobleServiceException('HTTP ${resp.statusCode}');
      }

      final decoded =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

      _applyInicializarResponse(decoded, manager);
      manager.set('expMuelleInicializarResponse', decoded);

      return decoded;
    } catch (e, st) {
      _log.logError('EXP_INICIALIZAR_EX', e, st);
      manager.setError('Error en inicializar: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------
  // VALIDAR CONTENEDOR
  // ---------------------------------------------------------------
  Future<Map<String, dynamic>> validarContenedor(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) async {
    final uri = Uri.parse('$_root/validar-contenedor');

    try {
      final body = _buildValidarContenedorRequest(manager, appManager);
      final bodyJson = json.encode(body);

      _log.logRequest('EXP_VALIDAR_CONTENEDOR_PAYLOAD', body);

      final resp = await _postWithAutoRefresh(
        uri,
        body: bodyJson,
        tag: 'EXP_VALIDAR_CONTENEDOR',
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw ExpDobleServiceException('HTTP ${resp.statusCode}');
      }

      final decoded =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

      _applyValidarContenedorResponse(decoded, manager);

      return decoded;
    } catch (e, st) {
      _log.logError('EXP_VALIDAR_CONTENEDOR_EX', e, st);
      manager.setError('Error en validar contenedor: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------
  // GUARDAR
  // ---------------------------------------------------------------
  Future<Map<String, dynamic>> guardar(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) async {
    final uri = Uri.parse('$_root/guardar');

    try {
      final body = _buildGuardarRequest(manager, appManager);
      final bodyJson = json.encode(body);

      _log.logRequest('EXP_GUARDAR_PAYLOAD', body);

      final resp = await _postWithAutoRefresh(
        uri,
        body: bodyJson,
        tag: 'EXP_GUARDAR',
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw ExpDobleServiceException('HTTP ${resp.statusCode}');
      }

      final decoded =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

      _applyGuardarResponse(decoded, manager);
      manager.set('expMuelleGuardarResponse', decoded);

      return decoded;
    } catch (e, st) {
      _log.logError('EXP_GUARDAR_EX', e, st);
      manager.setError('Error en guardar: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------
  // TERMINAR
  // ---------------------------------------------------------------
  Future<Map<String, dynamic>> terminar(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) async {
    final uri = Uri.parse('$_root/terminar');

    try {
      final body = _buildTerminarRequest(manager, appManager);
      final bodyJson = json.encode(body);

      _log.logRequest('EXP_TERMINAR_PAYLOAD', body);

      final resp = await _postWithAutoRefresh(
        uri,
        body: bodyJson,
        tag: 'EXP_TERMINAR',
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw ExpDobleServiceException('HTTP ${resp.statusCode}');
      }

      final decoded =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

      manager.set('expMuelleTerminarResponse', decoded);

      return decoded;
    } catch (e, st) {
      _log.logError('EXP_TERMINAR_EX', e, st);
      manager.setError('Error en terminar: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------
  // RUTA
  // ---------------------------------------------------------------
  Future<Map<String, dynamic>> ruta(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) async {
    final uri = Uri.parse('$_root/ruta');

    try {
      final body = _buildRutaRequest(manager, appManager);
      final bodyJson = json.encode(body);

      _log.logRequest('EXP_RUTA_PAYLOAD', body);

      final resp = await _postWithAutoRefresh(
        uri,
        body: bodyJson,
        tag: 'EXP_RUTA',
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw ExpDobleServiceException('HTTP ${resp.statusCode}');
      }

      final decoded =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

      return decoded;
    } catch (e, st) {
      _log.logError('EXP_RUTA_EX', e, st);
      rethrow;
    }
  }

  // ---------------------------------------------------------------
  // BUILD REQUESTS
  // ---------------------------------------------------------------

  String _contenedorActivo(AtkTransactionManager manager) {
    return (manager.contenedor1 ?? manager.contenedorExp ?? '')
        .trim()
        .toUpperCase();
  }

  /// ?? ID REAL del acceso vehicular (ej. 48006837). NUNCA usar atkId.
  int _vehicleAccessId(AtkTransactionManager manager) {
    final raw =
        (manager.get('ocrDiSvVehicleAccessId')?.toString().trim().isNotEmpty ??
            false)
        ? manager.get('ocrDiSvVehicleAccessId').toString().trim()
        : (manager.get('expDobleVacIdActivo')?.toString().trim() ?? '0');
    return int.tryParse(raw) ?? 0;
  }

  // ?? FIX SALIDA: true si el contenedor activo es SALIDA (el que NO leyó el OCR).
  bool _esSalida(AtkTransactionManager manager) {
    return (manager.get('expDobleEsSalida') as bool?) ?? false;
  }

  // ?? FIX 400: el backend valida pesoIngreso/pesoSalida como número >= 0 y NO
  //   acepta null. Por eso el campo que no aplica se envía como 0 (no null).
  //   SALIDA  -> pesoSalida  = báscula, pesoIngreso = 0
  //   ENTRADA -> pesoIngreso = báscula, pesoSalida  = 0
  double _toDoubleOrZero(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is num) return value.toDouble();

    final text = value.toString().trim().replaceAll(',', '.');
    if (text.isEmpty) return 0.0;

    return double.tryParse(text) ?? 0.0;
  }

  /// Para SALIDA:
  ///   pesoIngreso = peso histórico de ingreso recuperado por placa/conductor
  ///   pesoSalida  = peso actual de báscula
  ///
  /// Para ENTRADA:
  ///   pesoIngreso = peso actual de báscula
  ///   pesoSalida  = 0
  double _pesoIngresoParaEnviar(AtkTransactionManager manager) {
    if (_esSalida(manager)) {
      final pesoIngresoHistorico = _toDoubleOrZero(
        manager.conseguirConductorPesoIng,
      );

      return pesoIngresoHistorico;
    }

    return manager.pesoActualBascula;
  }

  double _pesoSalidaParaEnviar(AtkTransactionManager manager) {
    if (_esSalida(manager)) {
      return manager.pesoActualBascula;
    }

    return 0.0;
  }

  int? _parseIntFlexible(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;

    final asInt = int.tryParse(s);
    if (asInt != null) return asInt;

    final asDouble = double.tryParse(s.replaceAll(',', '.'));
    if (asDouble != null) return asDouble.toInt();

    return null;
  }

  int _numTran(AtkTransactionManager manager) {
    // SALIDA -> numTran del conductor (conseguir-conductor).
    if (_esSalida(manager)) {
      final numTranConductor = _parseIntFlexible(
        manager.conseguirConductorNumTran,
      );
      if (numTranConductor != null && numTranConductor > 0) {
        _log.logRequest('EXP_NUMTRAN_FROM_CONDUCTOR_SALIDA', {
          'numTran': numTranConductor,
          'esSalida': true,
        });
        return numTranConductor;
      }
      // Fallback de SALIDA (si el conductor no trajo numTran).
      final mov = manager.get('movement_active');
      final candidates = <dynamic>[
        manager.get('expDobleNumTranActivo'),
        manager.get('numTran'),
        _mapValue(mov, 'movid'),
        _mapValue(_mapValue(mov, 'raw'), 'movid'),
        manager.expMuelleNumtrans,
      ];
      for (final c in candidates) {
        final v = _parseIntFlexible(c);
        if (v != null && v > 0) return v;
      }
      return 0;
    }

    // ?? INGRESO (ENTRADA): el movid NO aplica. Siempre 0.
    _log.logRequest('EXP_NUMTRAN_INGRESO_ZERO', {
      'esSalida': false,
      'numTran': 0,
    });
    return 0;
  }

  dynamic _mapValue(dynamic source, String key) {
    if (source is Map<String, dynamic>) return source[key];
    if (source is Map) return source[key];
    return null;
  }

  Map<String, dynamic> _buildInicializarRequest(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) {
    return {
      'placa': _safePlaca(manager),
      'cedula': manager.driverCedula ?? '',
      'nombreConductor': manager.driverName ?? '',
      'vehicleAccessId': _vehicleAccessId(manager),
      'tpg': int.tryParse(appManager.kioskConfig?.patio ?? '1') ?? 1,
      'garitaLetra': appManager.kioskConfig?.gateLetter ?? 'A',
      'garitaNumero': int.tryParse(appManager.kioskConfig?.gate ?? '1') ?? 1,
      'doorNumber': 1,
      'fechaBarrera': _fechaBarrera(),
      'tipoMov': 'EXP',
      'contenedor': _contenedorActivo(manager),
      'buqueDisv': manager.naveExp,
      'bookingDisv': manager.bookingExp,
      'clienteDisv': manager.clienteExp,
      'productoDisv': manager.productoExp,
      'tipoCarga': manager.vehiculoTipoCarga,
      'cargaIMO': manager.vehiculoCargaImo,
      'refrigeradoDisv': manager.vehiculoRefrigerado,
      'pesoCenso': manager.pesoActualBascula.toInt(),
      'fotoConductor': manager.driverPhotoUrl,
      'usuarioNombre': KioskUserEnv.usuario,
      'emailJefe': KioskUserEnv.usuario,
      'ip': appManager.kioskConfig?.kioskServer,
    };
  }

  Map<String, dynamic> _buildValidarContenedorRequest(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) {
    return {
      'contenedor': _contenedorActivo(manager),
      'placa': _safePlaca(manager),
      'cedula': (manager.driverCedula ?? '').trim().toUpperCase(),
      'vehicleAccessId': _vehicleAccessId(manager),
    };
  }

  Map<String, dynamic> _buildGuardarRequest(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) {
    final esSalida = _esSalida(manager);

    return {
      'placa': _safePlaca(manager),
      'cedula': manager.driverCedula ?? '',
      'nombreConductor': manager.driverName ?? '',
      'vehicleAccessId': _vehicleAccessId(manager),
      'tpg': int.tryParse(appManager.kioskConfig?.patio ?? '1') ?? 1,
      'garitaLetra': appManager.kioskConfig?.gateLetter ?? 'A',
      'garitaNumero': int.tryParse(appManager.kioskConfig?.gate ?? '1') ?? 1,
      'doorNumber': 1,
      'fechaBarrera': _fechaBarrera(),
      'tipoMov': 'EXP',
      'contenedor': _contenedorActivo(manager),
      'contenedorDisv': manager.contenedorExp,
      'booking': manager.bookingExp,
      'tara': double.tryParse(manager.pesoTara ?? '0') ?? 0,
      // ?? FIX 400: 0 en vez de null en el campo que no aplica.
      'pesoIngreso': _pesoIngresoParaEnviar(manager),
      'pesoSalida': _pesoSalidaParaEnviar(manager),
      'sello1': manager.sello1Exp ?? manager.sello1,
      'sello2': manager.sello2Exp ?? manager.sello2,
      'sello3': manager.sello3Exp ?? manager.sello3,
      'sello4': manager.sello4Exp ?? manager.sello4,
      'sello5': manager.sello5,
      'tipoTran': esSalida ? 'O' : 'I',
      'codProducto': 'P01',
      'codTipoCarga': 'T01',
      'codBuque': 'B01',
      'numTrans': _numTran(manager),
      'taraExpoMin': 1000,
      'taraExpoMax': 5000,
      'deviceId': appManager.kioskConfig!.gate,
      'inOut': esSalida ? 'O' : 'I',
      'procesoCompleto': 'N',
      'estadoVal': 1,
      'huellaJefe': '',
      'garitaOut': 2,
      'observaciones': '',
      'pesoBulto': 0,
      'ip': appManager.kioskConfig?.kioskServer ?? '',
      'idTraslados': manager.idTraslados ?? 0,
      'pesoContenedor':
          double.tryParse(manager.pesoActualBascula.toString()) ?? 0,
      'aniodisv': manager.aniodisv ?? DateTime.now().year,
      'numdisv': manager.numdisv ?? 0,
    };
  }

  Map<String, dynamic> _buildTerminarRequest(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) {
    return {
      'placa': _safePlaca(manager),
      'vehicleAccessId': _vehicleAccessId(manager),
      'btnGuardarEnabled': false,
      'btnCancelarEnabled': true,
      'ver': 0,
      'imprimir': 1,
      // ?? FIX 400: 0 en vez de null en el campo que no aplica.
      'pesoIngreso': _pesoIngresoParaEnviar(manager),
      'pesoSalida': _pesoSalidaParaEnviar(manager),
      'tara': double.tryParse(manager.pesoTara ?? '0') ?? 0,
      'contenedor': _contenedorActivo(manager),
      'booking': manager.bookingExp,
      'cedula': manager.driverCedula,
      'nombreConductor': manager.driverName,
      'cargaIMO': manager.vehiculoCargaImo,
      'garitaLetra': appManager.kioskConfig?.gateLetter ?? 'A',
      'usuarioNombre': KioskUserEnv.usuario,
      'emailJefe': KioskUserEnv.usuario,
      'ip': appManager.kioskConfig?.kioskServer,
      'tpg': int.tryParse(appManager.kioskConfig?.patio ?? '1') ?? 1,
      'doorNumber': 1,
      'garitaNumero': int.tryParse(appManager.kioskConfig?.gate ?? '1') ?? 1,
      'tipoMov': 'EXP',
      'fechaBarrera': _fechaBarrera(),
      'bodegueroUser': KioskUserEnv.usuario,
    };
  }

  Map<String, dynamic> _buildRutaRequest(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) {
    return {
      'contenedor': _contenedorActivo(manager),
      'booking': manager.bookingExp,
      'placa': _safePlaca(manager),
      'danios': manager.daniosExp ?? manager.vehiculoObservaciones ?? '',
      'garitaNumero': int.tryParse(appManager.kioskConfig?.gate ?? '1') ?? 1,
      'vehicleAccessId': _vehicleAccessId(manager),
      'deviceId': appManager.kioskConfig?.gate,
      'ip': appManager.kioskConfig?.kioskServer,
    };
  }

  // ---------------------------------------------------------------
  // APPLY RESPONSES
  // ---------------------------------------------------------------

  void _applyInicializarResponse(
    Map<String, dynamic> response,
    AtkTransactionManager manager,
  ) {
    if (response['errorCode'] != 0) {
      manager.setError(response['message'] ?? 'Error en inicializar');
      return;
    }

    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) return;

    final allData = <String, dynamic>{};

    if (data['numtrans'] != null) {
      allData['expMuelleNumtrans'] = data['numtrans'].toString();
    }
    if (data['estado'] != null) {
      allData['expMuelleEstado'] = data['estado'];
      allData['mensajeInferior'] = 'Estado: ${data['estado']}';
    }
    if (data['tara'] != null) {
      allData['pesoTara'] = data['tara'].toString();
    }
    if (data['pesoIngreso'] != null) {
      allData['pesoIngreso'] = data['pesoIngreso'].toString();
    }
    if (data['contenedor'] != null) {
      allData['contenedor1'] = data['contenedor'];
      allData['contenedorExp'] = data['contenedor'];
    }

    final sellos = data['sellos'] as List?;
    if (sellos != null && sellos.isNotEmpty) {
      if (sellos.isNotEmpty && sellos[0] != null) {
        allData['sello1Exp'] = sellos[0];
      }
      if (sellos.length > 1 && sellos[1] != null) {
        allData['sello2Exp'] = sellos[1];
      }
      if (sellos.length > 2 && sellos[2] != null) {
        allData['sello3Exp'] = sellos[2];
      }
      if (sellos.length > 3 && sellos[3] != null) {
        allData['sello4Exp'] = sellos[3];
      }
    }

    final disv = data['disv'] as Map<String, dynamic>?;
    if (disv != null) {
      if (disv['cliente'] != null) allData['clienteExp'] = disv['cliente'];
      if (disv['producto'] != null) allData['productoExp'] = disv['producto'];
      if (disv['tipoCarga'] != null) {
        allData['vehiculoTipoCarga'] = disv['tipoCarga'];
      }
      if (disv['cargaIMO'] != null) {
        allData['vehiculoCargaImo'] = disv['cargaIMO'];
      }
      if (disv['refrigerado'] != null) {
        allData['vehiculoRefrigerado'] = disv['refrigerado'];
      }
      if (disv['booking'] != null) allData['bookingExp'] = disv['booking'];
      if (disv['buque'] != null) allData['naveExp'] = disv['buque'];
    }

    manager.setMany(allData);
  }

  void _applyValidarContenedorResponse(
    Map<String, dynamic> response,
    AtkTransactionManager manager,
  ) {
    final data = response['data'] as Map<String, dynamic>?;
    final esValido =
        (data?['esValido'] as bool?) ?? (response['errorCode'] == 0);

    manager.setManyWithoutNotify({
      'expMuelleValidarContenedorOk': esValido,
      'expMuelleContenedorValidado':
          data?['contenedorValidado'] ?? _contenedorActivo(manager),
    });

    if (!esValido) {
      final msg =
          (data?['mensajeError'] as String?) ??
          (response['message'] as String?) ??
          'El contenedor no coincide con el DISV.';
      manager.setError(msg);
    }
  }

  void _applyGuardarResponse(
    Map<String, dynamic> response,
    AtkTransactionManager manager,
  ) {
    if (response['errorCode'] != 0) {
      manager.setError(response['message'] ?? 'Error al guardar');
      return;
    }

    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) return;

    if (data['numero'] != null) {
      manager.set('expMuelleGuardarNumero', data['numero']);
    }
    manager.set('expMuelleGuardarOk', true);
  }

  // ---------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------

  String _fechaBarrera() {
    final now = DateTime.now();
    return '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
  }

  String _safePlaca(AtkTransactionManager manager) {
    final values = [
      manager.vehiculoPlaca,
      manager.get('placa'),
      manager.get('rfidPlaca'),
      manager.get('conseguirConductorPlaca'),
    ];

    for (final v in values) {
      final s = (v ?? '').toString().trim().toUpperCase();
      if (s.isNotEmpty) return s;
    }

    return '';
  }
}
