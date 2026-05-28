import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/models/facial/facial_request_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/websockets/websocket_models.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/ocrScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/error_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/transactions/incoming/TRLIncoming_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/muelle/descarga_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/transactions/incoming/dspCsIncoming_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/transactions/incoming/dspIncoming_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/transactions/incoming/exmIncoming_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/transactions/incoming/expIncoming_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/transactions/incoming/resIncoming_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/confirm_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/facial_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/face_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/scale_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/format/fecha_utils.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyFace/atkBodyBar_face.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyFace/atkSubheaderBar_face.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyRfid/atkHeaderBar_rfid.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/atkFooterBar_common.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/processing_widget.dart';

/// Tiempo máximo de espera facial antes de volver a la pantalla OCR.
/// Configurable vía .env: FACE_TIMEOUT_SECONDS (default 60).
const _kDefaultFaceTimeoutSeconds = 60;

class MuelleTransactionScreen extends StatefulWidget {
  const MuelleTransactionScreen({super.key});

  @override
  State<MuelleTransactionScreen> createState() =>
      _MuelleTransactionScreenState();
}

class _MuelleTransactionScreenState extends State<MuelleTransactionScreen> {
  // -- Servicios WebSocket -----------------------------------------------------
  FaceService? _face;
  ScaleService? _scale;

  // -- Subscripciones ----------------------------------------------------------
  StreamSubscription<EmployeeResponse>? _employeeSub;
  StreamSubscription<WeightResponse>? _weightSub;

  // -- Timer de timeout facial -------------------------------------------------
  Timer? _faceTimeoutTimer;

  // -- Flags de control de flujo -----------------------------------------------
  bool _validating = false;
  bool _navigating = false;

  // -- Managers ----------------------------------------------------------------
  AppStateManager? _appManager;
  AtkTransactionManager? _manager;

  // -- Servicios API -----------------------------------------------------------
  final FacialService _facialSvc = FacialService();
  final ConfirmService _confirmSvc = ConfirmService();

  // -- Getters de estado -------------------------------------------------------

  /// true si el tipo de movimiento es DES (descarga de contenedor).
  bool get _isDescargaMuelle {
    final manager = _manager;
    if (manager == null) return false;
    return (manager.transactionType ?? '').trim().toUpperCase() == 'DES';
  }

  /// true si este flujo requiere identificación facial (PORTEO vacío o EXP).
  bool get _requiresFacialValidation {
    final manager = _manager;
    if (manager == null) return false;
    final mov = (manager.transactionType ?? '').trim().toUpperCase();
    return mov == 'PVO' || mov == 'EXP';
  }

  // -- Ciclo de vida -----------------------------------------------------------

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _appManager = context.read<AppStateManager>();
      _manager = context.read<AtkTransactionManager>();

      LogService.instance.logScreenEnter(
        'MuelleTransactionScreen',
        route: ModalRoute.of(context)?.settings.name,
      );

      _load();
    });
  }

  @override
  void dispose() {
    _cancelFaceTimeout();
    _teardownStreams();
    super.dispose();
  }

  // -- Carga principal ---------------------------------------------------------

  Future<void> _load() async {
    _markMuelleTransactionFromOcr();
    await _startScaleMonitor();

    if (_isDescargaMuelle) {
      _tryNavigateToDescargaIfReady();
      return;
    }

    // Solo arranca el monitor facial si este flujo lo requiere (PVO / EXP).
    // FIX: versión anterior tenía dos llamadas a _startFaceMonitor(); la segunda
    // siempre se ejecutaba sin el guard. Ahora hay una sola llamada condicional.
    if (_requiresFacialValidation) {
      await _startFaceMonitor();
      _startFaceTimeoutTimer(); // inicia cuenta regresiva de vuelta al OCR
    }

    if (mounted) setState(() {});
  }

  // -- Timeout -----------------------------------------------------------------

  void _startFaceTimeoutTimer() {
    _cancelFaceTimeout();

    final seconds =
        int.tryParse(dotenv.env['FACE_TIMEOUT_SECONDS'] ?? '') ??
        _kDefaultFaceTimeoutSeconds;

    LogService.instance.logRequest('FACE_TIMEOUT_START', {'seconds': seconds});

    _faceTimeoutTimer = Timer(Duration(seconds: seconds), _onFaceTimeout);
  }

  void _cancelFaceTimeout() {
    _faceTimeoutTimer?.cancel();
    _faceTimeoutTimer = null;
  }

  void _onFaceTimeout() {
    if (!mounted || _navigating || _validating) return;

    LogService.instance.logWarning('FACE_TIMEOUT_EXPIRED', {
      'transactionType': _manager?.transactionType,
    });

    _navigating = true;
    _teardownStreams();
    _manager?.resetAll();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const OcrScannerScreen(),
        transitionDuration: const Duration(milliseconds: 200),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  // -- Marcado de transacción desde OCR ----------------------------------------

  void _markMuelleTransactionFromOcr() {
    final manager = _manager;
    if (manager == null) return;

    final vehicleType = (manager.ocrVehicleType ?? '').trim().toLowerCase();
    final containers = (manager.ocrContainerNumbers ?? '').trim();

    final isTruckEmpty = vehicleType == 'truck_empty';
    final isTruckContainer = vehicleType == 'truck_container';

    String tipoMov;
    String titulo;

    if (isTruckEmpty) {
      tipoMov = 'PVO';
      titulo = 'Porteo vacío sin contenedor';
    } else if (isTruckContainer) {
      tipoMov = 'EXP';
      titulo = 'Exportación con contenedor';
    } else {
      tipoMov = 'DES';
      titulo = 'Descarga de contenedor';
    }

    manager.setManyWithoutNotify({
      'transactionType': tipoMov,
      'muelleTransactionCode': tipoMov,
      'muelleTransactionName': titulo,
      'muelleIsTruckEmpty': isTruckEmpty,
      'muelleRequiresContainer': !isTruckEmpty,
      'tituloPantalla': titulo,
      'contenedor': isTruckEmpty ? '' : containers,
      'ocrVehicleType': vehicleType,
      'ocrContainerNumbers': containers,
    });

    LogService.instance.logRequest('MUELLE_TRANSACTION_MARKED', {
      'vehicleType': vehicleType,
      'containers': containers,
      'tipoMov': tipoMov,
      'titulo': titulo,
      'requiresFacial': tipoMov == 'PVO' || tipoMov == 'EXP',
    });
  }

  // -- Descarga: navegación automática -----------------------------------------

  void _tryNavigateToDescargaIfReady() {
    final manager = _manager;
    if (manager == null) return;

    final contenedor = (manager.contenedor ?? '').trim().isNotEmpty
        ? manager.contenedor!.trim()
        : (manager.ocrContainerNumbers ?? '').trim();

    final peso = manager.pesoActualBascula;
    final tipoMov = (manager.transactionType ?? '').trim().toUpperCase();

    final canNavigate = tipoMov == 'DES' && contenedor.isNotEmpty && peso > 0;

    LogService.instance.logRequest('MUELLE_DES_NAV_VALIDATE', {
      'tipoMov': tipoMov,
      'contenedor': contenedor,
      'peso': peso,
      'canNavigate': canNavigate,
    });

    if (!canNavigate) return;

    _navigating = true;
    _teardownStreams();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const DescargaScreen(),
        transitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  // -- Monitores WebSocket -----------------------------------------------------

  Future<void> _startScaleMonitor() async {
    final appManager = _appManager;
    final manager = _manager;
    if (appManager == null || manager == null) return;

    try {
      final scaleUrl = appManager.kioskConfig?.weightService;
      if (scaleUrl == null || scaleUrl.isEmpty) return;

      _scale = ScaleService(url: scaleUrl, onStatus: (_) {});

      _weightSub = _scale!.weight$.listen((response) {
        if (response.isSuccess && response.record != null) {
          manager.pesoActualBascula = response.record!.weight;
          if (_isDescargaMuelle && mounted) setState(() {});
        }
      });

      await _scale!.connect(scaleUrl);
    } catch (e) {
      LogService.instance.logError('SCALE_CONNECT_EX', e);
    }
  }

  Future<void> _startFaceMonitor() async {
    final appManager = _appManager;
    if (appManager == null) return;

    try {
      final faceUrl =
          appManager.kioskConfig?.faceService ??
          dotenv.env['FACE_SERVICE'] ??
          '';

      if (faceUrl.isEmpty) return;

      _face = FaceService(onStatus: (_) {});

      _employeeSub = _face!.employeeDetected$.listen(
        _onEmployeeDetected,
        onError: (e) => LogService.instance.logError('FACE_STREAM', e),
      );

      await _face!.connect(faceUrl);
    } catch (e) {
      LogService.instance.logError('FACE_CONNECT_EX', e);
    }
  }

  // -- Detección facial --------------------------------------------------------
  void _onEmployeeDetected(EmployeeResponse response) {
    final manager = _manager;
    final appManager = _appManager;

    // -- LOG DE ENTRADA: confirma que el stream está emitiendo --------------
    // Si este log nunca aparece, el problema está en FaceService, no aquí.
    LogService.instance.logRequest('FACE_MSG_RECEIVED', {
      'code': response.code,
      'gate': response.gate,
      'sn': response.sn,
      'hasRecord': response.record != null,
      'identificationNumber': response.record?.identificationNumber ?? '',
      'isSuccess': response.isSuccess,
    });

    if (manager == null || appManager == null) return;
    if (!mounted || _validating || _navigating) return;

    // Guard 1: solo flujos que requieren facial (PVO / EXP)
    if (!_requiresFacialValidation) {
      LogService.instance.logWarning('FACE_MSG_SKIPPED_NO_FACIAL_REQUIRED', {});
      return;
    }

    // Guard 2: datos válidos
    if (!response.isSuccess || response.record == null) {
      LogService.instance.logWarning('FACE_MSG_SKIPPED_INVALID', {
        'code': response.code,
        'hasRecord': response.record != null,
      });
      return;
    }

    // Guard 3: filtro por dispositivo — SN tiene prioridad, gate como fallback.
    //
    // Lógica:
    //   • Si FACE_DEVICE_SN está configurado ? valida por SN.
    //   • Si no, y BASCULA está configurado ? valida por gate.
    //   • Si ninguno está configurado ? acepta cualquier dispositivo.
    final expectedSn =
        (appManager.faceDeviceSn.isNotEmpty
                ? appManager.faceDeviceSn
                : dotenv.env['FACE_DEVICE_SN'] ?? '')
            .trim()
            .toUpperCase();

    final expectedGateRaw = dotenv.env['BASCULA'] ?? '';
    final expectedGate = int.tryParse(expectedGateRaw.trim());

    final incomingSn = response.sn.trim().toUpperCase();
    final incomingGate = response.gate;

    if (expectedSn.isNotEmpty) {
      // Validación por SN: solo bloquea si el SN entrante también está presente
      // y no coincide. Si el mensaje no trae SN (incomingSn vacío) pasa igual.
      if (incomingSn.isNotEmpty && expectedSn != incomingSn) {
        LogService.instance.logWarning('FACE_SN_MISMATCH', {
          'expected': expectedSn,
          'incoming': incomingSn,
        });
        return;
      }
    } else if (expectedGate != null) {
      // Validación por gate cuando no hay SN configurado
      if (incomingGate != expectedGate) {
        LogService.instance.logWarning('FACE_GATE_MISMATCH', {
          'expected': expectedGate,
          'incoming': incomingGate,
        });
        return;
      }
    }

    // -- Detección válida ----------------------------------------------------
    LogService.instance.logRequest('FACE_EMPLOYEE_ACCEPTED', {
      'identificationNumber': response.record!.identificationNumber,
      'name': response.record!.name,
      'gate': incomingGate,
      'sn': incomingSn,
    });

    _cancelFaceTimeout();
    _validating = true;
    final sw = Stopwatch()..start();

    final employee = response.record!;

    manager.setManyWithoutNotify({
      'driverCedula': employee.identificationNumber,
      'driverName': employee.name,
      'driverProfile': employee.profile,
      'driverCompany': employee.company,
      'driverFaceUrl': employee.urlFace,
    });

    manager.setMany({
      'isLoading': true,
      'mensajeInferior':
          'Validando reconocimiento facial...\nPor favor espere.',
    });

    final placa = manager.vehiculoPlaca ?? '';

    final req = FacialRequestModel(
      identification: employee.identificationNumber,
      numPlaca: placa,
      estado: 'P',
      kioskServer: appManager.kioskConfig?.kioskServer,
      kioskPort: appManager.kioskConfig?.kioskServerPort,
    );

    Future.microtask(() => _executeValidation(req, sw));
  }

  // -- Validación API ----------------------------------------------------------

  Future<void> _executeValidation(FacialRequestModel req, Stopwatch sw) async {
    final manager = _manager;
    final appManager = _appManager;

    if (manager == null || appManager == null) return;

    try {
      final facialRes = await _facialSvc.ejecutarFacial(req, manager);

      if (manager.hasError) {
        throw Exception(manager.errorMessage ?? facialRes.message);
      }

      final confirmRes = await _confirmSvc.ejecutarConfirm(manager, appManager);

      if (manager.hasError) {
        throw Exception(manager.errorMessage ?? confirmRes['message']);
      }

      if (!mounted) return;

      final cola =
          confirmRes['data']?['services']?['getCola']?['data']
              as Map<String, dynamic>?;

      final tipoMov = _normalizeTipoMov(cola?['tipo_mov']);
      final cargaSuelta = _normalizeFlag(cola?['carga_suelta']);
      final atkId = (cola?['atk_id'] ?? '').toString().trim();

      final catalogo =
          confirmRes['data']?['services']?['catalogoTitulo']?['data']
              as Map<String, dynamic>?;

      final title = (catalogo?['title'] ?? '').toString().trim();

      manager.setManyWithoutNotify({
        'transactionType': tipoMov,
        'vehiculoTipoCarga': cargaSuelta,
        'atkId': atkId.isNotEmpty ? atkId : manager.atkId,
        'tituloPantalla': title.isNotEmpty ? title : tipoMov,
        'isLoading': true,
        'mensajeInferior':
            'Procesando transacción $tipoMov...\nPor favor espere.',
      });

      _navigating = true;
      _teardownStreams();

      if (!mounted) return;

      _navigateToTransaction(tipoMov, cargaSuelta);
    } catch (e, st) {
      LogService.instance.logError('FACE_VALIDATION_ERROR', e, st);

      _navigating = true;
      _teardownStreams();

      if (!mounted) return;

      final errorMsg =
          manager.errorMessage ?? (e is Exception ? e.toString() : '$e');

      final cleanError = errorMsg
          .replaceAll('Exception: ', '')
          .replaceAll('Error::', '')
          .replaceAll('Error:', '')
          .trim();

      _navigateToError(cleanError);
    } finally {
      _validating = false;
    }
  }

  // -- Navegación --------------------------------------------------------------

  void _navigateToTransaction(String tipoMov, String cargaSuelta) {
    final manager = _manager;
    if (manager == null) return;

    final mov = _normalizeTipoMov(tipoMov);
    final carga = _normalizeFlag(cargaSuelta);

    Widget targetScreen;

    if (mov == 'DSP') {
      targetScreen = carga == 'N'
          ? const DspIncomingScreen()
          : const DspCsIncomingScreen();
    } else if (mov == 'TRL') {
      targetScreen = const TrlIncomingScreen();
    } else if (mov == 'EXP') {
      targetScreen = const ExpIncomingScreen();
    } else if (mov == 'EXM' || mov == 'XMD') {
      targetScreen = const ExmIncomingScreen();
    } else if (mov == 'RES') {
      targetScreen = const ResIncomingScreen();
    } else {
      LogService.instance.logWarning('MUELLE_UNKNOWN_MOV', {'tipoMov': mov});
      manager.setMensajeInferior('Tipo de transacción no reconocido: $mov');
      _validating = false;
      _navigating = false;
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => targetScreen,
        transitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  void _navigateToError(String error) {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ErrorScreen(error: error),
        transitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  // -- Helpers -----------------------------------------------------------------

  String _normalizeTipoMov(dynamic raw) {
    final t = (raw ?? '').toString().trim().toUpperCase();
    final m = RegExp(r'^[A-Z]{3}').firstMatch(t);
    return m?.group(0) ?? t;
  }

  String _normalizeFlag(dynamic raw) {
    return (raw ?? '').toString().trim().toUpperCase();
  }

  void _teardownStreams() {
    _cancelFaceTimeout();

    _employeeSub?.cancel();
    _weightSub?.cancel();

    _employeeSub = null;
    _weightSub = null;

    _face?.dispose();
    _scale?.dispose();

    _face = null;
    _scale = null;
  }

  // -- Build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final appManager = _appManager;
    final manager = _manager;

    if (appManager == null || manager == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final size = MediaQuery.sizeOf(context);
    final hHeader = size.height * 0.15;
    final hSubHeader = size.height * 0.10;
    final hBody = size.height * 0.68;
    final hFooter = size.height * 0.07;
    final p = context.palette;

    return Selector<AtkTransactionManager, bool>(
      selector: (_, m) => m.isLoading,
      builder: (context, isLoading, _) {
        if (isLoading) {
          return Scaffold(
            backgroundColor: p.bg,
            body: Center(
              child: ProcessingWidget(
                key: const ValueKey('muelle_processing'),
                title: 'Procesando validación facial Muelle',
                subtitle: 'Por favor espere...',
                primaryColor: p.azulCorporativo,
                secondaryColor: p.azulCorporativo.withValues(alpha: 0.6),
                size: size.shortestSide * 0.25,
              ),
            ),
          );
        }

        if (_isDescargaMuelle) {
          return Scaffold(
            body: Column(
              children: [
                AtkHeaderRfid(
                  title: 'Preparando transacción de descarga',
                  height: hHeader,
                  assetImagePath: 'assets/images/tpg_logo.png',
                  onModeChanged: (isLight) => appManager.setLight(isLight),
                ),
                _MuelleDescargaSubHeader(height: hSubHeader),
                _MuelleDescargaBody(height: hBody),
                AtkFooterBarCommon(
                  height: hFooter,
                  onModeChanged: (isLight) => appManager.setLight(isLight),
                ),
              ],
            ),
          );
        }

        // Pantalla de espera facial (PVO / EXP)
        return Scaffold(
          body: Column(
            children: [
              AtkHeaderRfid(
                title: 'Reconocimiento Facial Muelle',
                height: hHeader,
                assetImagePath: 'assets/images/tpg_logo.png',
                onModeChanged: (isLight) => appManager.setLight(isLight),
              ),
              AtkSubHeaderBarFace(height: hSubHeader),
              AtkBodyBarFace(height: hBody),
              AtkFooterBarCommon(
                height: hFooter,
                onModeChanged: (isLight) => appManager.setLight(isLight),
              ),
            ],
          ),
        );
      },
    );
  }
}

// -- Widgets privados ----------------------------------------------------------

class _MuelleDescargaSubHeader extends StatefulWidget {
  final double height;
  const _MuelleDescargaSubHeader({required this.height});

  @override
  State<_MuelleDescargaSubHeader> createState() =>
      _MuelleDescargaSubHeaderState();
}

class _MuelleDescargaSubHeaderState extends State<_MuelleDescargaSubHeader> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const base = 100.0;
    final s = (widget.height / base).clamp(0.6, 2.0);

    return SizedBox(
      height: widget.height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32 * s),
        child: Row(
          children: [
            Text(
              'Preparando transacción de descarga',
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 34 * s,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            const Expanded(child: SizedBox.shrink()),
            Text(
              _now.toFechaLargaEs(),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 22 * s,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MuelleDescargaBody extends StatelessWidget {
  final double height;
  const _MuelleDescargaBody({required this.height});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AtkTransactionManager>();
    final p = context.palette;
    final s = (height / 680.0).clamp(0.6, 1.6);

    final contenedor = manager.contenedor?.trim().isNotEmpty == true
        ? manager.contenedor!.trim()
        : (manager.ocrContainerNumbers ?? '').trim();

    final peso = manager.pesoActualBascula;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32 * s, vertical: 20 * s),
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/container.gif',
                  height: height * 0.80,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'DESCARGA',
                    style: TextStyle(
                      color: p.azulCorporativo,
                      fontSize: 42 * s,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 26 * s),
                  Text(
                    'Contenedor',
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: 22 * s,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8 * s),
                  Text(
                    contenedor.isNotEmpty ? contenedor : '---',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 52 * s,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  SizedBox(height: 34 * s),
                  Text(
                    '${peso.toStringAsFixed(0)} kg',
                    style: TextStyle(
                      color: peso > 0 ? Colors.green[800] : Colors.orange[800],
                      fontSize: 56 * s,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
