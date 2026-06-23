// lib/services/status/ocr_service.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:tpg_attack_kiosko_muelle/services/global_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/status_log_bus.dart';

import 'base_service.dart';

class OcrEvent {
  final int? transitId;
  final int? location;
  final String vehicleType;
  final int containerCount;
  final String note;
  final String status;
  final List<Map<String, dynamic>> containers;
  final DateTime timestamp;

  OcrEvent({
    required this.transitId,
    required this.location,
    required this.vehicleType,
    required this.containerCount,
    required this.note,
    required this.status,
    required this.containers,
    required this.timestamp,
  });
}

class OcrAuthResult {
  final String accessToken;
  final int expiresIn;

  OcrAuthResult({
    required this.accessToken,
    required this.expiresIn,
  });

  factory OcrAuthResult.fromJson(Map<String, dynamic> json) {
    return OcrAuthResult(
      accessToken: (json['access_token'] ?? '').toString(),
      expiresIn: int.tryParse((json['expires_in'] ?? '0').toString()) ?? 0,
    );
  }
}

class OcrService extends BaseService {
  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;

  bool _disposed = false;
  bool _shouldReconnect = true;
  bool _reconnectScheduled = false;
  bool _authInProgress = false;

  String? _lastUrl;
  String? _cachedToken;
  DateTime? _tokenExpiresAt;

  OcrService({
    required super.onStatus,
  });

  final StreamController<OcrEvent> _ocrEventCtrl =
      StreamController<OcrEvent>.broadcast();

  Stream<OcrEvent> get ocrEvent$ => _ocrEventCtrl.stream;

  Future<void> connect(String fullUrl) async {
    final isMuelle =
        (dotenv.env['MUELLE'] ?? '').trim().toUpperCase() == 'TRUE';

    if (!isMuelle) {
      setConnected(false);
      StatusLogBus.instance.addStatus('OCR', false);
      LogService.instance.logRequest('OCR_SKIP_CONNECT', {
        'reason': 'MUELLE_FALSE',
      });
      return;
    }

    if (fullUrl.trim().isEmpty) {
      setConnected(false);
      StatusLogBus.instance.addStatus('OCR', false);
      LogService.instance.logWarning('OCR_WS_URL_EMPTY', {});
      return;
    }

    _lastUrl = fullUrl.trim();
    _shouldReconnect = true;

    _stopWs();

    try {
      final token = await _getValidToken();

      if (token == null || token.isEmpty) {
        setConnected(false);
        StatusLogBus.instance.addStatus('OCR', false);
        LogService.instance.logWarning('OCR_AUTH_EMPTY_TOKEN', {
          'message': 'No se obtuvo access_token para OCR',
        });
        return;
      }

      _doConnect(_lastUrl!, token);
    } catch (e, st) {
      setConnected(false);
      StatusLogBus.instance.addStatus('OCR', false);
      LogService.instance.logError('OCR_CONNECT_FATAL', e, st);
      _scheduleReconnect(forceRefreshToken: true);
    }
  }

  Future<String?> _getValidToken({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _hasValidCachedToken) {
      return _cachedToken;
    }

    return _loginAndGetTokenWithRetry();
  }

  bool get _hasValidCachedToken {
    if (_cachedToken == null || _cachedToken!.isEmpty) return false;
    if (_tokenExpiresAt == null) return false;

    final now = DateTime.now();
    return now.isBefore(_tokenExpiresAt!.subtract(const Duration(seconds: 30)));
  }

  void _doConnect(String fullUrl, String token) {
    try {
      LogService.instance.logRequest('OCR_WS_CONNECTING', {
        'url': fullUrl,
        'hasToken': token.isNotEmpty,
      });

      _channel = IOWebSocketChannel.connect(
        Uri.parse(fullUrl),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      setConnected(true);
      StatusLogBus.instance.addStatus('OCR', true);

      _channelSub = _channel!.stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );

      startProbeLoop(() async => _channel != null);
    } catch (e, st) {
      setConnected(false);
      StatusLogBus.instance.addStatus('OCR', false);
      LogService.instance.logError('OCR_WS_CONNECT_ERROR', e, st);
      _scheduleReconnect(forceRefreshToken: false);
    }
  }

  void _onData(dynamic data) {
    final raw = data.toString();

    LogService.instance.logRequest('OCR_RAW_MESSAGE', {
      'message': raw,
    });

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! Map<String, dynamic>) return;

      if (_isTokenExpiredMessage(decoded)) {
        _handleTokenExpired();
        return;
      }

      if (decoded['type'] == 'connection') {
        LogService.instance.logRequest('OCR_WS_HANDSHAKE_OK', {
          'message': decoded['message'],
        });
        return;
      }

      if (decoded['type'] != 'ocr_event') return;

      final ok = decoded['ok'] == true;
      final dataMap = decoded['data'];

      if (!ok || dataMap is! Map<String, dynamic>) return;

      final basculaEnv = (dotenv.env['BASCULA'] ?? '').trim();
      // final location = int.tryParse(dataMap['location']?.toString() ?? '');
      final location = 92;

      if (basculaEnv.isNotEmpty && location?.toString() != basculaEnv) {
        LogService.instance.logRequest('OCR_EVENT_IGNORED_BY_LOCATION', {
          'basculaEnv': basculaEnv,
          'ocrLocation': location,
        });
        return;
      }

      final containersRaw = dataMap['containers'];

      final containers = containersRaw is List
          ? containersRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      final meta = decoded['meta'];
      final persistence = dataMap['persistence'];

      final event = OcrEvent(
        transitId: int.tryParse(dataMap['transit_id']?.toString() ?? ''),
        location: location,
        vehicleType: dataMap['vehicleType']?.toString() ?? '',
        containerCount:
            int.tryParse(dataMap['containerCount']?.toString() ?? '0') ?? 0,
        note: dataMap['note']?.toString() ?? '',
        status: dataMap['status']?.toString() ?? '',
        containers: containers,
        timestamp: DateTime.tryParse(
              meta is Map ? meta['emittedAt']?.toString() ?? '' : '',
            ) ??
            DateTime.now(),
      );

      _saveOcrInTransactionManager(
        event: event,
        raw: decoded,
        persistence: persistence is Map ? persistence : null,
        meta: meta is Map ? meta : null,
      );

      _ocrEventCtrl.add(event);

      LogService.instance.logRequest('OCR_EVENT_PARSED', {
        'transitId': event.transitId,
        'location': event.location,
        'vehicleType': event.vehicleType,
        'containerCount': event.containerCount,
        'containers': containers.map((e) => e['containerNumber']).toList(),
      });
    } catch (e, st) {
      LogService.instance.logError('OCR_PARSE_ERROR', e, st);
    }
  }

  void _saveOcrInTransactionManager({
    required OcrEvent event,
    required Map<String, dynamic> raw,
    required Map? persistence,
    required Map? meta,
  }) {
    final manager = GlobalManager.instance.transactionManager;

    // Limpia cualquier OCR anterior antes de guardar la nueva lectura.
    manager.resetOcr();

    final vehicleType = event.vehicleType.trim().toLowerCase();

    final isTruckEmpty = vehicleType == 'truck_empty';
    final isTruckContainer = vehicleType == 'truck_container';

    final containerNumbers = event.containers
        .map((e) => e['containerNumber']?.toString() ?? '')
        .where((e) => e.trim().isNotEmpty)
        .toList();

    final flowType = isTruckEmpty ? 'PORTEO_EMPTY' : 'DESCARGA';

    manager.set('ocrTransitId', event.transitId?.toString() ?? '');
    manager.set('ocrLocation', event.location?.toString() ?? '');
    manager.set('ocrVehicleType', event.vehicleType);
    manager.set('ocrContainerCount', event.containerCount.toString());
    manager.set('ocrNote', event.note);
    manager.set('ocrStatus', event.status);
    manager.set('ocrContainersJson', jsonEncode(event.containers));
    manager.set('ocrRawJson', jsonEncode(raw));
    manager.set('ocrEmittedAt', event.timestamp.toIso8601String());

    manager.set('ocrPersistenceSaved', persistence?['saved']?.toString() ?? '');
    manager.set('ocrPersistenceId', persistence?['id']?.toString() ?? '');
    manager.set('ocrPersistenceError', persistence?['error']?.toString() ?? '');
    manager.set(
      'ocrPersistenceSavedAt',
      persistence?['savedAt']?.toString() ?? '',
    );

    manager.set('ocrMetaTotalClients', meta?['totalClients']?.toString() ?? '');
    manager.set('ocrMetaEmittedAt', meta?['emittedAt']?.toString() ?? '');

    manager.set('ocrContainerNumbers', containerNumbers.join(' / '));

    manager.set('isTruckEmpty', isTruckEmpty);
    manager.set('ocrFlowType', flowType);

    if (isTruckContainer) {
      manager.set('contenedor', containerNumbers.join(' / '));
    } else {
      manager.set('contenedor', '');
    }

    for (var i = 0; i < event.containers.length; i++) {
      final c = event.containers[i];
      final index = i + 1;

      manager.set(
        'ocrContainer${index}Index',
        c['containerIndex']?.toString() ?? '',
      );
      manager.set(
        'ocrContainer${index}Number',
        c['containerNumber']?.toString() ?? '',
      );
      manager.set(
        'ocrContainer${index}Confidence',
        c['containerConfidence']?.toString() ?? '',
      );
      manager.set(
        'ocrContainer${index}IsoCheckType',
        c['isoCheckType']?.toString() ?? '',
      );
      manager.set(
        'ocrContainer${index}IsoCheckValue',
        c['isoCheckValue']?.toString() ?? '',
      );
      manager.set(
        'ocrContainer${index}ImageUrl',
        c['imageUrl']?.toString() ?? '',
      );
      manager.set(
        'ocrContainer${index}Tare',
        c['tare']?.toString() ?? '',
      );
      manager.set(
        'ocrContainer${index}TareConfidence',
        c['tareConfidence']?.toString() ?? '',
      );
      manager.set(
        'ocrContainer${index}MaxGrossWeight',
        c['maxGrossWeight']?.toString() ?? '',
      );
      manager.set(
        'ocrContainer${index}MaxNetWeight',
        c['maxNetWeight']?.toString() ?? '',
      );
    }

    LogService.instance.logRequest('OCR_TRANSACTION_MANAGER_UPDATED', {
      'ocrTransitId': event.transitId,
      'ocrLocation': event.location,
      'ocrVehicleType': event.vehicleType,
      'ocrContainerCount': event.containerCount,
      'ocrContainerNumbers': containerNumbers,
      'isTruckEmpty': isTruckEmpty,
      'isTruckContainer': isTruckContainer,
      'flowType': flowType,
      'contenedor': isTruckContainer ? containerNumbers.join(' / ') : '',
    });
  }

  bool _isTokenExpiredMessage(Map<String, dynamic> json) {
    final type = json['type']?.toString().toLowerCase().trim();
    final ok = json['ok'];
    final message = json['message']?.toString().toLowerCase().trim() ?? '';

    return type == 'error' &&
        ok == false &&
        message.contains('token expirado');
  }

  void _handleTokenExpired() {
    LogService.instance.logWarning('OCR_TOKEN_EXPIRED_FROM_WS', {
      'message': 'El WebSocket indicó token expirado',
    });

    _cachedToken = null;
    _tokenExpiresAt = null;

    setConnected(false);
    StatusLogBus.instance.addStatus('OCR', false);

    _stopWs();
    _scheduleReconnect(forceRefreshToken: true);
  }

  void _onError(dynamic error) {
    LogService.instance.logWarning('OCR_SOCKET_ERROR', {
      'error': error.toString(),
    });

    setConnected(false);
    StatusLogBus.instance.addStatus('OCR', false);

    _scheduleReconnect(forceRefreshToken: false);
  }

  void _onDone() {
    LogService.instance.logWarning('OCR_SOCKET_DONE', {
      'message': 'WebSocket OCR desconectado',
    });

    setConnected(false);
    StatusLogBus.instance.addStatus('OCR', false);

    _scheduleReconnect(forceRefreshToken: false);
  }

  void _scheduleReconnect({
    required bool forceRefreshToken,
  }) {
    if (!_shouldReconnect || _disposed || _lastUrl == null) return;
    if (_reconnectScheduled) return;

    _reconnectScheduled = true;

    Future.delayed(const Duration(seconds: 5), () async {
      _reconnectScheduled = false;

      if (!_shouldReconnect || _disposed || _lastUrl == null) return;

      _stopWs();

      try {
        final token = await _getValidToken(forceRefresh: forceRefreshToken);

        if (token == null || token.isEmpty) {
          setConnected(false);
          StatusLogBus.instance.addStatus('OCR', false);
          LogService.instance.logWarning('OCR_RECONNECT_NO_TOKEN', {});
          _scheduleReconnect(forceRefreshToken: true);
          return;
        }

        _doConnect(_lastUrl!, token);
      } catch (e, st) {
        setConnected(false);
        StatusLogBus.instance.addStatus('OCR', false);
        LogService.instance.logError('OCR_RECONNECT_ERROR', e, st);
        _scheduleReconnect(forceRefreshToken: true);
      }
    });
  }

  void _stopWs() {
    try {
      _channelSub?.cancel();
      _channelSub = null;
    } catch (_) {}

    try {
      _channel?.sink.close();
      _channel = null;
    } catch (_) {}
  }

  Future<String?> _loginAndGetTokenWithRetry() async {
    if (_authInProgress) {
      await Future.delayed(const Duration(milliseconds: 500));

      if (_hasValidCachedToken) return _cachedToken;
    }

    _authInProgress = true;

    try {
      const maxAttempts = 3;

      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final auth = await _loginAndGetTokenOnce(attempt: attempt);

          if (auth != null && auth.accessToken.isNotEmpty) {
            _cachedToken = auth.accessToken;

            final safeExpiresIn =
                auth.expiresIn > 60 ? auth.expiresIn - 30 : auth.expiresIn;

            _tokenExpiresAt = DateTime.now().add(
              Duration(seconds: safeExpiresIn),
            );

            LogService.instance.logRequest('OCR_AUTH_CACHE_SET', {
              'expiresIn': auth.expiresIn,
              'tokenExpiresAt': _tokenExpiresAt?.toIso8601String(),
            });

            return _cachedToken;
          }
        } catch (e, st) {
          LogService.instance.logError('OCR_AUTH_ATTEMPT_ERROR', e, st);
        }

        if (attempt < maxAttempts) {
          await Future.delayed(Duration(seconds: attempt));
        }
      }

      LogService.instance.logWarning('OCR_AUTH_RETRY_EXHAUSTED', {
        'attempts': maxAttempts,
      });

      return null;
    } finally {
      _authInProgress = false;
    }
  }

  Future<OcrAuthResult?> _loginAndGetTokenOnce({
    required int attempt,
  }) async {
    final authUrl = dotenv.env['OCR_AUTH_URL'] ?? '';
    final clientId = dotenv.env['OCR_CLIENT_ID'] ?? '';
    final clientSecret = dotenv.env['OCR_CLIENT_SECRET'] ?? '';

    if (authUrl.trim().isEmpty ||
        clientId.trim().isEmpty ||
        clientSecret.trim().isEmpty) {
      LogService.instance.logWarning('OCR_AUTH_CONFIG_MISSING', {
        'hasAuthUrl': authUrl.trim().isNotEmpty,
        'hasClientId': clientId.trim().isNotEmpty,
        'hasClientSecret': clientSecret.trim().isNotEmpty,
      });
      return null;
    }

    LogService.instance.logRequest('OCR_AUTH_START', {
      'url': authUrl,
      'clientId': clientId,
      'attempt': attempt,
    });

    final response = await http
        .post(
          Uri.parse(authUrl),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'grant_type': 'client_credentials',
            'client_id': clientId,
            'client_secret': clientSecret,
          },
        )
        .timeout(const Duration(seconds: 15));

    LogService.instance.logRequest('OCR_AUTH_RESPONSE', {
      'statusCode': response.statusCode,
      'bodyLength': response.body.length,
      'attempt': attempt,
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      LogService.instance.logWarning('OCR_AUTH_FAILED', {
        'statusCode': response.statusCode,
        'body': response.body,
        'attempt': attempt,
      });
      return null;
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      LogService.instance.logWarning('OCR_AUTH_INVALID_JSON', {
        'attempt': attempt,
      });
      return null;
    }

    final auth = OcrAuthResult.fromJson(decoded);

    if (auth.accessToken.isEmpty) {
      LogService.instance.logWarning('OCR_AUTH_TOKEN_EMPTY', {
        'attempt': attempt,
      });
      return null;
    }

    LogService.instance.logRequest('OCR_AUTH_OK', {
      'expiresIn': auth.expiresIn,
      'tokenLength': auth.accessToken.length,
      'attempt': attempt,
    });

    return auth;
  }

  @override
  void dispose() {
    _disposed = true;
    _shouldReconnect = false;
    _reconnectScheduled = false;

    super.dispose();

    _stopWs();
    _ocrEventCtrl.close();
  }
}