import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'package:tpg_attack_kiosko_muelle/models/attack/gate_config_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/attack/kioskConfig_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/attack/parameters_atak_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/auth/login_orchestrator_model.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';

class LoginOrchestratorService {
  static final _baseUrl = dotenv.env['BASE_MIDDLEWARE_URL'] ?? '';

  static Future<LoginOrchestratorResponse?> executeLogin({
    required String username,
    required String usernameApp,
    required String password,
    required String bascula,
    required String app,
    required Map<String, dynamic> machineInfo,
  }) async {
    final url = '${_baseUrl}kiosk/api/login/authenticate';
    final uri = Uri.parse(url);
    final sw = Stopwatch()..start();

    await LogService.instance.logRequest('LOGIN_ORCH_START', {
      'url': url,
      'method': 'POST',
      'username': username,
      'usernameApp': usernameApp,
      'bascula': bascula,
      'app': app,
      'machineInfo': machineInfo,
    });

    try {
      final domain = (machineInfo['domain_ps'] ?? machineInfo['domain_env'])
          ?.toString();

      final payload = <String, dynamic>{
        'username': username,
        'usernameApp': usernameApp,
        'password': password,
        'app': app,
        'bascula': bascula,
        'group': dotenv.env['GROUP'] ?? 'KIOSKO',
        'deviceId': '5d83931a-d596-42f0-937b-ec606c033674',
        'kioskCode': dotenv.env['KIOSK_CODE'] ?? '',
        'hostname': machineInfo['hostname'],
        'domain': domain,
        'uuid': machineInfo['uuid'],
        'ipAddress': _pickIp(machineInfo['ips']),
        'ips': machineInfo['ips'],
        'appVersion': dotenv.env['APP_VERSION'] ?? 'unknown',
      };

      final headers = <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

      await LogService.instance.logRequest('LOGIN_ORCH_REQUEST', {
        'url': url,
        'method': 'POST',
        'headers': headers,
        'payload': _safePayload(payload),
        'payloadPretty': _prettyJson(_safePayload(payload)),
      });

      final res = await http
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 90));

      await LogService.instance.logRequest('LOGIN_ORCH_RESPONSE_RAW', {
        'url': url,
        'statusCode': res.statusCode,
        'latencyMs': sw.elapsedMilliseconds,
        'rawBody': res.body,
      });

      if (res.statusCode != 200 && res.statusCode != 201) {
        await LogService.instance.logError('LOGIN_ORCH_HTTP_FAIL', {
          'url': url,
          'statusCode': res.statusCode,
          'latencyMs': sw.elapsedMilliseconds,
          'rawBody': res.body,
          'requestPayload': _safePayload(payload),
        });

        return null;
      }

      final decoded = jsonDecode(utf8.decode(res.bodyBytes));

      if (decoded is! Map<String, dynamic>) {
        await LogService.instance.logWarning('LOGIN_ORCH_INVALID_JSON', {
          'url': url,
          'statusCode': res.statusCode,
          'rawBody': res.body,
        });

        return null;
      }

      await LogService.instance.logRequest('LOGIN_ORCH_RESPONSE_JSON', {
        'url': url,
        'statusCode': res.statusCode,
        'latencyMs': sw.elapsedMilliseconds,
        'decoded': _safeLoginOrchResponse(decoded),
        'decodedPretty': _prettyJson(_safeLoginOrchResponse(decoded)),
      });

      final parsed = LoginOrchestratorResponse.fromJson(decoded);

      await LogService.instance.logRequest('LOGIN_ORCH_PARSED', {
        'errorCode': parsed.errorCode,
        'message': parsed.message,
        'services': {
          'ldapUser': _stepSummary(parsed.data.ldapUser),
          'middlewareLogin': _stepSummary(parsed.data.middlewareLogin),
          'kioskConfig': _stepSummary(parsed.data.kioskConfig),
          'kioskGate': _stepSummary(parsed.data.gateRes),
        },
      });

      await _saveLoginState(parsed);

      await LogService.instance.logRequest('LOGIN_ORCH_OK', {
        'latencyMs': sw.elapsedMilliseconds,
        'errorCode': parsed.errorCode,
        'message': parsed.message,
        'appStateSaved': true,
      });

      return parsed;
    } catch (e, st) {
      await LogService.instance.logError('LOGIN_ORCH_EXCEPTION', e, st);

      await LogService.instance.logRequest('LOGIN_ORCH_FAIL_CONTEXT', {
        'latencyMs': sw.elapsedMilliseconds,
        'url': url,
        'username': username,
        'usernameApp': usernameApp,
        'bascula': bascula,
        'app': app,
        'machineInfo': machineInfo,
      });

      return null;
    }
  }

  static Future<void> _saveLoginState(LoginOrchestratorResponse parsed) async {
    final sw = Stopwatch()..start();

    try {
      final appState = AppStateManager.instance;

      final middlewareData = parsed.data.middlewareLogin?.data;
      final kioskCfgData = parsed.data.kioskConfig?.data;
      final gateData = parsed.data.gateRes?.data;
      final parametersData = parsed.data.parametersAtak?.data;
      final sessionData = parsed.data.kioskSessionLogIns?.data;

      await LogService.instance.logRequest('LOGIN_ORCH_SAVE_STATE_START', {
        'hasMiddlewareData': middlewareData != null,
        'hasKioskConfigData': kioskCfgData != null,
        'hasGateData': gateData != null,
        'hasParametersAtakData': parametersData != null,
        'hasSessionLogData': sessionData != null,
        'middlewareData': _safeDynamic(middlewareData),
        'kioskCfgData': kioskCfgData,
        'gateData': gateData,
        'parametersAtakData': parametersData,
        'sessionData': sessionData,
      });

      if (middlewareData is Map<String, dynamic>) {
        final accessToken = middlewareData['accessToken']?.toString() ?? '';
        final refreshToken = middlewareData['refreshToken']?.toString() ?? '';

        appState.setTokens(accessToken, refreshToken);

        await LogService.instance.logRequest('LOGIN_ORCH_TOKENS_SAVED', {
          'hasAccessToken': accessToken.isNotEmpty,
          'hasRefreshToken': refreshToken.isNotEmpty,
          'accessTokenPreview': _tokenPreview(accessToken),
          'refreshTokenPreview': _tokenPreview(refreshToken),
        });
      }

      if (kioskCfgData is Map<String, dynamic>) {
        final cfg = KioskConfigModel.fromJson(kioskCfgData);
        appState.setKioskConfig(cfg);

        await LogService.instance.logRequest('LOGIN_ORCH_KIOSK_CONFIG_SAVED', {
          'raw': kioskCfgData,
          'gate': cfg.gate,
          'gateLetter': cfg.gateLetter,
          'patio': cfg.patio,
          'kioskServer': cfg.kioskServer,
          'kioskServerPort': cfg.kioskServerPort,
        });
      }

      if (gateData is List && gateData.isNotEmpty) {
        final firstGate = gateData[0];

        if (firstGate is Map<String, dynamic>) {
          final gateCfg = GateConfigModel.fromJson(firstGate);
          appState.setGateConfig(gateCfg);

          await LogService.instance.logRequest('LOGIN_ORCH_GATE_CONFIG_SAVED', {
            'raw': firstGate,
            'name': gateCfg.name,
            'side': gateCfg.side,
            'serverApp': gateCfg.serverApp,
            'serverPlc': gateCfg.serverPlc,
            'gateLocation': gateCfg.gateLocation,
            'movimientos': gateCfg.movimientos,
          });
        }
      }

      if (parametersData is Map<String, dynamic>) {
        final parameters = ParametersAtakModel.fromJson(parametersData);
        appState.setParametersAtak(parameters);

        await LogService.instance
            .logRequest('LOGIN_ORCH_PARAMETERS_ATAK_SAVED', {
              'raw': parametersData,
              'PORTEOPESO': parameters.porteoPeso,
              'peso_bypass': parameters.pesoBypass,
              'peso_promedio': parameters.pesoPromedio,
              'promedio_porteo': parameters.promedioPorteo,
              'tolerancia_porteo': parameters.toleranciaPorteo,
              'tolerancia_vacio': parameters.toleranciaVacio,
              'huella': parameters.huella,
              'huella_muelle': parameters.huellaMuelle,
              'peso_a_mano': parameters.pesoAMano,
            });
      } else {
        await LogService.instance.logWarning(
          'LOGIN_ORCH_PARAMETERS_ATAK_MISSING',
          {'parametersData': parametersData},
        );
      }

      if (sessionData is Map<String, dynamic>) {
        await LogService.instance.logRequest('LOGIN_ORCH_SESSION_LOG_SAVED', {
          'errcode': sessionData['errcode'],
          'errmsg': sessionData['errmsg'],
          'session_id': sessionData['session_id'],
        });
      }

      await LogService.instance.logRequest('LOGIN_ORCH_SAVE_STATE_OK', {
        'latencyMs': sw.elapsedMilliseconds,
        'hasParametersAtak': appState.hasParametersAtak,
        'porteoPeso': appState.porteoPeso,
        'pesoBypass': appState.pesoBypass,
        'pesoPromedio': appState.pesoPromedio,
      });
    } catch (e, st) {
      await LogService.instance.logError(
        'LOGIN_ORCH_SAVE_STATE_EXCEPTION',
        e,
        st,
      );

      await LogService.instance.logWarning('LOGIN_ORCH_SAVE_STATE_FAIL', {
        'latencyMs': sw.elapsedMilliseconds,
        'error': e.toString(),
      });
    }
  }

  static String? _pickIp(dynamic ips) {
    if (ips is List && ips.isNotEmpty) {
      final ipv4 = ips
          .cast<dynamic>()
          .map((e) => e.toString())
          .firstWhere(
            (s) => s.isNotEmpty && !s.contains(':'),
            orElse: () => '',
          );

      if (ipv4.isNotEmpty) return ipv4;

      return ips.first.toString();
    }

    return null;
  }

  static Map<String, dynamic> _safePayload(Map<String, dynamic> payload) {
    final copy = Map<String, dynamic>.from(payload);

    if (copy.containsKey('password')) {
      final raw = copy['password']?.toString() ?? '';
      copy['password'] = raw.isEmpty ? '' : '***';
      copy['passwordLength'] = raw.length;
    }

    return copy;
  }

  static Map<String, dynamic> _safeLoginOrchResponse(
    Map<String, dynamic> json,
  ) {
    final copy = Map<String, dynamic>.from(json);

    final data = copy['data'];

    if (data is Map<String, dynamic>) {
      final dataCopy = Map<String, dynamic>.from(data);
      final services = dataCopy['services'];

      if (services is Map<String, dynamic>) {
        final servicesCopy = Map<String, dynamic>.from(services);

        final middlewareLogin = servicesCopy['middlewareLogin'];
        if (middlewareLogin is Map<String, dynamic>) {
          final middlewareCopy = Map<String, dynamic>.from(middlewareLogin);
          middlewareCopy['data'] = _safeDynamic(middlewareCopy['data']);
          servicesCopy['middlewareLogin'] = middlewareCopy;
        }

        dataCopy['services'] = servicesCopy;
      }

      copy['data'] = dataCopy;
    }

    return copy;
  }

  static dynamic _safeDynamic(dynamic value) {
    if (value is Map<String, dynamic>) {
      final copy = Map<String, dynamic>.from(value);

      if (copy.containsKey('accessToken')) {
        copy['accessToken'] = _tokenPreview(copy['accessToken']);
      }

      if (copy.containsKey('refreshToken')) {
        copy['refreshToken'] = _tokenPreview(copy['refreshToken']);
      }

      if (copy.containsKey('password')) {
        copy['password'] = '***';
      }

      return copy;
    }

    if (value is List) {
      return value.map(_safeDynamic).toList();
    }

    return value;
  }

  static Map<String, dynamic>? _stepSummary(StepEnvelope? step) {
    if (step == null) return null;

    return {
      'errorCode': step.errorCode,
      'message': step.message,
      'spErrorCode': step.spErrorCode,
      'spMessage': step.spMessage,
      'hasData': step.data != null,
      'data': _safeDynamic(step.data),
    };
  }

  static String? _tokenPreview(dynamic token) {
    final value = token?.toString();

    if (value == null || value.isEmpty) return null;
    if (value.length <= 16) return '***';

    return '${value.substring(0, 8)}...${value.substring(value.length - 6)}';
  }

  static String _prettyJson(dynamic value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }
}
