// lib/services/status/scale_service.dart
// Autor: Abraham Yance
// Actualizado: 2025-11-21
// 🚀 ScaleService: WebSocket - lectura de peso en tiempo real (SIMPLIFICADO)

import 'dart:async';
import 'dart:convert';
import 'package:tpg_attack_kiosko_muelle/models/websockets/websocket_models.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/base_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/status_log_bus.dart';

class ScaleService extends BaseService {
  final String url;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;

  bool _connected = false;
  bool _disposed = false;
  bool _shouldReconnect = true;

  WeightResponse? _lastWeightResponse;

  // Streams
  final _connectedCtrl = StreamController<bool>.broadcast();
  final _weightCtrl = StreamController<WeightResponse>.broadcast();

  Stream<bool> get isConnected$ => _connectedCtrl.stream;
  Stream<WeightResponse> get weight$ => _weightCtrl.stream;

  ScaleService({required this.url, required super.onStatus});

  void start() => connect(url);

  /// Conectar al WebSocket
  Future<void> connect(String wsUrl) async {
    _stop();

    LogService.instance.logRequest('SCALE_WS_CONNECTING', {
      'url': wsUrl,
      'timestamp': DateTime.now().toIso8601String(),
    });
    StatusLogBus.instance.addText('BASCULA', '🔄 Conectando a: $wsUrl');

    try {
      final uri = Uri.parse(wsUrl.trim());
      final headers = _buildHeaders();

      _channel = IOWebSocketChannel.connect(uri, headers: headers);

      _connected = true;
      setConnected(true);
      _connectedCtrl.add(true);
      StatusLogBus.instance.addStatus('BASCULA', true);
      StatusLogBus.instance.addText(
        'BASCULA',
        '🔗 WebSocket BASCULA conectado',
      );

      _channelSub = _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      startProbeLoop(() async => _connected);
    } catch (e, st) {
      _handleConnectionError(e, st, wsUrl);
    }
  }

  /// Maneja datos entrantes
  void _onData(dynamic data) {
    final text = data.toString().trim();
    if (text.isEmpty) return;

    _processWeightData(text);
  }

  /// Maneja errores del stream
  void _onError(dynamic error) {
    _connected = false;
    setConnected(false);
    _connectedCtrl.add(false);
    StatusLogBus.instance.addStatus('BASCULA', false);
    StatusLogBus.instance.addText('BASCULA', '❌ ERROR: $error');

    LogService.instance.logError(
      'SCALE_SOCKET_ERROR',
      error,
      StackTrace.current,
    );
    _scheduleReconnect();
  }

  /// Maneja cierre de conexión
  void _onDone() {
    _connected = false;
    setConnected(false);
    _connectedCtrl.add(false);
    StatusLogBus.instance.addStatus('BASCULA', false);
    StatusLogBus.instance.addText('BASCULA', '🔌 Conexión cerrada');

    LogService.instance.logRequest('SCALE_WS_CLOSED', {
      'url': url,
      'timestamp': DateTime.now().toIso8601String(),
    });

    _scheduleReconnect();
  }

  /// Procesa datos de peso recibidos
  void _processWeightData(String text) {
    final kfg = AppStateManager.instance.kioskConfig;

    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      final response = WeightResponse.fromJson(json);

      if (response.isSuccess && response.record != null) {
        // ✅ VALIDAR QUE EL GATE COINCIDA CON BASCULA
        final gateFromResponse = response.gate.toString();
        final basculaFromEnv = kfg!.gate;

        if (gateFromResponse != basculaFromEnv) {
          LogService.instance.logRequest('SCALE_GATE_MISMATCH', {
            'gateFromResponse': gateFromResponse,
            'basculaExpected': basculaFromEnv,
            'message': 'Gate no coincide con BASCULA, ignorando',
          });
          return;
        }

        // ✅ Gate coincide, procesar normalmente
        _lastWeightResponse = response;

        LogService.instance.logRequest('SCALE_WEIGHT_RX', {
          'weight': response.record!.weight,
          'gate': gateFromResponse,
          'timestamp': DateTime.now().toIso8601String(),
        });

        StatusLogBus.instance.addText(
          'BASCULA',
          '⚖️ Peso: ${response.record!.weight} kg',
        );

        if (!_weightCtrl.isClosed) {
          _weightCtrl.add(response);
        }
      } else {
        StatusLogBus.instance.addText(
          'BASCULA',
          '❌ Error: ${response.message}',
        );
      }
    } catch (e) {
      // Si no es JSON, intentar parsear como número directo
      final weight = int.tryParse(text.trim()) ?? 0;

      // ⚠️ Para números planos (sin JSON), no podemos validar gate
      // Asumimos que es válido si no viene en formato JSON
      final response = WeightResponse(
        code: 0,
        message: 'Record Found',
        gate: 0,
        record: WeightRecord(weight: weight.toDouble()),
      );

      _lastWeightResponse = response;

      LogService.instance.logRequest('SCALE_WEIGHT_RX_RAW', {
        'weight': weight,
        'raw': text,
        'timestamp': DateTime.now().toIso8601String(),
      });

      StatusLogBus.instance.addText('BASCULA', '⚖️ Peso: $weight kg');

      if (!_weightCtrl.isClosed) {
        _weightCtrl.add(response);
      }
    }
  }

  /// Programa reconexión automática
  void _scheduleReconnect() {
    if (_shouldReconnect && !_disposed) {
      StatusLogBus.instance.addText('BASCULA', '🔄 Reintentando en 3s...');
      Future.delayed(const Duration(seconds: 3), () {
        if (_shouldReconnect && !_disposed) connect(url);
      });
    }
  }

  /// Maneja error de conexión inicial
  void _handleConnectionError(dynamic e, StackTrace st, String wsUrl) {
    _connected = false;
    setConnected(false);
    _connectedCtrl.add(false);
    StatusLogBus.instance.addStatus('BASCULA', false);
    StatusLogBus.instance.addText('BASCULA', '🚫 Fallo al conectar: $e');

    LogService.instance.logError('SCALE_CONNECT_EXCEPTION', e, st);
    _scheduleReconnect();
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

      return headers;
    } catch (_) {
      return {};
    }
  }

  /// Verifica estado de conexión
  Future<bool> checkOnce() async => _connected;

  /// Lee el último peso conocido
  Future<WeightResponse?> readWeight() async {
    if (!_connected) {
      LogService.instance.logWarning('SCALE_READ_WEIGHT', {
        'warning': 'No conectado',
        'timestamp': DateTime.now().toIso8601String(),
      });
      return null;
    }

    return _lastWeightResponse;
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

    LogService.instance.logRequest('SCALE_WS_DISPOSING', {
      'timestamp': DateTime.now().toIso8601String(),
    });

    super.dispose();
    _stop();

    _connectedCtrl.close();
    _weightCtrl.close();
  }
}
