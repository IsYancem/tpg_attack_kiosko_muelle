// lib/services/apis/exm_service.dart
// Autor: Abraham Yance
// Fecha: 2025-12-16
// Descripción: Servicio para endpoints de EXM (inicializar, guardar, terminar, cancelar, consultarRuta)

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/secure_storage_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/authApi_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/env_utils.dart';

class ExmServiceException implements Exception {
  final String message;
  ExmServiceException(this.message);
  @override
  String toString() => message;
}

class ExmService {
  final _log = LogService.instance;

  // ✅ Cache de headers (reutilizar de ExpService o crear específico)
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

  /// ✅ POST con auto-refresh (igual que EXP)
  Future<http.Response> _postWithAutoRefresh(
    Uri uri, {
    required String body,
    required String tag,
  }) async {
    var headers = await _authHeaders();

    final requestId = DateTime.now().millisecondsSinceEpoch;
    print('🌐 [HTTP-$requestId] POST $uri');
    print('📦 [HTTP-$requestId] Body length: ${body.length} bytes');
    print('🔑 [HTTP-$requestId] Headers: ${headers.keys.join(", ")}');

    try {
      var res = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      print(
        '✅ [HTTP-$requestId] Response: ${res.statusCode} (${res.body.length} bytes)',
      );

      if (res.statusCode == 401 || res.statusCode == 403) {
        print('🔄 [HTTP-$requestId] Auth error, refreshing token...');
        invalidateHeadersCache();

        final appState = AppStateManager.instance;
        final refreshed = await AuthApiService.refresh(appState);
        if (refreshed) {
          print('🔄 [HTTP-$requestId] RETRY con nuevo token');
          headers = await _authHeaders();
          res = await http
              .post(uri, headers: headers, body: body)
              .timeout(const Duration(seconds: 30));
          print('✅ [HTTP-$requestId] RETRY Response: ${res.statusCode}');
        }
      }

      return res;
    } on TimeoutException catch (e) {
      print('⏱️ [HTTP-$requestId] TIMEOUT después de 30s $e');
      rethrow;
    } catch (e) {
      print('❌ [HTTP-$requestId] ERROR: $e');
      rethrow;
    }
  }

  String get _baseUrl {
    final url = dotenv.env['BASE_MIDDLEWARE_URL'] ?? '';
    if (url.isEmpty) {
      throw ExmServiceException('BASE_MIDDLEWARE_URL no configurada');
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
    final uri = Uri.parse('${_baseUrl}kiosk/api/exm/inicializar');

    try {
      final body = _buildInicializarRequest(manager, appManager);
      final bodyJson = json.encode(body);

      final resp = await _postWithAutoRefresh(
        uri,
        body: bodyJson,
        tag: 'EXM_INICIALIZAR',
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw ExmServiceException('HTTP ${resp.statusCode}');
      }

      final decoded =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

      // Aplicar respuesta
      _applyInicializarResponse(decoded, manager);

      return decoded;
    } catch (e, st) {
      _log.logError('EXM_INICIALIZAR_EX', e, st);
      manager.setError('Error en inicializar EXM: $e');
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
    final uri = Uri.parse('${_baseUrl}kiosk/api/exm/guardar');

    try {
      final body = _buildGuardarRequest(manager, appManager);
      final bodyJson = json.encode(body);

      _log.logRequest('EXM_GUARDAR_PAYLOAD', body);

      final resp = await _postWithAutoRefresh(
        uri,
        body: bodyJson,
        tag: 'EXM_GUARDAR',
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw ExmServiceException('HTTP ${resp.statusCode}');
      }

      final decoded =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

      // Aplicar respuesta
      _applyGuardarResponse(decoded, manager);

      return decoded;
    } catch (e, st) {
      _log.logError('EXM_GUARDAR_EX', e, st);
      manager.setError('Error en guardar EXM: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CONSULTAR RUTA (Proyección y mapa)
  // ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> consultarRuta(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) async {
    final uri = Uri.parse('${_baseUrl}kiosk/api/exm/consultarRuta');

    try {
      final body = _buildConsultarRutaRequest(manager, appManager);
      final bodyJson = json.encode(body);

      print(
        '📤 [EXM_CONSULTAR_RUTA] Payload enviado:\n'
        '${const JsonEncoder.withIndent("  ").convert(body)}',
      );

      _log.logRequest('EXM_CONSULTAR_RUTA_PAYLOAD', body);

      final resp = await _postWithAutoRefresh(
        uri,
        body: bodyJson,
        tag: 'EXM_CONSULTAR_RUTA',
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw ExmServiceException('HTTP ${resp.statusCode}');
      }

      final decoded =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

      print('─────────────────────────────────────────────');
      print('📥 [EXM_CONSULTAR_RUTA] Respuesta completa del backend:');
      print(const JsonEncoder.withIndent('  ').convert(decoded));
      print('─────────────────────────────────────────────\n');

      // ✅ AQUÍ estaba faltando
      await _applyConsultarRutaResponse(decoded, manager);

      // ✅ aquí estabas loggeando body; debe ser decoded
      _log.logRequest('EXM_CONSULTAR_RUTA_RESPONSE', decoded);

      return decoded;
    } catch (e, st) {
      _log.logError('EXM_CONSULTAR_RUTA_EX', e, st);
      rethrow;
    }
  }

  Future<void> _applyConsultarRutaResponse(
    Map<String, dynamic> response,
    AtkTransactionManager manager,
  ) async {
    if (response['errorCode'] != 0) {
      return;
    }

    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      return;
    }

    final proyeccion = data['proyeccion'] as Map<String, dynamic>?;
    final mapa = data['mapa'] as Map<String, dynamic>?;
    final printBlock = data['print'] as Map<String, dynamic>?;
    final ui = data['ui'];
    final services = data['services'];

    final mapaUrl = mapa?['ruta']?.toString();
    final ubicacion = mapa?['ubicacion']?.toString();

    // ✅ descarga bytes del mapa para imprimirlo en el ticket combinado
    Uint8List? mapaBytes;
    if (mapaUrl != null && mapaUrl.trim().isNotEmpty) {
      mapaBytes = await _tryDownloadBytes(mapaUrl.trim());
    }

    final allData = <String, dynamic>{
      // snapshots (para auditoría y debug)
      'rutaResult': data, // o response completo si quieres: response
      'daniosExp': (printBlock?['info']?['danios'] ?? '').toString(),

      // proyección (si quieres mostrarlos en UI)
      if (proyeccion != null) 'exmProyeccion': proyeccion,
      if (proyeccion?['label'] != null) 'mensajeInferior': proyeccion!['label'],

      // ubicar en UI principal
      if (ubicacion != null && ubicacion.trim().isNotEmpty)
        'ubicacion': ubicacion,

      // mapa
      if (mapaUrl != null && mapaUrl.trim().isNotEmpty) 'mapaUrl': mapaUrl,
      if (mapaBytes != null) 'mapaBytes': mapaBytes,

      // guardar bloques sueltos por si necesitas luego
      'exmConsultarRutaUi': ui,
      'exmConsultarRutaServices': services,
      'exmConsultarRutaPrint': printBlock,
    };

    manager.setMany(allData);
  }

  Future<Uint8List?> _tryDownloadBytes(String url) async {
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return res.bodyBytes;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TERMINAR
  // ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> terminar(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) async {
    final uri = Uri.parse('${_baseUrl}kiosk/api/exm/terminar');

    try {
      final body = _buildTerminarRequest(manager, appManager);
      final bodyJson = json.encode(body);

      print(
        '📤 [EXM_TERMINAR] Payload enviado:\n'
        '${const JsonEncoder.withIndent("  ").convert(body)}',
      );

      _log.logRequest('EXM_TERMINAR_PAYLOAD', body);

      final resp = await _postWithAutoRefresh(
        uri,
        body: bodyJson,
        tag: 'EXM_TERMINAR',
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw ExmServiceException('HTTP ${resp.statusCode}');
      }

      final decoded =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

      return decoded;
    } catch (e, st) {
      _log.logError('EXM_TERMINAR_EX', e, st);
      manager.setError('Error en terminar EXM: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CANCELAR
  // ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> cancelar(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) async {
    final uri = Uri.parse('${_baseUrl}kiosk/api/exm/cancelar');

    try {
      final body = _buildCancelarRequest(manager, appManager);
      final bodyJson = json.encode(body);

      final resp = await _postWithAutoRefresh(
        uri,
        body: bodyJson,
        tag: 'EXM_CANCELAR',
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw ExmServiceException('HTTP ${resp.statusCode}');
      }

      final decoded =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

      _log.logRequest('EXM_CANCELAR_OK', {'message': decoded['message']});

      return decoded;
    } catch (e, st) {
      _log.logError('EXM_CANCELAR_EX', e, st);
      // No lanzar excepción aquí, cancelar es best-effort
      return {
        'errorCode': 1,
        'message': 'Error en cancelar EXM: $e',
        'data': null,
      };
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD REQUESTS (basado en DTOs del backend)
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
      'numPlaca': manager.vehiculoPlaca,
      'cedula': manager.driverCedula,
      'nombres': manager.driverName,
      'vehicle_access_id': int.parse(manager.atkId ?? '0'),
      'TPG': appManager.kioskConfig?.patio,
      'garita_letra': appManager.kioskConfig?.gateLetter,
      'garita_numero': appManager.kioskConfig?.gate,
      'door_number': 1,
      'fecha_barrera': fechaBarrera,
      'tipo_mov': 'EXM',
      'contenedor': manager.contenedor1 ?? manager.contenedorExp,
      'producto': manager.productoExp,
      'ESTADO': 'P',
      'foto_chofer': manager.driverPhotoUrl,
      'peso_salida': manager.pesoSalida,
    };
  }

  Map<String, dynamic> _buildGuardarRequest(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) {
    return {
      // ═══════════════════════════════════════════════════════
      // 🔹 DATOS BÁSICOS DE TRANSACCIÓN
      // ═══════════════════════════════════════════════════════
      'tipoTran': 'I', // ✅ SOLO 1 CARÁCTER: 'I' o 'U'
      'num_trans': int.tryParse(manager.numTrans ?? '0') ?? 0,
      'vehicle_access_id': int.tryParse(manager.atkId ?? '0') ?? 0,

      // ═══════════════════════════════════════════════════════
      // 🔹 DATOS DE GARITA/KIOSKO
      // ═══════════════════════════════════════════════════════
      'garita_letra': appManager.kioskConfig?.gateLetter ?? 'A',
      'garita_numero': int.tryParse(appManager.kioskConfig?.gate ?? '1') ?? 1,
      'device_id': appManager.kioskConfig?.bascula ?? '',
      'door_number': 1, // ✅ NUMBER, no string
      'door_out': 2, // ✅ NUMBER, no string
      'ip': appManager.kioskConfig?.kioskServer ?? '0.0.0.0',

      // ═══════════════════════════════════════════════════════
      // 🔹 DATOS DEL VEHÍCULO
      // ═══════════════════════════════════════════════════════
      'numPlaca': manager.vehiculoPlaca ?? '',

      // ═══════════════════════════════════════════════════════
      // 🔹 DATOS DEL CONDUCTOR
      // ═══════════════════════════════════════════════════════
      'chofer': manager.driverCedula ?? '',
      'nombres': manager.driverName ?? '',

      // ═══════════════════════════════════════════════════════
      // 🔹 DATOS DE CONTENEDORES
      // ═══════════════════════════════════════════════════════
      'contenedor': manager.contenedor1 ?? manager.contenedorExp ?? '',
      'contenedor_1': manager.contenedor1 ?? manager.contenedorExp ?? '',
      'nom_contenedor': manager.contenedor1 ?? manager.contenedorExp ?? '',
      'booking': manager.bookingExp ?? '',

      // ═══════════════════════════════════════════════════════
      // 🔹 DATOS DE PESOS
      // ═══════════════════════════════════════════════════════
      'peso_ing': manager.pesoActualBascula,
      'tara': double.tryParse(manager.pesoTara ?? '0') ?? 0,
      'peso_salida': null,
      'peso_contenedor': manager.pesoTara != null
          ? double.tryParse(manager.pesoTara!)
          : null,

      // Validación de tara
      'taraExpoMin': 1000,
      'taraExpoMax': 5000,
      'Tolerancia_dsp_vacio': 10,

      // Indica si se pesa o no
      'pesa': 'S',

      // ═══════════════════════════════════════════════════════
      // 🔹 DATOS DE TRASLADO/DISV (si aplica)
      // ═══════════════════════════════════════════════════════
      'id_traslado': manager.idTraslados,
      'aniodisv': manager.aniodisv,
      'numdisv': manager.numdisv,

      // ═══════════════════════════════════════════════════════
      // 🔹 FECHAS
      // ═══════════════════════════════════════════════════════
      'fechaIng': manager.exmFechaIng ?? DateTime.now().toIso8601String(),
      'fecha_mov_ini': DateTime.now().toIso8601String(),
      'fecha_barrera': DateTime.now().toIso8601String(),

      // ═══════════════════════════════════════════════════════
      // 🔹 USUARIO Y AUDITORÍA
      // ═══════════════════════════════════════════════════════
      'usuario_nombre': appManager.requestUsername,
    };
  }

  Map<String, dynamic> _buildConsultarRutaRequest(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) {
    return {
      'contenedor': manager.contenedor1 ?? manager.contenedorExp ?? '',
      'booking': manager.bookingExp ?? '',
      'garita_numero': int.tryParse(appManager.kioskConfig?.gate ?? '1') ?? 1,
      'numPlaca': manager.vehiculoPlaca ?? '',
      'danos': manager.daniosExp ?? manager.vehiculoObservaciones ?? '',
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
      'btn_guardar_enabled': false,
      'btn_cancelar_enabled': true,
      'peso_salida': manager.pesoSalida ?? '',
      'pesa': 'S', // Valor por defecto, ajustar si es necesario
      'TPG': appManager.kioskConfig?.patio ?? 'TPG1',
      'garita_letra': appManager.kioskConfig?.gateLetter ?? 'A',
      'garita_numero': appManager.kioskConfig?.gate ?? '1',
      'door_number': 1,
      'fecha_barrera': fechaBarrera,
      'numPlaca': manager.vehiculoPlaca ?? '',
      'TIPOMOV': 'EXM',
      'vehicle_access_id': int.tryParse(manager.atkId ?? '0') ?? 0,
      'bodegueroUser': appManager.requestUsername,
      'ruc': manager.driverCedula ?? '',
      'contenedor': manager.contenedor1 ?? manager.contenedorExp ?? '',
      'booking': manager.bookingExp ?? '',
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // RECARGAR DATOS (DISV: atk_pa_cons_disv_exp1)
  // ═══════════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> recargarDatos(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) async {
    // ✅ Recomiendo mantener coherencia con tus rutas EXM:
    // POST ${BASE}/kiosk/api/exm/recargarDatos
    final uri = Uri.parse('${_baseUrl}kiosk/api/exm/recargarDatos');

    try {
      final body = _buildRecargarDatosRequest(manager);
      final bodyJson = json.encode(body);

      _log.logRequest('EXM_RECARGAR_DATOS_PAYLOAD', body);

      final resp = await _postWithAutoRefresh(
        uri,
        body: bodyJson,
        tag: 'EXM_RECARGAR_DATOS',
      );

      if (resp.statusCode != 200 && resp.statusCode != 201) {
        throw ExmServiceException('HTTP ${resp.statusCode}');
      }

      final decoded =
          json.decode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;

      _applyRecargarDatosResponse(decoded, manager);

      return decoded;
    } catch (e, st) {
      _log.logError('EXM_RECARGAR_DATOS_EX', e, st);
      // ⚠️ este servicio normalmente no debería tumbar toda la transacción;
      // el runner decidirá si lo trata como fatal o warning.
      rethrow;
    }
  }

  Map<String, dynamic> _buildRecargarDatosRequest(
    AtkTransactionManager manager,
  ) {
    return {
      // backend espera estos (según tu DTO swagger)
      'transaccion': 'RECARGAR-DATOS',
      'id': int.tryParse(manager.atkId ?? '0') ?? 0,
      'statu': 50,
      'contenedor': manager.contenedor1 ?? manager.contenedorExp ?? '',
    };
  }

  void _applyRecargarDatosResponse(
    Map<String, dynamic> response,
    AtkTransactionManager manager,
  ) {
    if (response['errorCode'] != 0) {
      // No hacemos setError aquí por defecto: lo maneja el runner como warning/fatal
      print('⚠️ [EXM_RECARGAR_DATOS] errorCode != 0: ${response['message']}');
      return;
    }

    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      print('⚠️ [EXM_RECARGAR_DATOS] Respuesta inválida: falta data');
      return;
    }

    final resolved = data['resolved'] as Map<String, dynamic>?;
    final ui = data['ui'];
    final services = data['services'];

    final allData = <String, dynamic>{
      // snapshots completos (para debug / auditoría)
      'exmRecargarRaw': response,
      'exmRecargarData': data,
      'exmRecargarResolved': resolved,
      'exmRecargarUi': ui,
      'exmRecargarServices': services,
    };

    if (resolved != null) {
      // Mapeo “donde corresponde” (campos existentes en tu manager)
      final cliente = resolved['clientes_disv']?.toString();
      final producto = resolved['producto_disv']?.toString();
      final tipoCarga = resolved['tipo_carga']?.toString();
      final imo = resolved['cargaimo']?.toString();
      final placa = resolved['placa_vehiculo_disv']?.toString();
      final refrigerado = resolved['refrigerado_disv']?.toString();
      final cedula = resolved['cedula']?.toString();
      final booking = resolved['booking_disv']?.toString();
      final docTrans = resolved['doc_transporte_disv']?.toString();

      final nomCont = resolved['nom_contenedor']?.toString();
      final contNorm = resolved['contenedor_normalizado']?.toString();

      // exportador (columna 2/3 EXP)
      if (cliente != null && cliente.trim().isNotEmpty)
        allData['clienteExp'] = cliente;
      if (producto != null && producto.trim().isNotEmpty)
        allData['productoExp'] = producto;
      if (booking != null && booking.trim().isNotEmpty)
        allData['bookingExp'] = booking;

      // vehiculo/conductor
      if (placa != null &&
          placa.trim().isNotEmpty &&
          (manager.vehiculoPlaca ?? '').isEmpty) {
        allData['vehiculoPlaca'] = placa;
      }
      if (cedula != null &&
          cedula.trim().isNotEmpty &&
          (manager.driverCedula ?? '').isEmpty) {
        allData['driverCedula'] = cedula;
      }

      // tipo carga / IMO / refrigerado: lo guardo en campos “vehiculo…”
      if (tipoCarga != null && tipoCarga.trim().isNotEmpty)
        allData['vehiculoTipoCarga'] = tipoCarga;
      if (imo != null && imo.trim().isNotEmpty)
        allData['vehiculoCargaImo'] = imo;
      if (refrigerado != null && refrigerado.trim().isNotEmpty)
        allData['vehiculoRefrigerado'] = refrigerado;

      // contenedor (mantener sincronizado)
      final contFinal = (nomCont != null && nomCont.trim().isNotEmpty)
          ? nomCont
          : (contNorm != null && contNorm.trim().isNotEmpty ? contNorm : null);

      if (contFinal != null && contFinal.isNotEmpty) {
        allData['contenedor1'] = contFinal;
        allData['contenedorExp'] = contFinal;
        allData['contenedor'] = contFinal;
      }

      // sellos (reutilizo tus campos existentes)
      final s1 = resolved['sello1']?.toString();
      final s2 = resolved['sello2']?.toString();
      final s3 = resolved['sello3']?.toString();
      final s4 = resolved['sello4']?.toString();

      if (s1 != null && s1.trim().isNotEmpty) allData['sello1'] = s1;
      if (s2 != null && s2.trim().isNotEmpty) allData['sello2'] = s2;
      if (s3 != null && s3.trim().isNotEmpty) allData['sello3'] = s3;
      if (s4 != null && s4.trim().isNotEmpty) allData['sello4'] = s4;

      if (s1 != null && s1.trim().isNotEmpty) allData['sello1Exp'] = s1;
      if (s2 != null && s2.trim().isNotEmpty) allData['sello2Exp'] = s2;
      if (s3 != null && s3.trim().isNotEmpty) allData['sello3Exp'] = s3;
      if (s4 != null && s4.trim().isNotEmpty) allData['sello4Exp'] = s4;

      // disv
      final anio = resolved['aniodisv'];
      final num = resolved['numdisv'];
      if (anio != null) allData['aniodisv'] = anio;
      if (num != null) allData['numdisv'] = num;

      // extras EXM (los guardo en campos específicos nuevos del manager)
      if (docTrans != null && docTrans.trim().isNotEmpty)
        allData['exmDocTransporteDisv'] = docTrans;

      // observación
      final obs = resolved['observacion']?.toString();
      if (obs != null && obs.trim().isNotEmpty) {
        allData['vehiculoObservaciones'] =
            obs; // o si prefieres, mensajeInferior
        allData['mensajeInferior'] = obs;
      }
    }

    manager.setMany(allData);
  }

  Map<String, dynamic> _buildCancelarRequest(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) {
    return {
      'confirm': true,
      'vehicle_access_id': int.tryParse(manager.atkId ?? '0') ?? 0,
      'num_trans': int.tryParse(manager.numTrans ?? '0') ?? 0,
      'numPlaca': manager.vehiculoPlaca ?? '',
      'garita_letra': appManager.kioskConfig?.gateLetter ?? 'A',
      'usuario_nombre': appManager.requestUsername,
      'mensaje_error': manager.errorMessage ?? '',
      'email_jefe': null,
      'ip': appManager.kioskConfig?.kioskServer ?? '',
      'cedula': manager.driverCedula ?? '',
      'carga_s_n': 'N',
      'cargaimo': manager.vehiculoCargaImo ?? 'P02',
      'group1': 'cctv',
      'nombre_autor': 'CCTV-JEFE',
      'tipo_novedad': 941,
      'accion': 941,
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // APPLY RESPONSES
  // ═══════════════════════════════════════════════════════════════
  void _applyInicializarResponse(
    Map<String, dynamic> response,
    AtkTransactionManager manager,
  ) {
    print('─────────────────────────────────────────────');
    print('📥 [EXM_INICIALIZAR] Respuesta completa del backend:');
    print(const JsonEncoder.withIndent('  ').convert(response));

    if (response['errorCode'] != 0) {
      manager.setError(response['message'] ?? 'Error en inicializar EXM');
      print('❌ [EXM_INICIALIZAR] Error detectado: ${response['message']}');
      print('─────────────────────────────────────────────\n');
      return;
    }

    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) {
      manager.setError('Respuesta inválida: falta data');
      print('⚠️ [EXM_INICIALIZAR] No se encontró campo "data".');
      print('─────────────────────────────────────────────\n');
      return;
    }

    final resolved = data['resolved'] as Map<String, dynamic>?;
    final monitor = data['monitor'] as Map<String, dynamic>?;
    final services = data['services'] as Map<String, dynamic>?;

    final requested = monitor?['requested'] as Map<String, dynamic>?;
    final sent = monitor?['sent'] as Map<String, dynamic>?;

    // ✅ aquí guardamos ABSOLUTAMENTE TODO (raw + data + bloques)
    final allData = <String, dynamic>{
      // snapshots completos
      'exmInicializarRaw': response,
      'exmInicializarData': data,
      'exmResolved': resolved,
      'exmMonitorRequested': requested,
      'exmMonitorSent': sent,
      'exmServices': services,

      // también actualizamos "atkId" (tu flujo lo usa)
      if (data['numero'] != null) 'atkId': data['numero'].toString(),
    };

    // ─────────────────────────────────────────────
    // ✅ RESOLVED → campos tipados + reutilizar tus campos existentes
    // ─────────────────────────────────────────────
    if (resolved != null) {
      final placa = resolved['placa']?.toString();
      final cont = resolved['contenedor']?.toString();
      final pesoIng = resolved['pesoing'];
      final tara = resolved['tara'];

      int? numTran;
      final dataNumero = data['numero'];
      if (dataNumero != null) {
        numTran = int.tryParse(dataNumero.toString());
      }

      if (numTran == null) {
        final srv = services?['atk_numtrans_exm_fp']?['data']?['response'];
        final srvNum = srv?['numtran'];
        if (srvNum != null) {
          numTran = int.tryParse(srvNum.toString());
        }
      }

      if (placa != null && placa.isNotEmpty) {
        allData['vehiculoPlaca'] = placa;
      }

      if (cont != null && cont.isNotEmpty) {
        allData['contenedor1'] = cont;
        allData['contenedorExp'] = cont;
        allData['contenedor'] = cont; // por si alguna UI usa "contenedor"
      }

      // pesoing
      if (pesoIng != null) {
        allData['pesoIngreso'] = pesoIng.toString();
        allData['pesoActualBascula'] = _toDoubleSafe(pesoIng) ?? 0.0;
      }

      // tara
      if (tara != null) {
        allData['pesoTara'] = tara.toString();
      }

      if (numTran != null && numTran > 0) {
        allData['numTrans'] = numTran.toString();
        allData['exmNumTran'] = numTran;
      }

      // flags/campos extra EXM
      allData['exmPesa'] = resolved['pesa']?.toString();
    }

    // ─────────────────────────────────────────────
    // ✅ MONITOR.REQUESTED → guardar completo + tipado
    // ─────────────────────────────────────────────
    if (requested != null) {
      allData['exmMonitorAccion'] = requested['accion'];
      allData['exmMonitorPatio'] = requested['patio'];
      allData['exmMonitorBascula'] = requested['bascula'];
      allData['exmMonitorNumBascula'] = requested['num_bascula'];
      allData['exmMonitorBarrera'] = requested['barrera'];
      allData['exmMonitorFechaBarrera'] = requested['fecha_barrera'];
      allData['exmMonitorCedula'] = requested['cedula'];
      allData['exmMonitorNombres'] = requested['nombres'];
      allData['exmMonitorFoto'] = requested['foto'];
      allData['exmMonitorTransaccion'] = requested['transaccion'];
      allData['exmMonitorTipoMov'] = requested['tipo_mov'];
      allData['exmMonitorContenedor'] = requested['contenedor'];
      allData['exmMonitorInOut'] = requested['in_out'];
      allData['exmMonitorVehicleAccessId'] = requested['vehicle_access_id'];

      // opcional: si quieres sincronizar con tus campos existentes del chofer
      if ((manager.driverCedula ?? '').isEmpty && requested['cedula'] != null) {
        allData['driverCedula'] = requested['cedula']?.toString();
      }
      if ((manager.driverName ?? '').isEmpty && requested['nombres'] != null) {
        allData['driverName'] = requested['nombres']?.toString();
      }
      if ((manager.driverPhotoUrl ?? '').isEmpty && requested['foto'] != null) {
        allData['driverPhotoUrl'] = requested['foto']?.toString();
      }
    }

    // ─────────────────────────────────────────────
    // ✅ MONITOR.SENT → guardar completo + tipado
    // ─────────────────────────────────────────────
    if (sent != null) {
      allData['exmMonitorIp'] = sent['ip'];
      allData['exmMonitorPuerto'] = sent['puerto'];
      allData['exmMonitorOk'] = sent['ok'];
    }

    print('─────────────────────────────────────────────');
    print('💾 [EXM_INICIALIZAR] Datos que se guardarán en manager.setMany():');
    print(const JsonEncoder.withIndent('  ').convert(allData));
    print('─────────────────────────────────────────────\n');

    manager.setMany(allData);
  }

  // Helper local: convertir a double sin romperte por tipos mixtos
  double? _toDoubleSafe(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    if (v is String) {
      final s = v.trim().replaceAll(',', '.');
      if (s.isEmpty) return null;
      return double.tryParse(s);
    }
    return null;
  }

  void _applyGuardarResponse(
    Map<String, dynamic> response,
    AtkTransactionManager manager,
  ) {
    if (response['errorCode'] != 0) {
      manager.setError(response['message'] ?? 'Error al guardar EXM');
      return;
    }

    final data = response['data'] as Map<String, dynamic>?;
    if (data == null) return;

    // snapshot completo para auditoría
    final allData = <String, dynamic>{
      'exmGuardarRaw': response,
      'exmGuardarData': data,
    };

    // intenta mapear campos comunes (según como tu backend responda)
    final numTrans = data['num_trans'] ?? data['numTrans'] ?? data['numero'];
    if (numTrans != null) {
      final nt = numTrans.toString();
      if (nt.isNotEmpty && nt != '0') {
        allData['numTrans'] = nt;
        allData['exmNumTran'] = int.tryParse(nt);
      }
    }

    final atkId =
        data['vehicle_access_id'] ?? data['vehicleAccessId'] ?? data['atkId'];
    if (atkId != null) {
      final id = atkId.toString();
      if (id.isNotEmpty && id != '0') allData['atkId'] = id;
    }

    // placa/contenedor por si vienen reafirmados
    final placa = data['numPlaca'] ?? data['placa'];
    if (placa != null && placa.toString().trim().isNotEmpty) {
      allData['vehiculoPlaca'] = placa.toString();
    }

    final cont =
        data['contenedor'] ?? data['contenedor_1'] ?? data['nom_contenedor'];
    if (cont != null && cont.toString().trim().isNotEmpty) {
      allData['contenedor1'] = cont.toString();
      allData['contenedorExp'] = cont.toString();
      allData['contenedor'] = cont.toString();
    }

    // pesos (si el SP responde)
    final pesoIng = data['peso_ing'] ?? data['pesoIngreso'];
    if (pesoIng != null) {
      allData['pesoIngreso'] = pesoIng.toString();
    }

    final tara = data['tara'] ?? data['pesoTara'];
    if (tara != null) {
      allData['pesoTara'] = tara.toString();
    }

    final pesoSalida = data['peso_salida'] ?? data['pesoSalida'];
    if (pesoSalida != null) {
      allData['pesoSalida'] = pesoSalida.toString();
    }

    manager.setMany(allData);
  }
}
