// lib/services/conectivity/gate_control_service.dart
// Autor: Abraham Yance
// Fecha: 2025-11-28
// Desc: Servicio para abrir la barrera usando control_gate_service

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';

class GateControlService {
  GateControlService._();

  static final GateControlService instance = GateControlService._();

  /// Cambia a false cuando termines las pruebas en Postman.
  /// En true imprime api-key y key_plc completos.
  static const bool _printSensitiveForPostman = true;

  Future<bool> openGate({
    required String url,

    /// API KEY que va en el HEADER:
    /// headers['api-key']
    required String headerApiKey,

    /// KEY PLC que va dentro del JSON codificado en base64:
    /// Token.api_key
    required String bodyApiKey,

    required String gateLocation,
    required int gate,
    required int side,
  }) async {
    final log = LogService.instance;

    final u = url.trim();
    final cleanHeaderApiKey = headerApiKey.trim();
    final cleanBodyApiKey = bodyApiKey.trim();
    final cleanGateLocation = gateLocation.trim().isNotEmpty
        ? gateLocation.trim()
        : gate.toString();

    if (u.isEmpty) {
      await log.logWarning('GATE_OPEN_SKIP', {'reason': 'url vacío'});
      return false;
    }

    final uri = Uri.tryParse(u);
    if (uri == null || uri.host.isEmpty) {
      await log.logWarning('GATE_OPEN_SKIP', {
        'reason': 'url inválida (sin host)',
        'url': u,
      });
      return false;
    }

    if (cleanHeaderApiKey.isEmpty) {
      await log.logWarning('GATE_OPEN_SKIP', {
        'reason': 'header api-key vacío',
        'url': u,
        'gate': gate,
        'side': side,
      });
      return false;
    }

    if (cleanBodyApiKey.isEmpty) {
      await log.logWarning('GATE_OPEN_SKIP', {
        'reason': 'body api_key/keyPlc vacío',
        'url': u,
        'gate': gate,
        'side': side,
      });
      return false;
    }

    if (gate <= 0 || side <= 0) {
      await log.logWarning('GATE_OPEN_SKIP', {
        'reason': 'gate/side inválidos',
        'url': u,
        'gate': gate,
        'side': side,
        'gateLocation': cleanGateLocation,
      });
      return false;
    }

    final tokenPayload = <String, dynamic>{
      'gate': gate,
      'api_key': cleanBodyApiKey,
      'side': side,
    };

    const encoder = JsonEncoder.withIndent('    ');
    final tokenJsonPretty = encoder.convert(tokenPayload);
    final tokenBase64 = base64.encode(utf8.encode(tokenJsonPretty));

    final bodyMap = <String, dynamic>{
      'Token': tokenBase64,
    };

    final body = jsonEncode(bodyMap);

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'api-key': cleanHeaderApiKey,
      'gate-location': cleanGateLocation,
    };

    await log.logRequest('GATE_OPEN_REQUEST', {
      'url': u,
      'headers': _printSensitiveForPostman ? headers : _safeHeaders(headers),
      'headerApiKeySource': 'gateConfig.apiKey',
      'bodyApiKeySource': 'gateConfig.keyPlc',
      'tokenPayload': _printSensitiveForPostman
          ? tokenPayload
          : {
              'gate': gate,
              'api_key': _mask(cleanBodyApiKey),
              'side': side,
            },
      'tokenJsonPretty': _printSensitiveForPostman
          ? tokenJsonPretty
          : tokenJsonPretty.replaceAll(cleanBodyApiKey, _mask(cleanBodyApiKey)),
      'tokenBase64': _printSensitiveForPostman ? tokenBase64 : '<hidden>',
      'body': _printSensitiveForPostman ? body : '<hidden>',
      'headerApiKeyLen': cleanHeaderApiKey.length,
      'bodyApiKeyLen': cleanBodyApiKey.length,
      'tokenBase64_len': tokenBase64.length,
      'body_len': body.length,
    });

    try {
      final resp = await http.post(
        uri,
        headers: headers,
        body: body,
      );

      await log.logRequest('GATE_OPEN_RESPONSE', {
        'statusCode': resp.statusCode,
        'headers': resp.headers,
        'body': resp.body,
      });


      return resp.statusCode >= 200 && resp.statusCode < 300;
    } catch (e, st) {
      await log.logError('GATE_OPEN_EXCEPTION', e, st);

      return false;
    }
  }

  Map<String, String> _safeHeaders(Map<String, String> headers) {
    final copy = Map<String, String>.from(headers);

    if (copy.containsKey('api-key')) {
      copy['api-key'] = _mask(copy['api-key'] ?? '');
    }

    return copy;
  }

  String _mask(String value, {int keepStart = 4, int keepEnd = 4}) {
    if (value.isEmpty) return '';
    if (value.length <= keepStart + keepEnd) return '***';

    return '${value.substring(0, keepStart)}***${value.substring(value.length - keepEnd)}';
  }
}