// lib/services/status/rfid_service.dart
// Autor: Abraham Yance
// Actualizado: 2025-11-21
// 🚀 RfidService: WebSocket - detección de vehículos RFID (SIMPLIFICADO)

import 'dart:async';
import 'dart:convert';
import 'package:tpg_attack_kiosko_muelle/models/websockets/websocket_models.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:tpg_attack_kiosko_muelle/services/kiosk_server.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/status_log_bus.dart';
import 'base_service.dart';

class RfidService extends BaseService {
  String? _lastUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;

  bool _connected = false;
  bool _disposed = false;
  bool _shouldReconnect = true;
  bool _closingIntentionally = false;

  final String? patio;
  final String? bascula;
  final String? gate;

  // Streams
  final _connectedCtrl = StreamController<bool>.broadcast();
  final _vehicleCtrl = StreamController<VehicleResponse>.broadcast();

  Stream<bool> get isConnected$ => _connectedCtrl.stream;
  Stream<VehicleResponse> get vehicleDetected$ => _vehicleCtrl.stream;

  RfidService({required super.onStatus, this.patio, this.bascula, this.gate});

  String? _lastVehicleEmitKey;
  DateTime? _lastVehicleEmitAt;
  static const Duration _emitDedupWindow = Duration(seconds: 2);

  /// Conectar al WebSocket
  Future<void> connect(String url) async {
    _lastUrl = url;
    _stop();

    LogService.instance.logRequest('RFID_WS_CONNECTING', {
      'url': url,
      'timestamp': DateTime.now().toIso8601String(),
    });
    StatusLogBus.instance.addText('RFID', '🔄 Conectando a: $url');

    try {
      final uri = Uri.parse(url.trim());
      final headers = _buildHeaders();

      _channel = IOWebSocketChannel.connect(uri, headers: headers);

      _connected = true;
      setConnected(true);
      _connectedCtrl.add(true);
      StatusLogBus.instance.addStatus('RFID', true);
      StatusLogBus.instance.addText('RFID', '🔗 WebSocket RFID conectado');

      _channelSub = _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      startProbeLoop(() async => _connected);
    } catch (e, st) {
      _handleConnectionError(e, st, url);
    }
  }

  bool _shouldEmitVehicle(VehicleResponse response) {
    final record = response.record;
    if (record == null) return false;

    final key = '${response.gate}|${response.side}|${record.regNumber}';
    final now = DateTime.now();

    if (_lastVehicleEmitKey == key &&
        _lastVehicleEmitAt != null &&
        now.difference(_lastVehicleEmitAt!) <= _emitDedupWindow) {
      return false;
    }

    _lastVehicleEmitKey = key;
    _lastVehicleEmitAt = now;
    return true;
  }

  /// Maneja datos entrantes
  void _onData(dynamic data) {
    final text = data.toString().trim();
    if (text.isEmpty) return;

    // Solo mostrar en log si no es JSON válido de vehículo
    if (!_looksLikeVehicleJson(text)) {
      StatusLogBus.instance.addText('RFID', '📨 $text');
    }

    _processJsonData(text);
  }

  bool _looksLikeVehicleJson(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        return json.containsKey('code') &&
            json.containsKey('message') &&
            json.containsKey('record');
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Maneja errores del stream
  void _onError(dynamic error) {
    _connected = false;
    setConnected(false);
    _connectedCtrl.add(false);
    StatusLogBus.instance.addStatus('RFID', false);
    StatusLogBus.instance.addText('RFID', '❌ ERROR: $error');

    LogService.instance.logError(
      'RFID_SOCKET_ERROR',
      error,
      StackTrace.current,
    );

    _sendSta('Error en WebSocket RFID\n• detalle: $error');
    _scheduleReconnect();
  }

  /// Maneja cierre de conexión
  void _onDone() {
    _connected = false;
    setConnected(false);
    _connectedCtrl.add(false);
    StatusLogBus.instance.addStatus('RFID', false);

    if (!_closingIntentionally) {
      StatusLogBus.instance.addText('RFID', '🔌 Conexión cerrada');
      _sendSta('Conexión RFID cerrada');
      _scheduleReconnect();
    }
    _closingIntentionally = false;
  }

  /// Procesa JSON recibido
  Future<void> _processJsonData(String text) async {
    final kfg = AppStateManager.instance.kioskConfig;

    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      LogService.instance.logRequest('RFID_RX_JSON', json);

      final response = VehicleResponse.fromJson(json);

      // 1) ÉXITO REAL
      if (response.code == 0 && response.record != null) {
        final gateFromResponse = response.gate.toString();
        final basculaFromEnv = kfg!.gate;

        print(
          '🔍 GATE CHECK | response: "$gateFromResponse" | config: "$basculaFromEnv" | match: ${gateFromResponse == basculaFromEnv}',
        );

        if (gateFromResponse != basculaFromEnv) {
          LogService.instance.logRequest('RFID_GATE_MISMATCH', {
            'gateFromResponse': gateFromResponse,
            'basculaExpected': basculaFromEnv,
            'message': 'Gate no coincide, ignorando silenciosamente',
          });
          return;
        }

        final vehicle = response.record!;

        LogService.instance.logRequest('RFID_VEHICLE_DETECTED', {
          'regNumber': vehicle.regNumber,
          'company': vehicle.company,
          'gate': gateFromResponse,
          'timestamp': DateTime.now().toIso8601String(),
        });

        StatusLogBus.instance.addText(
          'RFID',
          '🚗 Vehículo: ${vehicle.regNumber} - ${vehicle.company}',
        );

        if (!_shouldEmitVehicle(response)) {
          LogService.instance.logRequest('RFID_VEHICLE_DUPLICATE_SKIPPED', {
            'regNumber': vehicle.regNumber,
            'message': response.message,
            'gate': gateFromResponse,
          });
          return;
        }

        print(
          '📡 EMIT | hashCode: $hashCode | hasListener: ${_vehicleCtrl.hasListener}',
        );
        if (!_vehicleCtrl.isClosed) {
          _vehicleCtrl.add(response);
        }

        return;
      }

      // 2) AVISO / BUSCANDO TAG
      if (response.code == 2) {
        LogService.instance.logRequest('RFID_SEARCHING_TAG', {
          'message': response.message,
          'gate': response.gate,
          'side': response.side,
          'timestamp': DateTime.now().toIso8601String(),
        });

        StatusLogBus.instance.addText('RFID', '🔎 Buscando TAG...');
        return;
      }

      // 3) AVISO / PESO EN BÁSCULA
      final msgLower = response.message.toLowerCase();
      final isWeightInfo =
          response.code == 1 &&
          msgLower.contains('weight') &&
          msgLower.contains('greater than 0');

      if (isWeightInfo) {
        LogService.instance.logRequest('RFID_WEIGHT_INFO', {
          'message': response.message,
          'gate': response.gate,
          'side': response.side,
          'timestamp': DateTime.now().toIso8601String(),
        });

        StatusLogBus.instance.addText('RFID', 'ℹ️ ${response.message}');
        return;
      }

      // 4) ERROR REAL
      final errorMsg = _buildErrorMessage(response);
      StatusLogBus.instance.addText('RFID', '❌ $errorMsg');
      _sendSta(errorMsg);

      LogService.instance.logRequest('RFID_BUSINESS_ERROR', {
        'code': response.code,
        'message': response.message,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      StatusLogBus.instance.addText('RFID', '❌ Error parseando JSON: $e');
      _sendSta('Error decodificando JSON\n• detalle: $e');
      LogService.instance.logError('RFID_JSON_PARSE_ERROR', e);
    }
  }

  /// Construye mensaje de error formateado
  String _buildErrorMessage(VehicleResponse response) {
    final lines = <String>[];
    lines.add(
      'Ex:: ${response.message.isEmpty ? "Error desconocido" : response.message}',
    );
    lines.add('• code: ${response.code}');

    if (response.record != null) {
      final record = response.record!;
      if (record.regNumber.isNotEmpty) {
        lines.add('• placa: ${record.regNumber}');
      }
      if (record.message.isNotEmpty) {
        lines.add('• mensaje: ${record.message}');
      }
      if (record.company.isNotEmpty) {
        lines.add('• empresa: ${record.company}');
      }
    }

    return lines.join('\n');
  }

  /// Programa reconexión automática
  void _scheduleReconnect() {
    if (_shouldReconnect && !_disposed && _lastUrl != null) {
      // ✅ Verificar que existe URL
      StatusLogBus.instance.addText('RFID', '🔄 Reintentando en 3s...');
      Future.delayed(const Duration(seconds: 3), () {
        if (_shouldReconnect && !_disposed && _lastUrl != null) {
          connect(_lastUrl!);
        }
      });
    }
  }

  /// Maneja error de conexión inicial
  void _handleConnectionError(dynamic e, StackTrace st, String url) {
    _connected = false;
    setConnected(false);
    _connectedCtrl.add(false);
    StatusLogBus.instance.addStatus('RFID', false);
    StatusLogBus.instance.addText('RFID', '🚫 Fallo al conectar: $e');

    _sendSta('Excepción al conectar RFID\n• detalle: $e');

    LogService.instance.logError('RFID_CONNECT_EXCEPTION', e, st);
    _scheduleReconnect();
  }

  /// Envía mensaje STA al servidor
  Future<void> _sendSta(String message) async {
    try {
      await KioskServer.connectMonitor(
        accion: 'STA',
        message: message,
        error: true,
        patio: patio,
        bascula: bascula,
        gate: gate,
      );
    } catch (_) {}
  }

  /// Construye headers para WebSocket
  Map<String, dynamic> _buildHeaders() {
    try {
      final cfg = AppStateManager.instance.gateConfig;
      final kfg = AppStateManager.instance.kioskConfig;
      if (cfg == null) return {};

      final headers = <String, dynamic>{};

      if (cfg.apiKey.isNotEmpty) {
        headers['api-key'] = cfg.apiKey;
      }

      if (kfg?.gate.isNotEmpty ?? false) {
        headers['gate-location'] = kfg!.gate;
      }

      headers['client-type'] = 'KIOSKO';

      return headers;
    } catch (_) {
      return {};
    }
  }

  /// Detiene la conexión
  void _stop() {
    try {
      _channelSub?.cancel();
      _channelSub = null;
    } catch (_) {}

    try {
      _channel?.sink.close();
      _channel = null;
    } catch (_) {}

    _connected = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _shouldReconnect = false;

    LogService.instance.logRequest('RFID_WS_DISPOSING', {
      'timestamp': DateTime.now().toIso8601String(),
    });

    super.dispose();
    _stop();

    _connectedCtrl.close();
    _vehicleCtrl.close();
  }
}
