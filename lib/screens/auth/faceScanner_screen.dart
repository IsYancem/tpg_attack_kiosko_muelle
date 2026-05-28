import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/models/facial/facial_request_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/websockets/websocket_models.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/error_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/transactions/incoming/TRLIncoming_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/transactions/incoming/dspCsIncoming_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/transactions/incoming/dspIncoming_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/transactions/incoming/exmIncoming_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/transactions/incoming/expIncoming_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/transactions/incoming/resIncoming_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/facial_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/confirm_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/scale_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/face_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyFace/atkBodyBar_face.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyFace/atkSubheaderBar_face.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyRfid/atkHeaderBar_rfid.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/atkFooterBar_common.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/processing_widget.dart';

class FaceScannerScreen extends StatefulWidget {
  const FaceScannerScreen({super.key});

  @override
  State<FaceScannerScreen> createState() => _FaceScreenState();
}

class _FaceScreenState extends State<FaceScannerScreen> {
  FaceService? _face;
  ScaleService? _scale;
  StreamSubscription<EmployeeResponse>? _employeeSub;
  StreamSubscription<WeightResponse>? _weightSub;
  bool _validating = false;
  bool _navigating = false;

  // ✅ Cache de managers para evitar lookups repetidos
  late AppStateManager _appManager;
  late AtkTransactionManager _manager;

  // ✅ Servicios pre-instanciados (reutilizables)
  final FacialService _facialSvc = FacialService();
  final ConfirmService _confirmSvc = ConfirmService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ✅ Cache de managers inmediato
      _appManager = context.read<AppStateManager>();
      _manager = context.read<AtkTransactionManager>();

      // ✅ Log sin await (fire-and-forget)
      LogService.instance.logScreenEnter(
        'FaceScannerScreen',
        route: ModalRoute.of(context)?.settings.name,
      );

      _faceScreenLoad();
    });
  }

  Future<void> _faceScreenLoad() async {
    // ✅ Iniciar ambos monitores en paralelo
    await Future.wait([_startScaleMonitor(), _startFaceMonitor()]);
  }

  Future<void> _startScaleMonitor() async {
    try {
      final scaleUrl = _appManager.kioskConfig?.weightService;
      if (scaleUrl == null || scaleUrl.isEmpty) return;

      _scale = ScaleService(
        url: scaleUrl,
        onStatus: (_) {}, // ✅ Sin log innecesario
      );

      _weightSub = _scale!.weight$.listen((response) {
        if (response.isSuccess && response.record != null) {
          // ✅ Actualizar peso SIN notifyListeners excesivos
          _manager.pesoActualBascula = response.record!.weight;
        }
      });

      await _scale!.connect(scaleUrl);
    } catch (e) {
      // ✅ Log fire-and-forget
      LogService.instance.logError('SCALE_CONNECT_EX', e);
    }
  }

  Future<void> _startFaceMonitor() async {
    try {
      final faceUrl =
          _appManager.kioskConfig?.faceService ??
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

  /// ✅ OPTIMIZADO: Maneja detección de empleado
  void _onEmployeeDetected(EmployeeResponse response) {
    if (!mounted || _validating || _navigating) return;
    if (!response.isSuccess || response.record == null) return;

    _validating = true;
    final sw = Stopwatch()..start();

    final employee = response.record!;

    _manager.setMany({
      'isLoading': true,
      'mensajeInferior':
          'Validando reconocimiento facial...\nPor favor espere.',
    });

    final placa = _manager.vehiculoPlaca ?? '';
    final req = FacialRequestModel(
      identification: employee.identificationNumber,
      numPlaca: placa,
      estado: 'P',
      kioskServer: _appManager.kioskConfig?.kioskServer,
      kioskPort: _appManager.kioskConfig?.kioskServerPort,
    );

    // ✅ Ejecutar en microtask para no bloquear UI
    Future.microtask(() => _executeValidation(req, sw));
  }

  /// ✅ OPTIMIZADO: Ejecuta validación facial + confirm
  Future<void> _executeValidation(FacialRequestModel req, Stopwatch sw) async {
    try {
      // ═══════════════════════════════════════════════════════════════
      // PASO 1: Validación facial
      // ═══════════════════════════════════════════════════════════════
      final facialRes = await _facialSvc.ejecutarFacial(req, _manager);

      if (_manager.hasError) {
        throw Exception(_manager.errorMessage ?? facialRes.message);
      }

      // ═══════════════════════════════════════════════════════════════
      // PASO 2: Confirmación
      // ═══════════════════════════════════════════════════════════════
      final confirmRes = await _confirmSvc.ejecutarConfirm(
        _manager,
        _appManager,
      );

      if (_manager.hasError) {
        throw Exception(_manager.errorMessage ?? confirmRes['message']);
      }

      if (!mounted) return;

      // ═══════════════════════════════════════════════════════════════
      // PASO 3: Extraer tipo de transacción y navegar
      // ═══════════════════════════════════════════════════════════════
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

      _manager.setManyWithoutNotify({
        'transactionType': tipoMov,
        'vehiculoTipoCarga': cargaSuelta,
        'atkId': atkId.isNotEmpty ? atkId : _manager.atkId,
        'tituloPantalla': title.isNotEmpty ? title : tipoMov,
        'isLoading': true,
        'mensajeInferior':
            'Procesando transacción $tipoMov...\nPor favor espere.',
      });

      _navigating = true;

      // ✅ Teardown en background (fire-and-forget)
      _teardownFaceStreams();

      if (!mounted) return;

      // ═══════════════════════════════════════════════════════════════
      // NAVEGACIÓN FLUIDA
      // ═══════════════════════════════════════════════════════════════
      _navigateToTransaction(tipoMov, cargaSuelta);
    } catch (e, st) {
      LogService.instance.logError('FACE_VALIDATION_ERROR', e, st);

      _navigating = true;
      _teardownFaceStreams();

      if (!mounted) return;

      // 🔥 EXTRAER MENSAJE DEL MANAGER SI EXISTE
      final errorMsg =
          _manager.errorMessage ?? (e is Exception ? e.toString() : '$e');

      // 🔥 LIMPIAR EL MENSAJE (remover prefijos)
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

  void _navigateToTransaction(String tipoMov, String cargaSuelta) {
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
      _manager.setMensajeInferior('Tipo de transacción no reconocido: $mov');
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

  String _normalizeTipoMov(dynamic raw) {
    final t = (raw ?? '').toString().trim().toUpperCase();

    // Si viene algo como "RES - Registro..." o "RES/XYZ", nos quedamos con el código
    final m = RegExp(r'^[A-Z]{3}').firstMatch(t);
    return m?.group(0) ?? t;
  }

  String _normalizeFlag(dynamic raw) {
    return (raw ?? '').toString().trim().toUpperCase();
  }

  /// ✅ Limpieza optimizada (sin await innecesarios)
  void _teardownFaceStreams() {
    _employeeSub?.cancel();
    _weightSub?.cancel();
    _employeeSub = null;
    _weightSub = null;

    _face?.dispose();
    _scale?.dispose();
    _face = null;
    _scale = null;
  }

  @override
  void dispose() {
    _teardownFaceStreams();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final hHeader = size.height * 0.15;
    final hSubHeader = size.height * 0.10;
    final hBody = size.height * 0.68;
    final hFooter = size.height * 0.07;

    final p = context.palette;

    // ✅ Usar Selector para solo observar isLoading
    return Selector<AtkTransactionManager, bool>(
      selector: (_, m) => m.isLoading,
      builder: (context, isLoading, _) {
        if (isLoading) {
          return Scaffold(
            backgroundColor: p.bg,
            body: Center(
              child: ProcessingWidget(
                key: const ValueKey('face_processing'),
                title: 'Procesando validación facial',
                subtitle: 'Por favor espere...',
                primaryColor: p.azulCorporativo,
                secondaryColor: p.azulCorporativo.withValues(alpha:0.6),
                size: size.shortestSide * 0.25,
              ),
            ),
          );
        }

        return Scaffold(
          body: Column(
            children: [
              AtkHeaderRfid(
                title: 'Reconocimiento Facial',
                height: hHeader,
                assetImagePath: 'assets/images/tpg_logo.png',
                onModeChanged: (isLight) => _appManager.setLight(isLight),
              ),
              AtkSubHeaderBarFace(height: hSubHeader),
              AtkBodyBarFace(height: hBody),
              AtkFooterBarCommon(
                height: hFooter,
                onModeChanged: (isLight) => _appManager.setLight(isLight),
              ),
            ],
          ),
        );
      },
    );
  }
}
