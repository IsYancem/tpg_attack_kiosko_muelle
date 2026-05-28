import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/face_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/mdwl_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/ocr_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/rfid_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/scale_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/status_log_bus.dart';

class ConnectivityManager {
  ConnectivityManager._();

  static final ConnectivityManager instance = ConnectivityManager._();

  MdwlService? _tosService;
  RfidService? _rfidService;
  ScaleService? _scaleService;
  FaceService? _faceService;
  OcrService? _ocrService;

  MdwlService get tosService => _tosService!;
  RfidService get rfidService => _rfidService!;
  ScaleService get scaleService => _scaleService!;
  FaceService get faceService => _faceService!;
  OcrService? get ocrService => _ocrService;

  bool _initialized = false;
  bool get isReady => _initialized;

  Future<void> init(AppStateManager appState, {bool force = false}) async {
    if (_initialized && !force) return;

    if (force && _initialized) {
      stopAll();
    }

    final cfg = appState.kioskConfig;

    if (cfg == null) {
      LogService.instance.logWarning('CONNECTIVITY_INIT_SKIP', {
        'reason': 'kioskConfig is null',
      });
      return;
    }

    _initialized = true;

    void onStatus(String label, bool connected) {
      LogService.instance.logRequest('CONNECTION_STATUS', {
        'service': label,
        'connected': connected,
      });
    }

    final isMuelle = appState.isMuelle;
    final ocrUrl = cfg.ocrService.trim();

    _tosService = MdwlService(onStatus: (b) => onStatus('TOS', b));

    _rfidService = RfidService(onStatus: (b) => onStatus('RFID', b));

    _faceService = FaceService(onStatus: (b) => onStatus('FACE', b));

    _scaleService = ScaleService(
      url: cfg.weightService,
      onStatus: (b) => onStatus('BASCULA', b),
    );

    _ocrService = null;

    if (isMuelle && ocrUrl.isNotEmpty) {
      _ocrService = OcrService(onStatus: (b) => onStatus('OCR', b));

      _ocrService!.connect(ocrUrl);
    } else {
      LogService.instance.logWarning('OCR_INIT_SKIPPED', {
        'isMuelle': isMuelle,
        'hasOcrUrl': ocrUrl.isNotEmpty,
      });
    }

    StatusLogBus.instance.addStatus('TOS', true);
    StatusLogBus.instance.addStatus('RFID', true);
    StatusLogBus.instance.addStatus('FACE', false);
    StatusLogBus.instance.addStatus('BASCULA', true);
    StatusLogBus.instance.addStatus('OCR', isMuelle && _ocrService != null);

    if (!isMuelle) {
      _rfidService!.connect(cfg.rfidService);
      await _faceService!.connect(cfg.faceService);
    }

    _scaleService!.start();

    LogService.instance.logRequest('ConnectivityManager', {
      'action': 'init_all_services',
      'isMuelle': isMuelle,
      'urls': {
        'rfid': cfg.rfidService,
        'face': cfg.faceService,
        'scale': cfg.weightService,
        'ocr': ocrUrl,
      },
    });
  }

  Future<void> ensureInitialized(AppStateManager appState) async {
    if (_initialized) return;

    if (appState.kioskConfig == null) {
      LogService.instance.logWarning('CONNECTIVITY_ENSURE_SKIP', {
        'reason': 'kioskConfig is null',
      });
      return;
    }

    await init(appState);
  }

  void stopAll() {
    try {
      _faceService?.dispose();
    } catch (_) {}

    try {
      _rfidService?.dispose();
    } catch (_) {}

    try {
      _scaleService?.dispose();
    } catch (_) {}

    try {
      _tosService?.dispose();
    } catch (_) {}

    try {
      _ocrService?.dispose();
    } catch (_) {}

    _tosService = null;
    _rfidService = null;
    _scaleService = null;
    _faceService = null;
    _ocrService = null;

    _initialized = false;
  }

  void dispose() {
    stopAll();
  }

  // Reconecta solo RFID sin destruir los otros servicios
  Future<RfidService> reinitRfid(AppStateManager appState) async {
    // Dispose solo el rfid anterior
    try {
      _rfidService?.dispose();
    } catch (_) {}
    _rfidService = null;

    void onStatus(String label, bool connected) {
      LogService.instance.logRequest('CONNECTION_STATUS', {
        'service': label,
        'connected': connected,
      });
    }

    _rfidService = RfidService(onStatus: (b) => onStatus('RFID', b));
    // NO conectar aquí — dejar que RfidScreen conecte DESPUÉS de suscribirse
    return _rfidService!;
  }

  Future<void> restart(AppStateManager appState) async {
    stopAll();
    await init(appState);
  }
}
