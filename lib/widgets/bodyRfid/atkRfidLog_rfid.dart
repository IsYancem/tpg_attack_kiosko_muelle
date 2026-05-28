import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tpg_attack_kiosko_muelle/models/websockets/websocket_models.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/ocr_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/rfid_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/status_log_bus.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

class AtkRfidLogPanel extends StatefulWidget {
  final double height;
  final RfidService service;

  /// ✅ Ahora opcional (solo MUELLE)
  final OcrService? ocrService;

  final int maxItems;
  final EdgeInsetsGeometry padding;

  const AtkRfidLogPanel({
    super.key,
    required this.height,
    required this.service,
    this.ocrService,
    this.maxItems = 3,
    this.padding = const EdgeInsets.symmetric(horizontal: 12),
  });

  @override
  State<AtkRfidLogPanel> createState() => _AtkRfidLogPanelState();
}

class _AtkRfidLogPanelState extends State<AtkRfidLogPanel> {
  final ListQueue<_LogItem> _items = ListQueue();

  late final StreamSubscription<String> _busSub;
  late final StreamSubscription<VehicleResponse> _vehicleSub;

  /// ✅ Ya no late: puede no existir si no hay OCR
  StreamSubscription<OcrEvent>? _ocrSub;

  @override
  void initState() {
    super.initState();

    final isMuelle =
        (dotenv.env['MUELLE'] ?? '').trim().toUpperCase() == 'TRUE';

    // 1️⃣ BUS GENERAL (estados)
    _busSub = StatusLogBus.instance.stream.listen((line) {
      if (!mounted) return;

      // ⚠️ OCR ya no se procesa aquí
      if (line.startsWith('[OCR]')) return;

      final ts = DateTime.now();
      final parsed = _Parsed.fromRaw(line);

      setState(() {
        _items.addFirst(_LogItem(ts: ts, raw: line, parsed: parsed));
        while (_items.length > widget.maxItems) _items.removeLast();
      });
    });

    // 2️⃣ RFID
    _vehicleSub = widget.service.vehicleDetected$.listen((response) {
      if (!mounted) return;

      final ts = DateTime.now();
      String msg;

      if (response.isSuccess && response.record != null) {
        final v = response.record!;
        msg = '🚗 Vehículo: ${v.regNumber} • ${v.company}';
        if (v.state == 0 && v.message.isNotEmpty) {
          msg += ' ⚠️ ${v.message}';
        }
      } else {
        msg = '❌ Error RFID: ${response.message}';
      }

      final parsed = _Parsed.fromRaw(msg);
      setState(() {
        _items.addFirst(_LogItem(ts: ts, raw: msg, parsed: parsed));
        while (_items.length > widget.maxItems) _items.removeLast();
      });
    });

    // 3️⃣ OCR (solo MUELLE + solo si viene el servicio)
    if (isMuelle && widget.ocrService != null) {
      _ocrSub = widget.ocrService!.ocrEvent$.listen((event) {
        if (!mounted) return;

        final ts = DateTime.now();

        final containerNumbers = event.containers
            .map((c) => c['containerNumber']?.toString() ?? '')
            .where((c) => c.isNotEmpty)
            .join(' / ');

        final msg = containerNumbers.isNotEmpty
            ? '📦 OCR: $containerNumbers'
            : '🚛 OCR: Vehículo vacío detectado';

        final parsed = _Parsed(
          type: _LogType.success,
          source: 'OCR',
          jsonData: null,
          messageKind: _JMessageKind.none,
          isUp: false,
          isDown: false,
          extraDetail: msg,
        );

        setState(() {
          _items.addFirst(_LogItem(ts: ts, raw: msg, parsed: parsed));
          while (_items.length > widget.maxItems) _items.removeLast();
        });
      });
    }
  }

  @override
  void dispose() {
    _busSub.cancel();
    _vehicleSub.cancel();
    _ocrSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final h = widget.height;
    final s = (h / 220).clamp(0.8, 2.0);

    return Padding(
      padding: widget.padding,
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha:0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.surfaceBorder),
        ),
        padding: EdgeInsets.all(12 * s),
        child: _items.isEmpty
            ? _EmptyState(scale: s)
            : ListView.separated(
                reverse: true,
                itemCount: _items.length,
                separatorBuilder: (_, __) => SizedBox(height: 5 * s),
                itemBuilder: (_, i) =>
                    _LogCard(item: _items.elementAt(i), scale: s),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final double scale;
  const _EmptyState({required this.scale});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Center(
      child: Opacity(
        opacity: 0.8,
        child: Text(
          'Sin datos aún…',
          style: TextStyle(
            color: p.textSecondary,
            fontSize: 16 * scale,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  final _LogItem item;
  final double scale;
  const _LogCard({required this.item, required this.scale});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final parsed = item.parsed;

    final displayTime = parsed.timestamp ?? item.ts;
    final time =
        '${displayTime.hour.toString().padLeft(2, '0')}:'
        '${displayTime.minute.toString().padLeft(2, '0')}:'
        '${displayTime.second.toString().padLeft(2, '0')}';

    final meta = _visualMetaFor(parsed.type, p);

    String? secondaryText;

    if (parsed.source == 'KIOSK' && parsed.extraDetail != null) {
      secondaryText = parsed.extraDetail;
    } else {
      final j = parsed.jsonData;
      if (j != null) {
        if (parsed.messageKind == _JMessageKind.vehiculo) {
          secondaryText =
              '🚗 Vehículo detectado: ${j["regnumber"]} • ${j["msg"]}';
        } else if (parsed.messageKind == _JMessageKind.relay) {
          secondaryText = '${j["msg"]} • Relay: ${j["relay"]}';
        }
      }
      secondaryText ??= parsed.extraDetail;
    }

    final cardH = 50 * scale;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.surfaceBorder),
      ),
      padding: EdgeInsets.all(4 * scale),
      child: SizedBox(
        height: cardH,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(meta.icon, color: meta.color, size: 18 * scale),
                SizedBox(width: 6 * scale),
                Expanded(
                  child: Text(
                    '$time • ${parsed.source} • ${meta.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: meta.color,
                      fontSize: 12.5 * scale,
                    ),
                  ),
                ),
              ],
            ),
            if (secondaryText != null) ...[
              SizedBox(height: 6 * scale),
              Text(
                secondaryText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5 * scale,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/* ───────────────────────────
 *   Parsing / Clasificación
 * ─────────────────────────── */

enum _LogType { success, warning, error, json, handshake, info }

enum _JMessageKind { none, vehiculo, relay }

class _Parsed {
  final _LogType type;
  final String source;
  final Map<String, dynamic>? jsonData;
  final _JMessageKind messageKind;

  final bool isUp;
  final bool isDown;
  final String? extraDetail;

  final DateTime? timestamp;
  final String? logLevel;
  final String? kioskAction;
  final String? kioskMessage;

  _Parsed({
    required this.type,
    required this.source,
    required this.jsonData,
    required this.messageKind,
    required this.isUp,
    required this.isDown,
    required this.extraDetail,
    this.timestamp,
    this.logLevel,
    this.kioskAction,
    this.kioskMessage,
  });

  factory _Parsed.fromRaw(String raw) {
    final text = raw.trim();

    // ✅ OCR PRIORIDAD por formato real del bus
    if (text.startsWith('[OCR]')) {
      return _parseOcrLog(text);
    }

    // Logs del server (si aplican)
    final kioskMatch = _parseKioskServerLog(text);
    if (kioskMatch != null) {
      return kioskMatch;
    }

    // Intento genérico de JSON embebido
    Map<String, dynamic>? j;
    _JMessageKind k = _JMessageKind.none;
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end > start) {
      final jsonStr = text.substring(start, end + 1);
      try {
        j = json.decode(jsonStr) as Map<String, dynamic>;
        if (j.containsKey('regnumber') && j.containsKey('msg')) {
          k = _JMessageKind.vehiculo;
        } else if (j.containsKey('msg') && j.containsKey('relay')) {
          k = _JMessageKind.relay;
        }
      } catch (_) {
        j = null;
      }
    }

    final s = _guessSource(text);
    final t = _classify(text, hasJson: j != null);

    final lower = text.toLowerCase();
    final up = lower.contains('✅') || lower.contains(' up');
    final down = lower.contains('❌') || lower.contains(' down');

    // ═══════════════════════════════════════════════════════════════
    // ✅ RFID: Extraer detalle después de [RFID]
    // ═══════════════════════════════════════════════════════════════
    if (s == 'RFID') {
      final detail = _extractDetailAfterTag(text, 'RFID');
      return _Parsed(
        type: t,
        source: s,
        jsonData: null,
        messageKind: _JMessageKind.none,
        isUp: false,
        isDown: false,
        extraDetail: detail,
      );
    }

    // ═══════════════════════════════════════════════════════════════
    // ✅ BASCULA: Detectar log de peso
    // ═══════════════════════════════════════════════════════════════
    if (s == 'BASCULA' && text.contains('⚖️ Peso:')) {
      return _Parsed(
        type: _LogType.success,
        source: s,
        jsonData: null,
        messageKind: _JMessageKind.none,
        isUp: false,
        isDown: false,
        extraDetail: text,
      );
    }

    // ═══════════════════════════════════════════════════════════════
    // TOS: mantener tu lógica
    // ═══════════════════════════════════════════════════════════════
    if (s == 'TOS') {
      final sysDetail = _buildSysDetail(text, j);

      _LogType t2 = t;
      if (t == _LogType.info) {
        final seemsError =
            lower.contains('error') ||
            lower.contains('❌') ||
            lower.contains('exception') ||
            lower.contains('fail');
        final seemsWarn =
            lower.contains('warn') ||
            lower.contains('advertencia') ||
            lower.contains('pendiente') ||
            lower.contains('⚠');
        if (!seemsError && !seemsWarn) {
          t2 = _LogType.success;
        }
      }

      return _Parsed(
        type: t2,
        source: s,
        jsonData: j,
        messageKind: k,
        isUp: up,
        isDown: down,
        extraDetail: sysDetail,
      );
    }

    // Detalles de UP/DOWN para algunos servicios
    String? detail;
    if (s == 'TOS' || s == 'BASCULA' || s == 'FACE' || s == 'OCR') {
      if (up) detail = _detailForService(s, true);
      if (down) detail = _detailForService(s, false);
    }

    return _Parsed(
      type: t,
      source: s,
      jsonData: j,
      messageKind: k,
      isUp: up,
      isDown: down,
      extraDetail: detail,
    );
  }

  /// ✅ Parser OCR robusto (NO JSON): extrae container_number con RegExp.
  static _Parsed _parseOcrLog(String text) {
    debugPrint('🧪 [OCR] RAW TEXT');
    debugPrint(text);

    // Busca: "container_number: MSCU1234567"
    final match = RegExp(r'container_number:\s*([A-Z0-9]+)').firstMatch(text);
    if (match != null) {
      final container = match.group(1)!;
      debugPrint('✅ [OCR] CONTENEDOR DETECTADO: $container');

      return _Parsed(
        type: _LogType.success,
        source: 'OCR',
        jsonData: null,
        messageKind: _JMessageKind.none,
        isUp: false,
        isDown: false,
        extraDetail: '📦 Contenedor leído: $container',
      );
    }

    debugPrint('⚠️ [OCR] EVENTO OCR SIN CONTENEDOR');

    return _Parsed(
      type: _LogType.info,
      source: 'OCR',
      jsonData: null,
      messageKind: _JMessageKind.none,
      isUp: false,
      isDown: false,
      extraDetail: 'Evento OCR recibido',
    );
  }

  /// ✅ Extrae texto después de [TAG]
  /// Ej: "[RFID] ✅ Placa leída: GNP0701" → "✅ Placa leída: GNP0701"
  static String? _extractDetailAfterTag(String text, String tag) {
    final pattern = RegExp(r'\[' + tag + r'\]\s*(.+)', caseSensitive: false);
    final match = pattern.firstMatch(text);

    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }

    return null;
  }
}

_Parsed? _parseKioskServerLog(String text) {
  final kioskPattern = RegExp(
    r'\[(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} [+-]\d{2}:\d{2})\]\s+(\w+)\s+–\s+(KioskServer\.\w+)\s+-\s+Details:\s+(.+)',
    multiLine: true,
  );

  final match = kioskPattern.firstMatch(text);
  if (match == null) return null;

  final timestampStr = match.group(1)!;
  final logLevel = match.group(2)!;
  final detailsStr = match.group(4)!;

  DateTime? timestamp;
  try {
    timestamp = DateTime.parse(timestampStr.replaceAll(' ', 'T'));
  } catch (_) {
    timestamp = null;
  }

  Map<String, dynamic>? detailsJson;
  String? kioskAction;
  String? kioskMessage;
  _LogType logType = _LogType.info;

  try {
    detailsJson = json.decode(detailsStr) as Map<String, dynamic>;
    final payload = detailsJson['payload'] as Map<String, dynamic>?;

    if (payload != null) {
      kioskAction = payload['Accion']?.toString();
      kioskMessage = payload['Message']?.toString();

      final hasError = payload['Error'] == true;
      if (hasError) {
        logType = _LogType.error;
      } else if (kioskAction == 'STA') {
        logType = _LogType.warning;
      } else {
        logType = _LogType.success;
      }
    }
  } catch (_) {
    kioskMessage = detailsStr;
    if (logLevel.toUpperCase() == 'ERROR') {
      logType = _LogType.error;
    } else if (logLevel.toUpperCase() == 'WARN') {
      logType = _LogType.warning;
    }
  }

  return _Parsed(
    type: logType,
    source: 'KIOSK',
    jsonData: detailsJson,
    messageKind: _JMessageKind.none,
    isUp: false,
    isDown: false,
    extraDetail: _buildKioskDetail(kioskAction, kioskMessage, logLevel),
    timestamp: timestamp,
    logLevel: logLevel,
    kioskAction: kioskAction,
    kioskMessage: kioskMessage,
  );
}

String? _buildKioskDetail(String? action, String? message, String logLevel) {
  if (action == null && message == null) return null;

  final parts = <String>[];

  if (action != null) {
    switch (action.toUpperCase()) {
      case 'STA':
        parts.add('📊 Estado reportado');
        break;
      case 'ENT':
        parts.add('🚪 Entrada registrada');
        break;
      case 'SAL':
        parts.add('🚪 Salida registrada');
        break;
      default:
        parts.add('⚙️ $action');
    }
  }

  if (message != null) {
    final shortMessage = message.length > 50
        ? '${message.substring(0, 47)}...'
        : message;
    parts.add(shortMessage);
  }

  return parts.join(' • ');
}

String _detailForService(String src, bool up) {
  switch (src) {
    case 'TOS':
      return up ? 'Tos conectado — canal WS estable.' : 'Tos sin conexión.';
    case 'BASCULA':
      return up
          ? 'Báscula operativa — lectura disponible.'
          : 'Báscula sin respuesta.';
    case 'FACE':
      return up
          ? 'Servicio de reconocimiento facial activo.'
          : 'Servicio facial desconectado.';
    default:
      return up ? 'Servicio activo.' : 'Servicio inactivo.';
  }
}

String? _summarizeJson(Map<String, dynamic> j) {
  final parts = <String>[];

  String? s(dynamic v) => v == null
      ? null
      : v.toString().trim().isEmpty
      ? null
      : v.toString().trim();

  final msg = s(j['msg']) ?? s(j['message']) ?? s(j['detail']) ?? s(j['error']);
  if (msg != null) parts.add(msg);

  final reg = s(j['regnumber']) ?? s(j['plate']) ?? s(j['placa']);
  if (reg != null) parts.add('Reg: $reg');

  final relay = s(j['relay']);
  if (relay != null) parts.add('Relay: $relay');

  final now = s(j['now']) ?? s(j['timestamp']) ?? s(j['time']);
  if (now != null) parts.add('Hora: $now');

  final code = s(j['code']);
  if (code != null && (msg == null)) parts.add('code=$code');

  if (parts.isEmpty) return null;
  return parts.join(' • ');
}

String _buildSysDetail(String raw, Map<String, dynamic>? maybeJson) {
  String _truncate(String s, int max) =>
      s.length <= max ? s : '${s.substring(0, max)}…';

  if (maybeJson != null) {
    final sum = _summarizeJson(maybeJson);
    final extraBL = () {
      final m = (maybeJson['msg'] ?? '').toString();
      final bl = RegExp(
        r'blacklist\s*:\s*(\d+)',
        caseSensitive: false,
      ).firstMatch(m);
      return bl != null ? ' • BlackList: ${bl.group(1)}' : '';
    }();
    if (sum != null) return '$sum$extraBL';
  }

  final stripped = raw
      .replaceAll(RegExp(r'^\s*\[[^\]]+\]\s*', caseSensitive: false), '')
      .trim();

  return stripped.isEmpty ? 'Evento del sistema' : _truncate(stripped, 120);
}

_LogType _classify(String t, {required bool hasJson}) {
  final lower = t.toLowerCase();

  if (t.startsWith('http/1.1') ||
      lower.contains('switching protocols') ||
      lower.contains('handshake')) {
    return _LogType.handshake;
  }
  if (lower.contains('error') ||
      lower.startsWith('error:') ||
      lower.contains('❌')) {
    return _LogType.error;
  }
  if (lower.contains('warn') ||
      lower.contains('advertencia') ||
      lower.contains('pendiente') ||
      lower.contains('⚠')) {
    return _LogType.warning;
  }
  if (hasJson) return _LogType.json;
  if (lower.contains('ok') ||
      lower.contains('éxito') ||
      lower.contains('aprobado') ||
      lower.contains('✅')) {
    return _LogType.success;
  }
  return _LogType.info;
}

String _guessSource(String t) {
  final lower = t.toLowerCase();

  if (lower.contains('[ocr]') || lower.contains('ocr_id')) return 'OCR';
  if (lower.contains('kioskserver')) return 'KIOSK';
  if (lower.contains('[tos]')) return 'TOS';
  if (lower.contains('[rfid]')) return 'RFID';
  if (lower.contains('[bascula]') || lower.contains('[scale]'))
    return 'BASCULA';
  if (lower.contains('[face]')) return 'FACE';
  return 'INFO';
}

class _VisualMeta {
  final IconData icon;
  final Color color;
  final String title;
  _VisualMeta(this.icon, this.color, this.title);
}

_VisualMeta _visualMetaFor(_LogType type, AppPalette p) {
  switch (type) {
    case _LogType.success:
      return _VisualMeta(Icons.check_circle, Colors.greenAccent, 'Éxito');
    case _LogType.warning:
      return _VisualMeta(Icons.warning, Colors.orangeAccent, 'Advertencia');
    case _LogType.error:
      return _VisualMeta(Icons.error, Colors.redAccent, 'Error');
    case _LogType.json:
      return _VisualMeta(Icons.data_object, Colors.lightBlueAccent, 'JSON');
    case _LogType.handshake:
      return _VisualMeta(Icons.sync_alt, Colors.blueGrey, 'Handshake');
    case _LogType.info:
      return _VisualMeta(Icons.info_outline, p.textSecondary, 'Info');
  }
}

class _LogItem {
  final DateTime ts;
  final String raw;
  final _Parsed parsed;

  _LogItem({required this.ts, required this.raw, required this.parsed});
}
