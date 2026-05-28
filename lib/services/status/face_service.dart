import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:tpg_attack_kiosko_muelle/models/websockets/websocket_models.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/global_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/base_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/status_log_bus.dart';

class FaceService extends BaseService {
  Socket? _socket;
  StreamSubscription<List<int>>? _socketSub;

  bool _connected = false;
  bool _disposed = false;
  bool _shouldReconnect = true;
  String? _lastUrl;

  final _connectedCtrl = StreamController<bool>.broadcast();
  final _employeeCtrl = StreamController<EmployeeResponse>.broadcast();

  final List<int> _frameBuffer = <int>[];

  Stream<bool> get isConnected$ => _connectedCtrl.stream;
  Stream<EmployeeResponse> get employeeDetected$ => _employeeCtrl.stream;

  FaceService({required super.onStatus});

  Future<void> connect(String url) async {
    await _stop();

    String normalizedUrl = url.trim();

    if (!normalizedUrl.startsWith('ws://') &&
        !normalizedUrl.startsWith('wss://')) {
      final error = 'URL inválida: debe comenzar con ws:// o wss://';
      LogService.instance.logError('FACE_INVALID_URL', error);
      StatusLogBus.instance.addText('FACE', error);
      return;
    }

    if (!normalizedUrl.endsWith('/')) {
      normalizedUrl = '$normalizedUrl/';
    }

    _lastUrl = normalizedUrl;

    LogService.instance.logRequest('FACE_WS_CONNECTING', {
      'originalUrl': url,
      'normalizedUrl': normalizedUrl,
      'timestamp': DateTime.now().toIso8601String(),
    });
    StatusLogBus.instance.addText('FACE', 'Conectando a: $normalizedUrl');

    try {
      final uri = Uri.parse(normalizedUrl);

      final port = uri.hasPort ? uri.port : (uri.scheme == 'wss' ? 443 : 80);

      final Socket socket;
      if (uri.scheme == 'wss') {
        socket = await SecureSocket.connect(
          uri.host,
          port,
          timeout: const Duration(seconds: 5),
        );
      } else {
        socket = await Socket.connect(
          uri.host,
          port,
          timeout: const Duration(seconds: 5),
        );
      }

      final socketStream = socket.asBroadcastStream();

      final random = Random.secure();
      final keyBytes = List<int>.generate(16, (_) => random.nextInt(256));
      final wsKey = base64Encode(keyBytes);

      final path = () {
        final p = uri.path.isEmpty ? '/' : uri.path;
        if (uri.hasQuery && uri.query.isNotEmpty) {
          return '$p?${uri.query}';
        }
        return p;
      }();

      final hostHeader = uri.hasPort ? '${uri.host}:$port' : uri.host;

      final req = StringBuffer()
        ..write('GET $path HTTP/1.1\r\n')
        ..write('Host: $hostHeader\r\n')
        ..write('Upgrade: websocket\r\n')
        ..write('Connection: Upgrade\r\n')
        ..write('Sec-WebSocket-Key: $wsKey\r\n')
        ..write('Sec-WebSocket-Version: 13\r\n')
        ..write('\r\n');

      final rawRequest = req.toString();

      LogService.instance.logRequest('FACE_RAW_HANDSHAKE_REQUEST', {
        'url': normalizedUrl,
        'request': rawRequest,
        'secWebSocketKey': wsKey,
      });

      socket.add(utf8.encode(rawRequest));
      await socket.flush();

      final handshakeBytes = await _readHandshake(socketStream);
      final rawResponse = utf8.decode(handshakeBytes, allowMalformed: true);

      LogService.instance.logRequest('FACE_RAW_HANDSHAKE_RESPONSE', {
        'url': normalizedUrl,
        'response': rawResponse,
      });

      _validateHandshake(rawResponse);

      _socket = socket;
      _frameBuffer.clear();

      _connected = true;
      setConnected(true);
      _connectedCtrl.add(true);
      StatusLogBus.instance.addStatus('FACE', true);
      StatusLogBus.instance.addText('FACE', 'WebSocket FACE conectado');

      _socketSub = socketStream.listen(
        _onSocketData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      startProbeLoop(() async => _connected);
    } catch (e, st) {
      _handleConnectionError(e, st, normalizedUrl);
    }
  }

  Future<List<int>> _readHandshake(Stream<List<int>> socketStream) async {
    final completer = Completer<List<int>>();
    final buffer = <int>[];

    late StreamSubscription<List<int>> sub;
    sub = socketStream.listen(
      (data) {
        buffer.addAll(data);

        for (int i = 0; i <= buffer.length - 4; i++) {
          if (buffer[i] == 13 &&
              buffer[i + 1] == 10 &&
              buffer[i + 2] == 13 &&
              buffer[i + 3] == 10) {
            final headerEnd = i + 4;
            final headerBytes = buffer.sublist(0, headerEnd);
            final remaining = buffer.sublist(headerEnd);

            _frameBuffer
              ..clear()
              ..addAll(remaining);

            if (!completer.isCompleted) {
              completer.complete(headerBytes);
            }
            sub.cancel();
            return;
          }
        }
      },
      onError: (e, st) {
        if (!completer.isCompleted) {
          completer.completeError(e, st);
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          completer.complete(buffer);
        }
      },
      cancelOnError: false,
    );

    return completer.future.timeout(const Duration(seconds: 5));
  }

  void _validateHandshake(String rawResponse) {
    final lower = rawResponse.toLowerCase();

    if (!lower.startsWith('http/1.1 101')) {
      throw Exception(
        'Handshake inválido: respuesta no es 101 Switching Protocols',
      );
    }

    if (!lower.contains('upgrade: websocket')) {
      throw Exception('Handshake inválido: falta header Upgrade: websocket');
    }

    if (!lower.contains('connection: upgrade')) {
      throw Exception('Handshake inválido: falta header Connection: Upgrade');
    }

    if (!lower.contains('sec-websocket-accept:')) {
      throw Exception('Handshake inválido: falta Sec-WebSocket-Accept');
    }
  }

  void _onSocketData(List<int> data) {
    _frameBuffer.addAll(data);
    _drainFrames();
  }

  void _drainFrames() {
    while (true) {
      if (_frameBuffer.length < 2) return;

      final b0 = _frameBuffer[0];
      final b1 = _frameBuffer[1];

      final fin = (b0 & 0x80) != 0;
      final opcode = b0 & 0x0F;
      final masked = (b1 & 0x80) != 0;

      int offset = 2;
      int payloadLen = b1 & 0x7F;

      if (payloadLen == 126) {
        if (_frameBuffer.length < offset + 2) return;
        payloadLen = (_frameBuffer[offset] << 8) | _frameBuffer[offset + 1];
        offset += 2;
      } else if (payloadLen == 127) {
        if (_frameBuffer.length < offset + 8) return;

        final byteData = ByteData(8);
        for (int i = 0; i < 8; i++) {
          byteData.setUint8(i, _frameBuffer[offset + i]);
        }

        final big = byteData.getUint64(0);
        if (big > 0x7FFFFFFF) {
          throw Exception('Frame FACE demasiado grande');
        }

        payloadLen = big.toInt();
        offset += 8;
      }

      List<int>? maskKey;
      if (masked) {
        if (_frameBuffer.length < offset + 4) return;
        maskKey = _frameBuffer.sublist(offset, offset + 4);
        offset += 4;
      }

      if (_frameBuffer.length < offset + payloadLen) return;

      final payload = _frameBuffer.sublist(offset, offset + payloadLen);
      _frameBuffer.removeRange(0, offset + payloadLen);

      final decodedPayload = masked && maskKey != null
          ? _unmaskPayload(payload, maskKey)
          : payload;

      switch (opcode) {
        case 0x1: // text
          final text = utf8.decode(decodedPayload, allowMalformed: true).trim();
          if (text.isNotEmpty) {
            _onData(text);
          }
          break;

        case 0x8: // close
          StatusLogBus.instance.addText(
            'FACE',
            'Servidor FACE cerró la conexión',
          );
          unawaited(_closeSocketOnly());
          _onDone();
          return;

        case 0x9: // ping
          unawaited(_sendFrame(opcode: 0xA, payload: decodedPayload)); // pong
          break;

        case 0xA: // pong
          break;

        case 0x0: // continuation
          if (!fin) {
            LogService.instance.logRequest('FACE_CONTINUATION_FRAME', {
              'message': 'Frame continuado no soportado explícitamente',
            });
          }
          break;

        default:
          LogService.instance.logRequest('FACE_UNKNOWN_OPCODE', {
            'opcode': opcode,
            'payloadLength': decodedPayload.length,
          });
      }
    }
  }

  List<int> _unmaskPayload(List<int> payload, List<int> maskKey) {
    final out = List<int>.filled(payload.length, 0);
    for (int i = 0; i < payload.length; i++) {
      out[i] = payload[i] ^ maskKey[i % 4];
    }
    return out;
  }

  Future<void> _sendFrame({
    required int opcode,
    List<int> payload = const [],
  }) async {
    final socket = _socket;
    if (socket == null) return;

    final random = Random.secure();
    final maskKey = List<int>.generate(4, (_) => random.nextInt(256));

    final frame = <int>[];
    frame.add(0x80 | (opcode & 0x0F)); // FIN + opcode

    final length = payload.length;
    if (length < 126) {
      frame.add(0x80 | length);
    } else if (length <= 0xFFFF) {
      frame.add(0x80 | 126);
      frame.add((length >> 8) & 0xFF);
      frame.add(length & 0xFF);
    } else {
      frame.add(0x80 | 127);
      final byteData = ByteData(8)..setUint64(0, length);
      frame.addAll(byteData.buffer.asUint8List());
    }

    frame.addAll(maskKey);

    for (int i = 0; i < payload.length; i++) {
      frame.add(payload[i] ^ maskKey[i % 4]);
    }

    socket.add(frame);
    await socket.flush();
  }

  void _onData(dynamic data) {
    final text = data.toString().trim();
    if (text.isEmpty) return;
    _processEmployeeData(text);
  }

  void _onError(dynamic error) {
    _connected = false;
    setConnected(false);
    _connectedCtrl.add(false);
    StatusLogBus.instance.addStatus('FACE', false);
    StatusLogBus.instance.addText('FACE', 'ERROR: $error');

    LogService.instance.logError(
      'FACE_SOCKET_ERROR',
      error,
      StackTrace.current,
    );
    _scheduleReconnect();
  }

  void _onDone() {
    _connected = false;
    setConnected(false);
    _connectedCtrl.add(false);
    StatusLogBus.instance.addStatus('FACE', false);
    StatusLogBus.instance.addText('FACE', 'Conexión cerrada');

    LogService.instance.logRequest('FACE_WS_CLOSED', {
      'timestamp': DateTime.now().toIso8601String(),
    });

    _scheduleReconnect();
  }

  void _processEmployeeData(String text) {
    try {
      final json = jsonDecode(text) as Map<String, dynamic>;
      LogService.instance.logRequest('FACE_RX_JSON', json);

      final expectedSn =
          AppStateManager.instance.kioskConfig?.faceDeviceSn
              .trim()
              .toUpperCase() ??
          '';
      final incomingSn = (json['sn'] ?? '').toString().trim().toUpperCase();

      if (expectedSn.isNotEmpty && incomingSn != expectedSn) {
        LogService.instance.logRequest('FACE_SN_MISMATCH', {
          'expectedSn': expectedSn,
          'incomingSn': incomingSn,
          'message': 'SN no coincide, ignorando lectura facial',
        });
        return;
      }

      final response = EmployeeResponse.fromJson(json);

      if (!response.isSuccess || response.record == null) {
        StatusLogBus.instance.addText('FACE', 'Error: ${response.message}');
        LogService.instance.logRequest('FACE_BUSINESS_ERROR', {
          'code': response.code,
          'message': response.message,
          'timestamp': DateTime.now().toIso8601String(),
        });
        return;
      }

      final employee = response.record!;

      if (employee.identificationNumber.isEmpty) {
        LogService.instance.logRequest('FACE_EMPTY_IDENTIFICATION', {
          'sn': incomingSn,
          'payload': json,
        });
        return;
      }

      if (employee.state == 0) {
        LogService.instance.logRequest('FACE_EMPLOYEE_INACTIVE', {
          'identification': employee.identificationNumber,
          'name': employee.name,
          'stateText': employee.stateText,
        });
        return;
      }

      LogService.instance.logRequest('FACE_EMPLOYEE_DETECTED', {
        'sn': incomingSn,
        'name': employee.name,
        'identification': employee.identificationNumber,
        'profile': employee.profile,
        'licenseExpirationDate': employee.licenseExpirationDate,
        'timestamp': DateTime.now().toIso8601String(),
      });

      StatusLogBus.instance.addText(
        'FACE',
        'Empleado: ${employee.name} - ${employee.profile}',
      );

      _saveToGlobalManager(employee);

      if (!_employeeCtrl.isClosed) {
        _employeeCtrl.add(response);
      }
    } catch (e, st) {
      StatusLogBus.instance.addText('FACE', '[RAW] $text');
      LogService.instance.logError('FACE_PARSE_ERROR', e, st);
      LogService.instance.logRequest('FACE_RX_RAW', {'raw': text});
    }
  }

  void _saveToGlobalManager(EmployeeRecord employee) {
    try {
      final manager = GlobalManager.instance.transactionManager;

      manager.setDriverCedula(employee.identificationNumber);
      manager.setDriverName(employee.name);
      manager.setDriverPhotoUrl(employee.urlFace);
      manager.setDriverEmpresa(employee.company);

      if (employee.message.isNotEmpty) {
        manager.setDriverAlerta(employee.message);
      }

      LogService.instance.logRequest('FACE_SAVED_TO_GLOBAL_MANAGER', {
        'identification': employee.identificationNumber,
        'name': employee.name,
      });
    } catch (e) {
      LogService.instance.logError('FACE_SAVE_TO_GLOBAL_MANAGER_ERROR', e);
    }
  }

  void _scheduleReconnect() {
    if (_shouldReconnect &&
        !_disposed &&
        _lastUrl != null &&
        _lastUrl!.isNotEmpty) {
      StatusLogBus.instance.addText('FACE', 'Reintentando en 3s...');
      Future.delayed(const Duration(seconds: 3), () {
        if (_shouldReconnect && !_disposed) {
          connect(_lastUrl!);
        }
      });
    }
  }

  void _handleConnectionError(dynamic e, StackTrace st, String url) {
    _connected = false;
    setConnected(false);
    _connectedCtrl.add(false);
    StatusLogBus.instance.addStatus('FACE', false);
    StatusLogBus.instance.addText('FACE', 'Fallo al conectar: $e');

    LogService.instance.logError('FACE_CONNECT_EXCEPTION', e, st);
    _scheduleReconnect();
  }

  Future<void> _closeSocketOnly() async {
    try {
      await _socketSub?.cancel();
    } catch (_) {}
    _socketSub = null;

    try {
      await _socket?.close();
    } catch (_) {}

    try {
      _socket?.destroy();
    } catch (_) {}

    _socket = null;
  }

  Future<void> _stop() async {
    try {
      stopProbeLoop();
    } catch (_) {}

    await _closeSocketOnly();
    _frameBuffer.clear();
    _connected = false;
  }

  @override
  void dispose() {
    _disposed = true;
    _shouldReconnect = false;

    LogService.instance.logRequest('FACE_WS_DISPOSING', {
      'timestamp': DateTime.now().toIso8601String(),
    });

    super.dispose();
    unawaited(_stop());

    _connectedCtrl.close();
    _employeeCtrl.close();
  }
}
