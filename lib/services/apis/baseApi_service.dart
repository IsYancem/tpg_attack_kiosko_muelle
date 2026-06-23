// lib/services/apis/baseApi_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/authApi_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/secure_storage_service.dart';

enum HttpMethod { get, post, put, patch, delete }

class RequestSpec {
  final String path; // relativo a BASE_MIDDLEWARE_URL
  final HttpMethod method;
  final String tag; // para logs
  final Map<String, String>? query; // ?a=1&b=2
  final Map<String, dynamic>? body; // payload JSON
  final Map<String, String>? headers; // overrides/extra
  final Duration timeout; // default 20s

  RequestSpec({
    required this.path,
    required this.method,
    required this.tag,
    this.query,
    this.body,
    this.headers,
    this.timeout = const Duration(seconds: 20),
  });
}

/// Envoltorio estándar de TODA respuesta.
/// T será SIEMPRE el tipo del campo "data".
class ApiEnvelope<T> {
  final int errorCode;
  final String message;
  final T? data;

  ApiEnvelope({
    required this.errorCode,
    required this.message,
    required this.data,
  });

  bool get isOk => errorCode == 0;

  Map<String, dynamic> toJson(dynamic Function(T v)? encoder) => {
    'errorCode': errorCode,
    'message': message,
    'data': data == null
        ? null
        : (encoder == null ? data : encoder(data as T)),
  };
}

abstract class BaseApiService {
  BaseApiService();

  String get _base => dotenv.env['BASE_MIDDLEWARE_URL'] ?? '';

  Uri _buildUri(RequestSpec spec) {
    final u = Uri.parse('$_base${spec.path}');
    if (spec.query == null || spec.query!.isEmpty) return u;
    return u.replace(queryParameters: {...u.queryParameters, ...spec.query!});
  }

  Future<Map<String, String>> _defaultHeaders() async {
    final h = <String, String>{'Accept': 'application/json'};
    final token = await SecureStorageService.getToken();
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  Future<http.Response> _execOnce(Uri uri, RequestSpec spec) async {
    final client = LogService.instance.httpClient;
    final headers = {
      ...(await _defaultHeaders()),
      if (spec.method != HttpMethod.get) 'Content-Type': 'application/json',
      ...(spec.headers ?? {}),
    };

    switch (spec.method) {
      case HttpMethod.get:
        return client.get(uri, headers: headers).timeout(spec.timeout);
      case HttpMethod.post:
        return client
            .post(uri, headers: headers, body: json.encode(spec.body ?? {}))
            .timeout(spec.timeout);
      case HttpMethod.put:
        return client
            .put(uri, headers: headers, body: json.encode(spec.body ?? {}))
            .timeout(spec.timeout);
      case HttpMethod.patch:
        return client
            .patch(uri, headers: headers, body: json.encode(spec.body ?? {}))
            .timeout(spec.timeout);
      case HttpMethod.delete:
        return client
            .delete(uri, headers: headers, body: json.encode(spec.body ?? {}))
            .timeout(spec.timeout);
    }
  }

  /// Runner genérico:
  /// - log start/end + retry si 401/403
  /// - decodifica envelope y aplica decoder SOLO a data
  Future<ApiEnvelope<T>> call<T>({
    required RequestSpec spec,
    required T Function(Map<String, dynamic> data) decoder,
  }) async {
    final uri = _buildUri(spec);

    // try #1
    LogService.instance.logConnStart(
      kind: 'http',
      target: uri.toString(),
      extra: {
        'tag': spec.tag,
        'method': spec.method.name.toUpperCase(),
        if (spec.body != null) 'hasBody': true,
        'try': 1,
      },
    );
    var res = await _execOnce(uri, spec);
    LogService.instance.logConnEnd(
      kind: 'http',
      target: uri.toString(),
      ok: res.statusCode == 200,
      extra: {'tag': spec.tag, 'status': res.statusCode, 'try': 1},
    );

    // refresh si 401/403
    if (res.statusCode == 401 || res.statusCode == 403) {
      LogService.instance.logWarning('AUTH_EXPIRED', {
        'tag': spec.tag,
        'uri': uri.toString(),
        'status': res.statusCode,
        'action': 'refresh',
      });

      final appState = AppStateManager.instance;

      final refreshed = await AuthApiService.refresh(appState);
      if (refreshed) {
        LogService.instance.logConnStart(
          kind: 'http',
          target: uri.toString(),
          extra: {
            'tag': spec.tag,
            'method': spec.method.name.toUpperCase(),
            'try': 2,
          },
        );
        res = await _execOnce(uri, spec);
        LogService.instance.logConnEnd(
          kind: 'http',
          target: uri.toString(),
          ok: res.statusCode == 200,
          extra: {'tag': spec.tag, 'status': res.statusCode, 'try': 2},
        );
      }
    }

    // Si no es 200 devolvemos envelope "técnico" con error
    if (res.statusCode != 200 && res.statusCode != 201) {
      return ApiEnvelope<T>(
        errorCode: 1,
        message: 'HTTP ${res.statusCode}',
        data: null,
      );
    }

    // Parse envelope
    final map = json.decode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final err = (map['errorCode'] ?? 1) as int;
    final msg = (map['message'] ?? '').toString();
    final rawData = map['data'];

    T? parsed;
    if (rawData is Map<String, dynamic>) {
      parsed = decoder(Map<String, dynamic>.from(rawData));
    } else if (rawData == null) {
      parsed = null;
    } else {
      // data NO es objeto (lista o primitivo): intentamos envolver
      parsed = decoder({'value': rawData});
    }

    return ApiEnvelope<T>(errorCode: err, message: msg, data: parsed);
  }
}
