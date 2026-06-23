import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;

class LogService extends ChangeNotifier {
  LogService._internal();
  static final LogService instance = LogService._internal();

  static const int _maxFileBytes = 20 * 1024 * 1024;
  int maxRetentionDays = 10;

  final DateFormat _dayFmt = DateFormat('yyyy-MM-dd');
  late final Directory _logDir;
  late File _currentFile;
  bool _initialised = false;

  late final http.Client httpClient;
  late final Interceptor dioInterceptor;

  // Callback tipado para loggers internos (HTTP/DIO)
  late final Future<void> Function(
    String status,
    String component,
    Map<String, dynamic> details,
  )
  _sink;

  Future<void> init({int? maxDays}) async {
    if (_initialised) return;
    if (maxDays != null) maxRetentionDays = maxDays;

    final baseDir = (Platform.isAndroid || Platform.isIOS)
        ? await getApplicationDocumentsDirectory()
        : Directory.current;

    _logDir = Directory(p.join(baseDir.path, 'logs'));
    if (!await _logDir.exists()) await _logDir.create(recursive: true);

    _currentFile = await _ensureActiveFile(DateTime.now());
    await _purgeOldFiles();

    _sink = _enqueueLine;

    httpClient = _LogHttpClient(_sink);
    dioInterceptor = _LogDioInterceptor(_sink);

    _initialised = true;
  }

  Future<void> _logQueue = Future<void>.value();

  Future<void> _enqueueLine(
    String status,
    String component,
    Map<String, dynamic> details,
  ) {
    final safeDetails = Map<String, dynamic>.from(details);

    _logQueue = _logQueue
        .then<void>((_) async {
          await _writeLine(status, component, safeDetails);
        })
        .catchError((Object error, StackTrace st) {
          if (kDebugMode) {
            debugPrint('[LogService] Error escribiendo log: $error');
          }
        });

    return Future<void>.value();
  }

  Future<void> flush() async {
    await _logQueue;
  }

  Future<void> logRequest(String action, Map<String, dynamic> details) {
    return _enqueueLine('INFO', action, details);
  }

  Future<void> logWarning(String action, Map<String, dynamic> details) {
    return _enqueueLine('WARN', action, details);
  }

  Future<void> logWarning2(String action) {
    return _enqueueLine('WARN', 'WARNING', {'message': action});
  }

  Future<void> logError(String action, Object error, [StackTrace? st]) {
    return _enqueueLine('ERROR', action, {
      'error': _errToMap(error),
      if (st != null) 'stack': st.toString(),
    });
  }

  /// Formatea el offset de zona horaria, p.ej. -05:00 (Ecuador)
  String _fmtOffset(Duration o) {
    final sign = o.isNegative ? '-' : '+';
    final d = o.abs();
    final hh = d.inHours.toString().padLeft(2, '0');
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$sign$hh:$mm';
  }

  String _nowStr() {
    final now = DateTime.now().toLocal();
    return '${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)} ${_fmtOffset(now.timeZoneOffset)}';
  }

  /// Registra inicio de intento de conexión (socket/http/db/etc.)
  Future<void> logConnStart({
    required String kind,
    required String target,
    Map<String, dynamic>? extra,
  }) async {
    return _enqueueLine('INFO', 'CONN_START', {
      'kind': kind,
      'target': target,
      'extra': extra ?? {},
    });
  }

  /// Registra fin de intento de conexión
  Future<void> logConnEnd({
    required String kind,
    required String target,
    required bool ok,
    int? ms,
    Object? error,
    Map<String, dynamic>? extra,
  }) async {
    return _enqueueLine(ok ? 'INFO' : 'ERROR', 'CONN_END', {
      'kind': kind,
      'target': target,
      'ok': ok,
      if (ms != null) 'latency_ms': ms,
      if (error != null) 'error': _errToMap(error),
      if (extra != null) 'extra': extra,
    });
  }

  // ===========================================================================
  // ✅ Formato estándar para resultado de “SP/servicio”
  // ===========================================================================
  /// ✅ SP_RES es ERROR automáticamente si errorCode != 0
  Future<void> logSpResult({
    required String service,
    required String path,
    required int errorCode,
    required String message,
    Map<String, dynamic>? data,
    int? latencyMs,
    String? levelOverride,
  }) async {
    final details = <String, dynamic>{
      'service': service,
      'path': path,
      'errorCode': errorCode,
      'message': message,
      if (latencyMs != null) 'latency_ms': latencyMs,
      if (data != null) 'data': data,
    };

    // ✅ Regla: errorCode != 0 => ERROR
    final status = levelOverride ?? (errorCode == 0 ? 'INFO' : 'ERROR');

    // ✅ ahora SIEMPRE: datetime | STATUS | COMPONENT | DETAILS(JSON)
    return _enqueueLine(status, 'SP_RES', details);
  }

  // ===========================================================================
  // ✅ FORMATO ÚNICO Y OBLIGATORIO:
  // datetime | STATUS | COMPONENT | DETAILS(JSON)
  // ===========================================================================
  Future<void> _writeLine(
    String status,
    String component,
    Map<String, dynamic> details,
  ) async {
    // ⛑️ Asegura init antes de usar _currentFile
    if (!_initialised) {
      await init();
    }

    final now = DateTime.now();

    // Rotación diaria
    if (await _currentFile.exists()) {
      final currentFileDate = await _currentFile.lastModified();
      if (_dayFmt.format(now) != _dayFmt.format(currentFileDate)) {
        _currentFile = await _ensureActiveFile(now);
      }
    } else {
      final currentDay = _dayFmt.format(now);
      final currentFileName = p.basename(_currentFile.path);
      if (!currentFileName.startsWith(currentDay)) {
        _currentFile = await _ensureActiveFile(now);
      }
    }

    // Rotación por tamaño
    if (await _currentFile.exists() &&
        await _currentFile.length() >= _maxFileBytes) {
      _currentFile = await _nextRotatedFile(now);
    }

    if (!await _currentFile.exists()) {
      await _currentFile.create(recursive: true);
    }

    // ✅ Línea final estricta:
    // datetime | STATUS | COMPONENT | DETAILS(JSON)
    final line =
        '${_nowStr()} | $status | $component | ${jsonEncode(details)}\n';

    await _currentFile.writeAsString(
      line,
      mode: FileMode.append,
      flush: status == 'ERROR',
    );

    if (kDebugMode) debugPrint(line.trimRight());
  }

  Map<String, dynamic> _errToMap(Object e) {
    if (e is Error) {
      return {'message': e.toString(), 'stack': e.stackTrace.toString()};
    }
    return {'error': e.toString()};
  }

  Future<File> _ensureActiveFile(DateTime date) async {
    final prefix = '${_dayFmt.format(date)}-app.log';

    // Buscar todos los archivos de ese día
    final files = _logDir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith(prefix))
        .toList();

    if (files.isEmpty) {
      final file = File(p.join(_logDir.path, prefix));
      await file.create(recursive: true);
      return file;
    }

    // Ordenar para obtener el último
    files.sort((a, b) => _compareLogFiles(a.path, b.path));
    final last = files.last;

    if (await last.length() < _maxFileBytes) {
      return last;
    }

    return await _nextRotatedFile(date);
  }

  Future<File> _nextRotatedFile(DateTime date) async {
    final prefix = '${_dayFmt.format(date)}-app.log';

    // Buscar el número más alto existente
    int maxSuffix = 1;
    final baseFile = File(p.join(_logDir.path, prefix));

    // Si existe el archivo base, empezar desde .2
    if (await baseFile.exists()) {
      maxSuffix = 2;
    }

    // Buscar archivos con sufijo numérico
    final reg = RegExp('^${RegExp.escape(prefix)}\\.(\\d+)\$');

    for (final f in _logDir.listSync().whereType<File>()) {
      final match = reg.firstMatch(p.basename(f.path));
      if (match != null) {
        final num = int.tryParse(match.group(1)!);
        if (num != null && num >= maxSuffix) {
          maxSuffix = num + 1;
        }
      }
    }

    final name = '$prefix.$maxSuffix';
    final file = File(p.join(_logDir.path, name));
    await file.create(recursive: true);
    return file;
  }

  // Función auxiliar para comparar archivos de log correctamente
  int _compareLogFiles(String pathA, String pathB) {
    final nameA = p.basename(pathA);
    final nameB = p.basename(pathB);

    // Extraer números de sufijo
    final regexA = RegExp(r'\.(\d+)$');
    final regexB = RegExp(r'\.(\d+)$');

    final matchA = regexA.firstMatch(nameA);
    final matchB = regexB.firstMatch(nameB);

    final suffixA = matchA != null ? int.parse(matchA.group(1)!) : 0;
    final suffixB = matchB != null ? int.parse(matchB.group(1)!) : 0;

    return suffixA.compareTo(suffixB);
  }

  Future<void> _purgeOldFiles() async {
    final cutoff = DateTime.now().subtract(Duration(days: maxRetentionDays));
    final regex = RegExp(r'^(\d{4}-\d{2}-\d{2})');

    await for (final entity in _logDir.list()) {
      if (entity is! File) continue;

      final match = regex.firstMatch(p.basename(entity.path));
      if (match == null) continue;

      final dateStr = match.group(1);
      if (dateStr == null) continue;
      final date = DateTime.tryParse(dateStr);
      if (date == null) continue;

      if (date.isBefore(cutoff)) {
        try {
          await entity.delete();
        } catch (_) {
          /* ignore */
        }
      }
    }
  }

  // ===========================================================================
  // ✅ Formato estándar para “SP/servicio ejecutado” + payload enviado
  // ===========================================================================
  /// Por defecto SP_EXEC es INFO.
  /// Puedes forzar status con levelOverride: 'INFO' | 'WARN' | 'ERROR'
  Future<void> logSpExec({
    required String service,
    required String path,
    String method = 'POST',
    Map<String, dynamic>? payload,
    Map<String, dynamic>? context,
    String? levelOverride,
  }) async {
    final details = <String, dynamic>{
      'service': service,
      'method': method,
      'path': path,
      'payload': payload ?? {},
      if (context != null) 'context': context,
    };

    final status = levelOverride ?? 'INFO';

    // ✅ ahora SIEMPRE: datetime | STATUS | COMPONENT | DETAILS(JSON)
    return _enqueueLine(status, 'SP_EXEC', details);
  }
}

class _LogHttpClient extends http.BaseClient {
  _LogHttpClient(this._log);
  final Future<void> Function(
    String status,
    String component,
    Map<String, dynamic> details,
  )
  _log;

  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest req) async {
    final start = DateTime.now();
    try {
      final res = await _inner.send(req);
      final ms = DateTime.now().difference(start).inMilliseconds;
      await _log('INFO', 'HTTP', {
        'method': req.method,
        'url': req.url.toString(),
        'statusCode': res.statusCode,
        'latency_ms': ms,
      });
      return res;
    } catch (e) {
      final ms = DateTime.now().difference(start).inMilliseconds;
      await _log('ERROR', 'HTTP', {
        'method': req.method,
        'url': req.url.toString(),
        'latency_ms': ms,
        'error': {'message': e.toString()},
      });
      rethrow;
    }
  }
}

class _LogDioInterceptor extends Interceptor {
  _LogDioInterceptor(this._log);
  final Future<void> Function(
    String status,
    String component,
    Map<String, dynamic> details,
  )
  _log;

  @override
  void onRequest(RequestOptions opts, RequestInterceptorHandler h) {
    opts.extra['start'] = DateTime.now();
    super.onRequest(opts, h);
  }

  @override
  void onResponse(Response res, ResponseInterceptorHandler h) async {
    final start = res.requestOptions.extra['start'] as DateTime?;
    final ms = start != null
        ? DateTime.now().difference(start).inMilliseconds
        : null;

    await _log('INFO', 'DIO_HTTP', {
      'method': res.requestOptions.method,
      'url': res.requestOptions.uri.toString(),
      'statusCode': res.statusCode,
      if (ms != null) 'latency_ms': ms,
    });

    super.onResponse(res, h);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler h) async {
    final start = err.requestOptions.extra['start'] as DateTime?;
    final ms = start != null
        ? DateTime.now().difference(start).inMilliseconds
        : null;

    await _log('ERROR', 'DIO_HTTP', {
      'method': err.requestOptions.method,
      'url': err.requestOptions.uri.toString(),
      if (err.response?.statusCode != null)
        'statusCode': err.response!.statusCode,
      if (ms != null) 'latency_ms': ms,
      'error': {
        'type': err.type.toString(),
        'message': (err.error ?? err.message).toString(),
      },
    });

    super.onError(err, h);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Log helpers para pantallas y navegación
// ─────────────────────────────────────────────────────────────────────────────

extension ScreenLogging on LogService {
  Future<void> logScreenEnter(
    String screenName, {
    String? route,
    Map<String, dynamic>? extra,
  }) async {
    await logRequest('SCREEN_ENTER', {
      'screen': screenName,
      if (route != null) 'route': route,
      ...?extra,
    });
  }

  Future<void> logScreenExit(
    String screenName, {
    String? route,
    Map<String, dynamic>? extra,
  }) async {
    await logRequest('SCREEN_EXIT', {
      'screen': screenName,
      if (route != null) 'route': route,
      ...?extra,
    });
  }

  Future<void> logNavigation({
    String? from,
    String? to,
    String action = 'push',
    Map<String, dynamic>? extra,
  }) async {
    await logRequest('NAVIGATE', {
      'action': action, // push | pop | replace
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      ...?extra,
    });
  }
}

/// RouteObserver que loguea automáticamente transiciones Navigator
class NavLogObserver extends RouteObserver<PageRoute<dynamic>> {
  static final NavLogObserver instance = NavLogObserver();

  String _routeName(Route<dynamic>? r) =>
      (r?.settings.name?.isNotEmpty ?? false)
      ? r!.settings.name!
      : (r is PageRoute ? r.settings.runtimeType.toString() : r.toString());

  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is PageRoute) {
      LogService.instance.logNavigation(
        action: 'push',
        from: previousRoute is PageRoute ? _routeName(previousRoute) : null,
        to: _routeName(route),
      );
      LogService.instance.logScreenEnter(
        _routeName(route),
        route: _routeName(route),
      );
    }
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    if (route is PageRoute) {
      // Al hacer pop, la pantalla "actual" pasa a ser previousRoute
      LogService.instance.logNavigation(
        action: 'pop',
        from: _routeName(route),
        to: previousRoute is PageRoute ? _routeName(previousRoute) : null,
      );
      LogService.instance.logScreenExit(
        _routeName(route),
        route: _routeName(route),
      );
      if (previousRoute is PageRoute) {
        LogService.instance.logScreenEnter(
          _routeName(previousRoute),
          route: _routeName(previousRoute),
        );
      }
    }
    super.didPop(route, previousRoute);
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    if (newRoute is PageRoute) {
      LogService.instance.logNavigation(
        action: 'replace',
        from: oldRoute is PageRoute ? _routeName(oldRoute) : null,
        to: _routeName(newRoute),
      );
      if (oldRoute is PageRoute) {
        LogService.instance.logScreenExit(
          _routeName(oldRoute),
          route: _routeName(oldRoute),
        );
      }
      LogService.instance.logScreenEnter(
        _routeName(newRoute),
        route: _routeName(newRoute),
      );
    }
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}
