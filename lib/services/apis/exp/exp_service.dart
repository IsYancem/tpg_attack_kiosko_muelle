// lib/services/apis/exp_service.dart
// Autor: Abraham Yance
// Fecha: 2025-12-10
// Descripción: Servicio para endpoints de EXP (inicializar, guardar, terminar, cancelar)
// ELIMINADO: imprimir (no es necesario)
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

class ExpServiceException implements Exception {
  final String message;
  ExpServiceException(this.message);
  @override
  String toString() => message;
}

class ExpService {
  final _log = LogService.instance;

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

  /// ✅ POST con auto-refresh
  // exp_service.dart
  Future<http.Response> _postWithAutoRefresh(
    Uri uri, {
    required String body,
    required String tag,
  }) async {
    var headers = await _authHeaders();

    // ✅ LOG ANTES DE ENVIAR
    final requestId = DateTime.now().millisecondsSinceEpoch;
    _log.logRequest(
      '${tag}_REQUEST',
      {
        'uri': uri.toString(),
        'headers': headers,
        'body': json.decode(body),
        'requestId': requestId,
      },
    );

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
      throw ExpServiceException('BASE_MIDDLEWARE_URL no configurada');
    }
    return url;
  }

  // ═══════════════════════════════════════════════════════════════
  // INICIALIZAR
  // ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> inicializar(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) async {
    final uri = Uri.parse('${_baseUrl}kiosk/api/exp/inicializar');

    try {
      final body = _buildInicializarRequest(manager, appManager);
      final bodyJson = json.encode(body);

      final resp = await _postWithAutoRefresh(
        uri,
        body: bodyJson,
        tag: 'EXP_INICIALIZAR',
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw ExpServiceException('HTTP ${resp.statusCode}');
      }

      final decoded =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

      // Aplicar respuesta
      _applyInicializarResponse(decoded, manager);

      return decoded;
    } catch (e, st) {
      _log.logError('EXP_INICIALIZAR_EX', e, st);
      manager.setError('Error en inicializar: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // GUARDAR
  // ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> guardar(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) async {
    final uri = Uri.parse('${_baseUrl}kiosk/api/exp/guardar');

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
        throw ExpServiceException('HTTP ${resp.statusCode}');
      }

      final decoded =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

      // Aplicar respuesta
      _applyGuardarResponse(decoded, manager);

      return decoded;
    } catch (e, st) {
      _log.logError('EXP_GUARDAR_EX', e, st);
      manager.setError('Error en guardar: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // RUTA (Consultar proyección y generar ticket)
  // ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> ruta(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) async {
    final uri = Uri.parse('${_baseUrl}kiosk/api/exp/ruta');

    try {
      final body = _buildRutaRequest(manager, appManager);
      final bodyJson = json.encode(body);

      /// 🔥 LOG FORMAL EN LogService
      _log.logRequest('EXP_RUTA_PAYLOAD', body);

      final resp = await _postWithAutoRefresh(
        uri,
        body: bodyJson,
        tag: 'EXP_RUTA',
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw ExpServiceException('HTTP ${resp.statusCode}');
      }

      final decoded =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

      return decoded;
    } catch (e, st) {
      _log.logError('EXP_RUTA_EX', e, st);
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD RUTA REQUEST
  // ═══════════════════════════════════════════════════════════════
  // En _buildRutaRequest de ExpService:
  Map<String, dynamic> _buildRutaRequest(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) {
    return {
      'contenedor': manager.contenedor1 ?? manager.contenedorExp ?? '',
      'booking': manager.bookingExp,
      'placa': _safePlaca(manager),
      'danios': manager.daniosExp ?? manager.vehiculoObservaciones ?? '',
      'garitaNumero': int.tryParse(appManager.kioskConfig?.gate ?? '1') ?? 1,
      'vehicleAccessId': int.tryParse(manager.atkId ?? '0') ?? 0,
      'deviceId': appManager.kioskConfig?.gate,
      'ip': appManager.kioskConfig?.kioskServer,
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // TERMINAR
  // ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> terminar(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) async {
    final uri = Uri.parse('${_baseUrl}kiosk/api/exp/terminar');

    try {
      final body = _buildTerminarRequest(manager, appManager);
      final bodyJson = json.encode(body);

      /// 🔥 LOG FORMAL EN LogService
      _log.logRequest('EXP_TERMINAR_PAYLOAD', body);

      final resp = await _postWithAutoRefresh(
        uri,
        body: bodyJson,
        tag: 'EXP_TERMINAR',
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw ExpServiceException('HTTP ${resp.statusCode}');
      }

      final decoded =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

      return decoded;
    } catch (e, st) {
      _log.logError('EXP_TERMINAR_EX', e, st);
      manager.setError('Error en terminar: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CANCELAR
  // ═══════════════════════════════════════════════════════════════
 /* Future<Map<String, dynamic>> cancelar(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) async {
    final uri = Uri.parse('${_baseUrl}kiosk/api/exp/cancelar');

    try {
      final body = _buildCancelarRequest(manager, appManager);
      final bodyJson = json.encode(body);

      final resp = await _postWithAutoRefresh(
        uri,
        body: bodyJson,
        tag: 'EXP_CANCELAR',
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw ExpServiceException('HTTP ${resp.statusCode}');
      }

      final decoded =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

      _log.logRequest('EXP_CANCELAR_OK', {'message': decoded['message']});

      return decoded;
    } catch (e, st) {
      _log.logError('EXP_CANCELAR_EX', e, st);
      // No lanzar excepción aquí, cancelar es best-effort
      return {'errorCode': 1, 'message': 'Error en cancelar: $e', 'data': null};
    }
  }
*/

  // ═══════════════════════════════════════════════════════════════
  // BUILD REQUESTS
  // ═══════════════════════════════════════════════════════════════
  Map<String, dynamic> _buildInicializarRequest(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) {
    final now = DateTime.now();
    final fechaBarrera =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    return {
      'placa': _safePlaca(manager),
      'cedula': manager.driverCedula ?? '',
      'nombreConductor': manager.driverName ?? '',
      'vehicleAccessId': int.tryParse(manager.atkId ?? '0') ?? 0,
      'tpg': int.tryParse(appManager.kioskConfig?.patio ?? '1') ?? 1,
      'garitaLetra': appManager.kioskConfig?.gateLetter ?? 'A',
      'garitaNumero': int.tryParse(appManager.kioskConfig?.gate ?? '1') ?? 1,
      'doorNumber': 1,
      'fechaBarrera': fechaBarrera,
      'tipoMov': 'EXP',
      'contenedor': manager.contenedor1 ?? manager.contenedorExp,
      'buqueDisv': manager.naveExp,
      'bookingDisv': manager.bookingExp,
      'clienteDisv': manager.clienteExp,
      'productoDisv': manager.productoExp,
      'tipoCarga': manager.vehiculoTipoCarga,
      'cargaIMO': manager.vehiculoCargaImo,
      'refrigeradoDisv': manager.vehiculoRefrigerado,
      'pesoCenso': manager.pesoActualBascula.toInt(),
      'fotoConductor': manager.driverPhotoUrl,
      'usuarioNombre': appManager.requestUsername,
      'emailJefe': appManager.requestUsername,
      'ip': appManager.kioskConfig?.kioskServer,
    };
  }

  Map<String, dynamic> _buildGuardarRequest(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) {
    final now = DateTime.now();
    final fechaBarrera =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    return {
      'placa': _safePlaca(manager),
      'cedula': manager.driverCedula ?? '',
      'nombreConductor': manager.driverName ?? '',
      'vehicleAccessId': manager.atkId ?? 0, 
      'tpg': int.tryParse(appManager.kioskConfig?.patio ?? '1') ?? 1,
      'garitaLetra': appManager.kioskConfig?.gateLetter ?? 'A',
      'garitaNumero': int.tryParse(appManager.kioskConfig?.gate ?? '1') ?? 1,
      'doorNumber': 1,
      'fechaBarrera': fechaBarrera,
      'tipoMov': 'EXP',
      'contenedor': manager.contenedor1 ?? manager.contenedorExp ?? '',
      'contenedorDisv': manager.contenedorExp,
      'booking': manager.bookingExp,
      'tara': double.tryParse(manager.pesoTara ?? '0') ?? 0,
      'pesoIngreso': manager.pesoActualBascula,
      'pesoSalida': null,
      'sello1': manager.sello1Exp ?? manager.sello1,
      'sello2': manager.sello2Exp ?? manager.sello2,
      'sello3': manager.sello3Exp ?? manager.sello3,
      'sello4': manager.sello4Exp ?? manager.sello4,
      'sello5': manager.sello5,
      'tipoTran': 'I',
      'codProducto': 'P01',
      'codTipoCarga': 'T01',
      'codBuque': 'B01',
      'estadoIn': 'P',
      'estadoUp': 'C',
      'numTrans': int.tryParse(manager.atkId ?? '0') ?? 0,
      'taraExpoMin': 1000,
      'taraExpoMax': 5000,
      'deviceId': appManager.kioskConfig!.gate,
      'inOut': 'I',
      'procesoCompleto': 'N',
      'estadoVal': 1,
      'huellaJefe': '',
      'garitaOut': 2,
      'observaciones': '',
      'pesoBulto': 0,
      'ip': appManager.kioskConfig?.kioskServer ?? '', // ✅ agregado
      'idTraslados': manager.idTraslados ?? 0, // ✅ agregado
      'pesoContenedor':
          double.tryParse(manager.pesoActualBascula.toString()) ??
          0, // ✅ agregado
      'aniodisv': manager.aniodisv ?? DateTime.now().year, // ✅ agregado
      'numdisv': manager.numdisv ?? 0, // ✅ agregado
    };
  }

  Map<String, dynamic> _buildTerminarRequest(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) {
    final now = DateTime.now();
    final fechaBarrera =
        '${now.year}${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    return {
      'placa': _safePlaca(manager),
      'vehicleAccessId': int.tryParse(manager.atkId ?? '0') ?? 0,
      'btnGuardarEnabled': false,
      'btnCancelarEnabled': true,
      'ver': 0,
      'imprimir': 1,
      'pesoSalida': null,
      'pesoIngreso': manager.pesoActualBascula,
      'tara': double.tryParse(manager.pesoTara ?? '0') ?? 0,
      'contenedor': manager.contenedor1 ?? manager.contenedorExp,
      'booking': manager.bookingExp,
      'cedula': manager.driverCedula,
      'nombreConductor': manager.driverName,
      'cargaIMO': manager.vehiculoCargaImo,
      'garitaLetra': appManager.kioskConfig?.gateLetter ?? 'A',
      'usuarioNombre': appManager.requestUsername,
      'emailJefe': appManager.requestUsername,
      'ip': appManager.kioskConfig?.kioskServer,
      'tpg': int.tryParse(appManager.kioskConfig?.patio ?? '1') ?? 1,
      'doorNumber': 1,
      'garitaNumero': int.tryParse(appManager.kioskConfig?.gate ?? '1') ?? 1,
      'tipoMov': 'EXP',
      'fechaBarrera': fechaBarrera,
      'bodegueroUser': appManager.requestUsername,
    };
  }

  /* Map<String, dynamic> _buildCancelarRequest(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) {
    return {
      'placa': _safePlaca(manager),
      'numTrans': int.tryParse(manager.atkId ?? '0') ?? 0,
      'vehicleAccessId': int.tryParse(manager.atkId ?? '0') ?? 0,
      'btnGuardarEnabled': false,
      'pesoSalida': null,
      'pesoIngreso': manager.pesoActualBascula,
      'cedula': manager.driverCedula,
      'nombreConductor': manager.driverName,
      'cargaIMO': manager.vehiculoCargaImo,
      'garitaLetra': appManager.kioskConfig?.gateLetter ?? 'A',
      'usuarioNombre': appManager.requestUsername,
      'emailJefe': appManager.requestUsername,
      'ip': appManager.kioskConfig?.kioskServer,
      'observacionPedirAut': manager.errorMessage,
    };
  } */

  // ═══════════════════════════════════════════════════════════════
  // APPLY RESPONSES
  // ═══════════════════════════════════════════════════════════════

  void _applyInicializarResponse(
    Map<String, dynamic> response,
    AtkTransactionManager manager,
  ) {
    if (response['errorCode'] != 0) {
      manager.setError(response['message'] ?? 'Error en inicializar');
      return;
    }

    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      return;
    }

    final allData = <String, dynamic>{};

    // Datos básicos
    if (data['numtrans'] != null) {
      allData['atkId'] = data['numtrans'].toString();
    }

    if (data['estado'] != null) {
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

    // Sellos
    final sellos = data['sellos'] as List?;
    if (sellos != null && sellos.isNotEmpty) {
      if (sellos.length > 0 && sellos[0] != null)
        allData['sello1Exp'] = sellos[0];
      if (sellos.length > 1 && sellos[1] != null)
        allData['sello2Exp'] = sellos[1];
      if (sellos.length > 2 && sellos[2] != null)
        allData['sello3Exp'] = sellos[2];
      if (sellos.length > 3 && sellos[3] != null)
        allData['sello4Exp'] = sellos[3];
    }

    // DISV
    final disv = data['disv'] as Map<String, dynamic>?;
    if (disv != null) {
      if (disv['cliente'] != null) allData['clienteExp'] = disv['cliente'];
      if (disv['producto'] != null) allData['productoExp'] = disv['producto'];
      if (disv['tipoCarga'] != null)
        allData['vehiculoTipoCarga'] = disv['tipoCarga'];
      if (disv['cargaIMO'] != null)
        allData['vehiculoCargaImo'] = disv['cargaIMO'];
      if (disv['refrigerado'] != null)
        allData['vehiculoRefrigerado'] = disv['refrigerado'];
      if (disv['booking'] != null) allData['bookingExp'] = disv['booking'];
      if (disv['buque'] != null) allData['naveExp'] = disv['buque'];
    }

    manager.setMany(allData);
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
