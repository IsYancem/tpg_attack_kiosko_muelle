// Autor: Abraham Yance
// Fecha: 2025-11-11
// Pie de página común con estado de servicios y modo de operación (modo kiosko)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/connectivity_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/face_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/mdwl_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/rfid_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/scale_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/atk_mode_toggle.dart';

mixin SafeState<T extends StatefulWidget> on State<T> {
  bool _disposed = false;
  void safeSetState(VoidCallback fn) {
    if (!_disposed && mounted) setState(fn);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AtkFooterBarCommon extends StatefulWidget {
  final double height;
  final ValueChanged<bool>? onModeChanged;

  const AtkFooterBarCommon({
    super.key,
    required this.height,
    this.onModeChanged,
  });

  @override
  State<AtkFooterBarCommon> createState() => _AtkFooterBarState();
}

class _AtkFooterBarState extends State<AtkFooterBarCommon> with SafeState {
  static const _systems = [
    'TOS',
    'RFID',
    'BASCULA',
    'FACE',
    'OCR',
    'SEMF',
    'HIGH',
    'SENSOR',
  ];

  late Map<String, bool> _statuses;

  MdwlService? _mdwlService;
  RfidService? _rfidService;
  ScaleService? _scaleService;
  FaceService? _faceService;

  @override
  void initState() {
    super.initState();
    _statuses = {for (final k in _systems) k: false};

    // -----------------------------
    // 1) MIDDLEWARE (TOS)
    // -----------------------------
    final middlewareUrl = dotenv.env['WS_MIDDLEWARE_URL'];
    if (middlewareUrl != null && middlewareUrl.isNotEmpty) {
      _mdwlService = MdwlService(onStatus: (ok) => _setStatus('TOS', ok));
      _mdwlService!.connect(middlewareUrl);
    }

    // -----------------------------
    // 2) Config del kiosko
    // -----------------------------
    final appStateManager = Provider.of<AppStateManager>(
      context,
      listen: false,
    );
    final cfg = appStateManager.kioskConfig;
    ConnectivityManager.instance.ensureInitialized(appStateManager);

    // -----------------------------
    // 3) RFID
    // -----------------------------
    final rfidUrl = cfg?.rfidService;
    if (rfidUrl != null && rfidUrl.isNotEmpty) {
      _rfidService = RfidService(onStatus: (ok) => _setStatus('RFID', ok));
      _rfidService!.isConnected$.listen((ok) => _setStatus('RFID', ok));
      _rfidService!.connect(rfidUrl);
    }

    // -----------------------------
    // 4) BASCULA
    // -----------------------------
    final scaleUrl = cfg?.weightService;
    if (scaleUrl != null && scaleUrl.isNotEmpty) {
      _scaleService = ScaleService(
        url: scaleUrl,
        onStatus: (ok) => _setStatus('BASCULA', ok),
      );
      _scaleService!.isConnected$.listen((ok) => _setStatus('BASCULA', ok));
      _scaleService!.start(); // importante
    }

    // -----------------------------
    // 5) FACE (NO EN MUELLE)
    // -----------------------------
    final isMuelle = appStateManager.isMuelle;

    if (!isMuelle) {
      final faceUrl = cfg?.faceService;
      if (faceUrl != null && faceUrl.isNotEmpty) {
        _faceService = FaceService(onStatus: (ok) => _setStatus('FACE', ok));
        _faceService!.isConnected$.listen((ok) => _setStatus('FACE', ok));
        _faceService!.connect(faceUrl);
      }
    } else {
      // En MUELLE no existe FACE → lo marcamos como OK o deshabilitado visualmente
      _setStatus('FACE', false);
    }

    // -----------------------------
    // 6) OCR (desde .env)
    // -----------------------------
    if (isMuelle) {
      final cm = ConnectivityManager.instance;
      final ocr = cm.ocrService;

      if (ocr != null) {
        ocr.isConnected$.listen((ok) {
          _setStatus('OCR', ok);
        });
      } else {
        _setStatus('OCR', false);

        LogService.instance.logWarning('FOOTER_OCR_SERVICE_NULL', {
          'reason':
              'Modo muelle activo, pero ConnectivityManager.ocrService es null',
          'hasKioskConfig': cfg != null,
          'ocrUrl': cfg?.ocrService ?? '',
        });
      }
    } else {
      _setStatus('OCR', false);
    }
  }

  @override
  void dispose() {
    _mdwlService?.dispose();
    _rfidService?.dispose();
    _scaleService?.dispose();
    _faceService?.dispose();
    super.dispose();
  }

  void _setStatus(String key, bool value) {
    if (_statuses[key] == value) return;
    safeSetState(() => _statuses[key] = value);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const base = 112.0;
    final s = (widget.height / base).clamp(0.6, 2.5);

    final isMuelle = context.read<AppStateManager>().isMuelle;

    return SizedBox(
      height: widget.height,
      child: Container(
        color: p.headerSubtitle.withValues(alpha: 0.12),
        padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 6 * s),
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Wrap(
                  spacing: 24 * s,
                  runSpacing: 18 * s,
                  children: [
                    for (final k in _systems)
                      if (
                      // ⛔ FACE no existe en muelle
                      !(isMuelle && k == 'FACE') &&
                          // ⛔ SENSOR solo existe en muelle
                          !(!isMuelle && k == 'SENSOR'))
                        _statusChip(context, k, _statuses[k] ?? false, s),
                  ],
                ),
              ),
            ),
            AtkModeToggle(onChanged: widget.onModeChanged ?? (_) {}, scale: s),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(
    BuildContext context,
    String label,
    bool ok,
    double scale,
  ) {
    final p = context.palette;
    const okColor = Color(0xFF22C55E);
    const failColor = Color(0xFFE53935);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 6 * scale,
      ),
      decoration: BoxDecoration(
        color: (ok ? okColor : failColor).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10 * scale),
        border: Border.all(
          color: (ok ? okColor : failColor).withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20 * scale,
            height: 20 * scale,
            decoration: BoxDecoration(
              color: ok ? okColor : failColor,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 8 * scale),
          Text(
            label,
            style: TextStyle(
              fontSize: 36 * scale,
              fontWeight: FontWeight.w600,
              color: ok ? p.textPrimary : failColor,
            ),
          ),
        ],
      ),
    );
  }
}
