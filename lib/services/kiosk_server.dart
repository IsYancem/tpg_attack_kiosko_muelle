// lib/services/kiosk_server.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:tpg_attack_kiosko_muelle/models/attack/kioskConfig_model.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';

class KioskServer {
  KioskServer._();

  static KioskConfigModel? _globals;

  /// Llamar una vez después de cargar configuración.
  static void configure({required KioskConfigModel globals}) {
    _globals = globals;
    LogService.instance.logRequest('KioskServer.configure', {
      'kioskServer': globals.kioskServer,
      'kioskServerPort': globals.kioskServerPort,
    });
  }

  static Future<bool> connectMonitorTransaction({
    required String accion,
    required String message,
    required bool error,
    String? patio,
    String? bascula,
    String? gate,
    String? tipoMov,
    String? desMov,
    String? contenedor,
    String? turno,
    String? ip,
    int? port,
  }) async {
    final payload = {
      'Accion': accion,
      'Patio': patio,
      'Bascula': bascula,
      'Gate': gate,
      'Error': error,
      'Message': message,
      if (tipoMov != null) 'TipoMov': tipoMov,
      if (desMov != null) 'DesMov': desMov,
      if (contenedor != null) 'Contenedor': contenedor,
      if (turno != null) 'Turno': turno,
    };

    try {
      final jsonString = jsonEncode(payload);
      final bytes = utf8.encode(jsonString);

      LogService.instance.logRequest('KioskServer.prepareTransactionPayload', {
        'payload': payload,
      });

      final ok = await _send(bytes, ip: ip, port: port);
      LogService.instance.logRequest('KioskServer.connectMonitorTransaction', {
        'accion': accion,
        'tipo_mov': tipoMov,
        'des_mov': desMov,
        'contenedor': contenedor,
        'turno': turno,
        'result': ok ? 'success' : 'failure',
      });
      return ok;
    } catch (e, st) {
      LogService.instance.logError(
        'KioskServer.connectMonitorTransaction',
        e,
        st,
      );
      return false;
    }
  }

  static Future<bool> _send(List<int> data, {String? ip, int? port}) async {
    final targetIp = ip ?? _globals?.kioskServer;
    final targetPort = port ?? _globals?.kioskServerPort;

    if (targetIp == null || targetIp.isEmpty || targetPort == null) {
      LogService.instance.logWarning('KioskServer.invalidConfig', {
        'ip': targetIp,
        'port': targetPort,
      });
      return false;
    }

    final sw = Stopwatch()..start();
    try {
      LogService.instance.logRequest('KioskServer.Socket.connect', {
        'ip': targetIp,
        'port': targetPort,
      });

      final socket = await Socket.connect(
        targetIp,
        targetPort,
      ).timeout(const Duration(seconds: 3));

      socket.add(data);
      await socket.flush();
      await socket.close();
      socket.destroy();

      LogService.instance.logRequest('KioskServer.Socket.send', {
        'bytes': data.length,
        'elapsed_ms': sw.elapsedMilliseconds,
      });
      return true;
    } on TimeoutException catch (e, st) {
      LogService.instance.logError('KioskServer.Socket.timeout', e, st);
      return false;
    } on SocketException catch (e, st) {
      LogService.instance.logError('KioskServer.Socket.exception', e, st);
      return false;
    } catch (e, st) {
      LogService.instance.logError('KioskServer.Socket.unknownError', e, st);
      return false;
    } finally {
      sw.stop();
    }
  }

  /// ← NUEVO MÉTODO: Para enviar datos completos del chofer (acción CHO)
  static Future<bool> connectMonitorChofer({
    required String accion,
    required String message,
    required bool error,
    String? patio,
    String? bascula,
    String? gate,
    String? nombres,
    String? cedula,
    String? foto,
    String? ip,
    int? port,
  }) async {
    final payload = {
      'Accion': accion,
      'Patio': patio,
      'Bascula': bascula,
      'Gate': gate,
      'Error': error,
      'Message': message,
      if (nombres != null) 'Nombres': nombres,
      if (cedula != null) 'Cedula': cedula,
      if (foto != null) 'Foto': foto,
    };

    try {
      final jsonString = jsonEncode(payload);
      final bytes = utf8.encode(jsonString);

      LogService.instance.logRequest('KioskServer.prepareChoferPayload', {
        'payload': payload,
      });

      final ok = await _send(bytes, ip: ip, port: port);
      LogService.instance.logRequest('KioskServer.connectMonitorChofer', {
        'accion': accion,
        'result': ok ? 'success' : 'failure',
      });
      return ok;
    } catch (e, st) {
      LogService.instance.logError(
        'KioskServer.connectMonitorChofer',
        e,
        st,
      );
      return false;
    }
  }

  static Future<bool> connectMonitor({
    required String accion,
    required String message,
    required bool error,
    String? patio,
    String? bascula,
    String? gate,
    String? ip,
    int? port,
  }) async {
    final payload = {
      'Accion': accion,
      'Patio': patio,
      'Bascula': bascula,
      'Gate': gate,
      'Error': error,
      'Message': message,
    };

    try {
      final jsonString = jsonEncode(payload);
      final bytes = utf8.encode(jsonString);

      LogService.instance.logRequest('KioskServer.preparePayload', {
        'payload': payload,
      });

      final ok = await _send(bytes, ip: ip, port: port);
      LogService.instance.logRequest('KioskServer.connectMonitor', {
        'accion': accion,
        'error': error,
        'result': ok ? 'success' : 'failure',
      });
      return ok;
    } catch (e, st) {
      LogService.instance.logError('KioskServer.connectMonitor', e, st);
      return false;
    }
  }

  /// Procesar Monitor Attack (equivalente al código C#)
  static Future<bool> procesarMonitorAttack({
    required String jsonData,
    required String tipo,
  }) async {
    LogService.instance.logRequest('KioskServer.procesarMonitorAttack', {
      'action': 'starting_monitor_attack_processing',
      'tipo': tipo,
      'json_length': jsonData.length,
    });

    try {
      // Parsear el JSON para validar formato
      final info = json.decode(jsonData);

      LogService.instance.logRequest(
        'KioskServer.procesarMonitorAttack',
        {'action': 'json_parsed_successfully', 'info': info},
      );

      // Por ahora solo simulamos el procesamiento exitoso
      // IMPLEMENTAR: Aquí iría la lógica específica del Monitor Attack
      await LogService.instance
          .logRequest('KioskServer.procesarMonitorAttack', {
            'action': 'monitor_attack_processed',
            'success': true,
            'json_data': jsonData,
            'tipo': tipo,
          });

      return true;
    } catch (e, st) {
      LogService.instance.logError(
        'KioskServer.procesarMonitorAttack',
        e,
        st,
      );
      return false;
    }
  }
}
