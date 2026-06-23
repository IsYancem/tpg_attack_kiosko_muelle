import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/models/datos/consultar_placa_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/datos/consultar_transaccion_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/websockets/websocket_models.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/error_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/muelle/descarga_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/muelle/expDoble_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/muelle/expRepesaje_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/muelle/psc_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/confirm_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/datosApi_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/ocr_api_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/connectivity_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/ocr_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/rfid_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/scale_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/status_log_bus.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyOcr/atkBodyBar_ocr.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyOcr/atkSubheaderBar_ocr.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyRfid/atkHeaderBar_rfid.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/atkFooterBar_common.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/processing_widget.dart';

class OcrScannerScreen extends StatefulWidget {
  const OcrScannerScreen({super.key});

  @override
  State<OcrScannerScreen> createState() => _OcrScannerScreenState();
}

void _dbg(String tag, [Map<String, dynamic>? data]) {
  final ts = DateTime.now().toIso8601String();
  final payload = data == null ? '' : ' | $data';
  // ignore: avoid_print
  print('?? [OCR_FLOW][$ts] $tag$payload');
}

class _OcrScannerScreenState extends State<OcrScannerScreen> {
  ScaleService? _scale;
  OcrService? _ocrService;
  RfidService? _rfid;

  StreamSubscription<WeightResponse>? _weightSub;
  StreamSubscription<OcrEvent>? _ocrSub;
  StreamSubscription<VehicleResponse>? _vehicleSub;
  StreamSubscription<bool>? _connSub;

  // Solo DatosApiService — el confirm lo ejecuta cada runner.
  final DatosApiService _datosApiService = DatosApiService();
  final ConfirmService _confirmService = ConfirmService();
  final OcrApiService _ocrApiService = OcrApiService();
  bool _ocrStatusUpdateSent = false;

  AppStateManager? _appManager;
  AtkTransactionManager? _manager;

  SensorStatus _ocrStatus = SensorStatus.idle;
  Timer? _ocrEmulationTimer;
  int _ocrCycles = 0;

  bool _ocrDetected = false;
  bool _weightDetected = false;
  bool _weightStable = false;

  bool _facialStarted = false;

  double _lastWeight = 0;
  Timer? _stableTimer;

  static const _stableDuration = Duration(seconds: 3);
  static const double _minValidWeight = 1.0;

  String? _placaSesion;
  int? _ultimoSideDetectado;

  String? _lastProcessedEventKey;
  DateTime? _lastProcessedAt;
  static const Duration _eventDedupWindow = Duration(seconds: 3);

  Timer? _placaTimeoutTimer;
  static const int _placaTimeoutSeconds = 120;

  bool _validating = false;
  bool _navigating = false;
  bool _consultandoConductor = false;
  bool _navigated = false;

  bool _consultandoTransaccionPlaca = false;

  String _routeTransactionCode = '';
  String _routeTransactionName = '';
  String _routeTargetScreen = '';

  @override
  void initState() {
    super.initState();
    _startOcrVisualCycle();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      _appManager = context.read<AppStateManager>();
      _manager = context.read<AtkTransactionManager>();

      _resetLocalScannerState();

      final authSnapshot = _manager?.authSnapshot ?? {};

      _manager?.resetAllWithDefaults({
        'isLoading': false,
        'hasError': false,
        'errorMessage': null,
        'transaccionActiva': false,
        'ocrFacialStarted': false,
        'ocrFacialOk': false,
        'mensajeInferior': null,
        'flowRemainingSeconds': null,

        ...authSnapshot,
      });

      LogService.instance.logRequest('OCR_SCREEN_ENTER_RESET', {
        'message': 'OCR anterior limpiado al entrar a pantalla',
      });

      await _initAllServices();
    });
  }

  void _resetLocalScannerState() {
    _ocrDetected = false;
    _weightDetected = false;
    _weightStable = false;
    _facialStarted = false;

    _lastWeight = 0;
    _ultimoSideDetectado = null;
    _placaSesion = null;

    _lastProcessedEventKey = null;
    _lastProcessedAt = null;

    _validating = false;
    _navigating = false;
    _consultandoConductor = false;
    _consultandoTransaccionPlaca = false;
    _navigated = false;

    _ocrStatusUpdateSent = false;

    _routeTransactionCode = '';
    _routeTransactionName = '';
    _routeTargetScreen = '';
  }

  void _runInBackground(Future<dynamic> future, String tag) {
    unawaited(
      future.catchError((error, stackTrace) async {
        LogService.instance.logError(tag, error, stackTrace);
      }),
    );
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // SERVICIOS
  // ---------------------------------------------------------------------------

  Future<void> _initAllServices() async {
    final appManager = _appManager;
    if (appManager == null) return;

    final cm = ConnectivityManager.instance;
    await cm.ensureInitialized(appManager);
    if (!mounted) return;

    _vehicleSub?.cancel();
    _connSub?.cancel();
    _vehicleSub = null;
    _connSub = null;

    _rfid?.dispose();
    _rfid = null;

    final rfidUrl = appManager.kioskConfig?.rfidService ?? '';

    if (rfidUrl.isEmpty) {
      LogService.instance.logWarning('OCR_RFID_CONNECT_SKIP', {
        'reason': 'rfidService vacío',
      });
    } else {
      _rfid = RfidService(onStatus: (_) {});
      _dbg('RFID_LOCAL_CREATED', {'hashCode': _rfid.hashCode, 'url': rfidUrl});

      _vehicleSub = _rfid!.vehicleDetected$.listen(_onVehicleDetected);
      _connSub = _rfid!.isConnected$.listen((ok) {
        LogService.instance.logRequest('RFID_CONNECTION', {'connected': ok});
      });

      _dbg('RFID_SUBSCRIBED', {'hashCode': _rfid.hashCode});
      await _rfid!.connect(rfidUrl);
    }

    _ocrService = cm.ocrService;
    _startOcrListener();

    await _startScaleMonitor();

    if (mounted) setState(() {});
  }

  void _startOcrListener() {
    if (_ocrService == null) {
      LogService.instance.logWarning('OCR_LISTENER_SKIP', {
        'reason': 'ocrService is null',
      });
      return;
    }

    _ocrSub?.cancel();
    _ocrSub = _ocrService!.ocrEvent$.listen(
      _onOcrReceived,
      onError: (error) {
        LogService.instance.logWarning('OCR_LISTENER_ERROR', {
          'error': error.toString(),
        });
      },
    );

    LogService.instance.logRequest('OCR_LISTENER_STARTED', {});
  }

  Future<void> _startScaleMonitor() async {
    final appManager = _appManager;
    final manager = _manager;
    if (appManager == null || manager == null) return;

    try {
      final scaleUrl = appManager.kioskConfig?.weightService;
      if (scaleUrl == null || scaleUrl.isEmpty) {
        LogService.instance.logWarning('SCALE_CONNECT_SKIP', {
          'reason': 'weightService is empty',
        });
        return;
      }

      _scale ??= ScaleService(url: scaleUrl, onStatus: (_) {});
      _weightSub?.cancel();

      _weightSub = _scale!.weight$.listen(
        (response) {
          if (!mounted || _navigated) return;
          if (!response.isSuccess || response.record == null) return;
          _onWeightReceived(response.record!.weight);
        },
        onError: (error) {
          LogService.instance.logWarning('SCALE_LISTENER_ERROR', {
            'error': error.toString(),
          });
        },
      );

      await _scale!.connect(scaleUrl);
    } catch (e, st) {
      LogService.instance.logError('SCALE_CONNECT_EX', e, st);
    }
  }

  // ---------------------------------------------------------------------------
  // OCR
  // ---------------------------------------------------------------------------

  void _onOcrReceived(OcrEvent event) {
    if (!mounted || _navigated) return;

    final manager = _manager;
    if (manager == null) return;

    final vehicleType = event.vehicleType.trim().toLowerCase();
    final isTruckEmpty = vehicleType == 'truck_empty';
    final isTruckContainer = vehicleType == 'truck_container';

    final containerNumbers = event.containers
        .map((e) => e['containerNumber']?.toString() ?? '')
        .where((e) => e.trim().isNotEmpty)
        .toList();

    final hasContainer = containerNumbers.isNotEmpty;

    if (!isTruckEmpty && !isTruckContainer) {
      LogService.instance.logWarning('OCR_EVENT_UNKNOWN_VEHICLE_TYPE', {
        'vehicleType': event.vehicleType,
      });
      return;
    }

    if (isTruckContainer && !hasContainer) {
      LogService.instance.logWarning('OCR_TRUCK_CONTAINER_WITHOUT_CONTAINER', {
        'vehicleType': event.vehicleType,
      });
      return;
    }

    _ocrDetected = true;
    manager.setIsTruckEmpty(isTruckEmpty);
    manager.setOcrFlowType(isTruckEmpty ? 'PORTEO_EMPTY' : 'DESCARGA');

    _markPreliminaryMuelleTransaction(
      manager: manager,
      vehicleType: vehicleType,
      containerNumbers: containerNumbers,
      isTruckEmpty: isTruckEmpty,
      isTruckContainer: isTruckContainer,
    );

    setState(() {
      _ocrStatus = _weightDetected
          ? SensorStatus.weightOk
          : SensorStatus.aligned;
    });

    LogService.instance.logRequest('OCR_FLOW_DETECTED', {
      'vehicleType': event.vehicleType,
      'containers': containerNumbers,
      'isTruckEmpty': isTruckEmpty,
    });

    _tryStartStableValidation();
  }

  void _markPreliminaryMuelleTransaction({
    required AtkTransactionManager manager,
    required String vehicleType,
    required List<String> containerNumbers,
    required bool isTruckEmpty,
    required bool isTruckContainer,
  }) {
    final containers = _normalizeOcrContainerNumbers(containerNumbers);
    final containersText = containers.join(' / ');
    final containerCount = containers.length;
    final tipoMov = isTruckEmpty ? 'PVO' : 'DESCARGA';
    final titulo = isTruckEmpty
        ? 'Porteo vacío sin contenedor'
        : containerCount > 1
        ? 'Descarga con $containerCount contenedores'
        : 'Descarga con contenedor';

    manager.setManyWithoutNotify({
      'transactionType': tipoMov,
      'muelleTransactionCode': tipoMov,
      'muelleTransactionName': titulo,
      'muelleIsTruckEmpty': isTruckEmpty,
      'muelleRequiresContainer': !isTruckEmpty,
      'muelleContainerCount': containerCount,
      'muelleIsDoubleContainer': containerCount > 1,
      'tituloPantalla': titulo,
      'contenedor': isTruckEmpty ? '' : containersText,
      'contenedor1': containers.isNotEmpty ? containers[0] : '',
      'contenedor2': containers.length > 1 ? containers[1] : '',
      'ocrVehicleType': vehicleType,
      'ocrContainerNumbers': containersText,
      'ocrContainerCount': containerCount,
      'ocrContainerValid': isTruckContainer && containerCount > 0,
      'ocrRouteBypass': true,
    });

    LogService.instance.logRequest('OCR_PRELIMINARY_TRANSACTION_MARKED', {
      'containers': containers,
      'tipoMov': tipoMov,
      'isTruckEmpty': isTruckEmpty,
    });
  }

  List<String> _normalizeOcrContainerNumbers(List<String> rawContainers) {
    final seen = <String>{};
    final result = <String>[];

    for (final raw in rawContainers) {
      final value = raw.trim().toUpperCase();
      if (value.isEmpty) continue;

      final isValidFormat = RegExp(r'^[A-Z]{4}\d{7}$').hasMatch(value);
      if (!isValidFormat) {
        LogService.instance.logWarning('OCR_CONTAINER_FORMAT_INVALID', {
          'container': value,
        });
        continue;
      }

      if (seen.add(value)) result.add(value);
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // BÁSCULA
  // ---------------------------------------------------------------------------

  void _onWeightReceived(double weight) {
    if (!mounted || _navigated) return;

    final manager = _manager;
    if (manager == null) return;

    manager.setPesoActualBascula(weight);

    final wasWeightDetected = _weightDetected;
    _weightDetected = weight >= _minValidWeight;

    if (_weightDetected && !wasWeightDetected) {
      setState(() {
        _ocrStatus = _ocrDetected
            ? SensorStatus.weightOk
            : SensorStatus.goodPosition;
      });
    }

    if (weight != _lastWeight) {
      _lastWeight = weight;
      _weightStable = false;
      _stableTimer?.cancel();

      LogService.instance.logRequest('WEIGHT_CHANGED', {
        'peso': weight,
        'stableIn': '${_stableDuration.inSeconds}s',
      });

      _tryStartStableValidation();
      return;
    }

    if (_ocrDetected && _weightDetected && _stableTimer == null) {
      _tryStartStableValidation();
    }
  }

  void _tryStartStableValidation() {
    if (!mounted || _navigated) return;
    if (!_ocrDetected || !_weightDetected) return;

    _stableTimer?.cancel();
    _stableTimer = Timer(_stableDuration, _onWeightStable);

    LogService.instance.logRequest('WEIGHT_STABLE_TIMER_STARTED', {
      'peso': _lastWeight,
      'seconds': _stableDuration.inSeconds,
    });
  }

  void _onWeightStable() {
    _stableTimer = null;

    if (!mounted || _navigated) return;
    if (!_ocrDetected || !_weightDetected || _lastWeight < _minValidWeight)
      return;

    _weightStable = true;

    LogService.instance.logRequest('OCR_AND_WEIGHT_STABLE_OK', {
      'pesoFinal': _lastWeight,
    });

    _tryProcessFlow(_ultimoSideDetectado);
  }

  // ---------------------------------------------------------------------------
  // RFID
  // ---------------------------------------------------------------------------

  bool _isDuplicateVehicleEvent(VehicleResponse response) {
    final record = response.record;
    if (record == null) return false;

    final key = '${response.gate}|${response.side}|${record.regNumber}';
    final now = DateTime.now();

    final isSameKey = _lastProcessedEventKey == key;
    final isInsideWindow =
        _lastProcessedAt != null &&
        now.difference(_lastProcessedAt!) <= _eventDedupWindow;

    if (isSameKey && isInsideWindow) return true;

    _lastProcessedEventKey = key;
    _lastProcessedAt = now;

    return false;
  }

  Future<void> _onVehicleDetected(VehicleResponse response) async {
    _dbg('EVT_START', {
      'mounted': mounted,
      'validating': _validating,
      'navigating': _navigating,
      'success': response.isSuccess,
      'gate': response.gate,
      'side': response.side,
    });

    try {
      if (!mounted) return;

      final manager = _manager;
      if (manager == null) return;

      if (!response.isSuccess || response.record == null) return;

      final vehicle = response.record!;
      final placa = vehicle.regNumber.trim().toUpperCase();

      if (placa.isEmpty) return;

      if ((_navigating || _validating || _consultandoConductor) &&
          _placaSesion == placa) {
        _dbg('EVT_SKIP', {'reason': 'flow_running_same_plate'});
        return;
      }

      if ((_navigating || _validating || _consultandoConductor) &&
          _placaSesion != placa) {
        _navigating = false;
        _validating = false;
        _consultandoConductor = false;
      }

      if (_placaSesion != placa) {
        _lastProcessedEventKey = null;
        _lastProcessedAt = null;
      }

      if (_isDuplicateVehicleEvent(response)) {
        _dbg('EVT_DUPLICATE_SKIP', {'placa': placa});
        return;
      }

      if (mounted) setState(() {});

      StatusLogBus.instance.addText('OCR_RFID', 'Placa detectada: $placa');

      _ultimoSideDetectado = response.side;

      manager.setManyWithoutNotify({
        'side': response.side,
        'doorNumber': response.side,
        'sideGate': response.side.toString(),
        'rfidGate': response.gate,
      });

      if (_placaSesion != placa) {
        _startNewVehicleSession(placa, vehicle, response.side, response.gate);
      }

      await _tryProcessFlow(_ultimoSideDetectado);
    } catch (e, st) {
      _dbg('EVT_FATAL_EXCEPTION', {'error': e.toString()});
      StatusLogBus.instance.addText('OCR_RFID', 'Handler error: $e');
      _navigating = false;
      _validating = false;
      _consultandoConductor = false;
      LogService.instance.logError('OCR_RFID_HANDLER_ERROR', e, st);
    }
  }

  void _startNewVehicleSession(
    String placa,
    VehicleRecord vehicle,
    int side,
    int gate,
  ) {
    final manager = _manager;
    if (manager == null) return;

    final ocrContenedor = manager.get('contenedor');
    final ocrContenedor1 = manager.get('contenedor1');
    final ocrContenedor2 = manager.get('contenedor2');
    final ocrContainerNumbers = manager.get('ocrContainerNumbers');
    final ocrContainerCount = manager.get('ocrContainerCount');
    final ocrVehicleType = manager.get('ocrVehicleType');
    final ocrContainerValid = manager.get('ocrContainerValid');
    final ocrRouteBypass = manager.get('ocrRouteBypass');

    _placaTimeoutTimer?.cancel();
    _placaSesion = null;
    _navigating = false;
    _validating = false;
    _consultandoConductor = false;
    _facialStarted = false;

    manager.resetDriver();
    manager.resetVehiculo();
    manager.resetImportador();
    // No usar resetContenedores aquí porque borra contenedor1 del OCR.
    manager.resetPesos();
    manager.clearError();
    manager.setTransaccionActiva(false);

    _placaSesion = placa;

    manager.setManyWithoutNotify({
      'vehiculoPlaca': placa,
      'vehiculoRfid': vehicle.rfid,
      'vehiculoEmpresa': vehicle.company,
      'vehiculoMarca': vehicle.brand,
      'vehiculoModelo': vehicle.model,
      'vehiculoColor': vehicle.color,
      'vehiculoEstado': vehicle.state.toString(),
      'vehiculoMensaje': vehicle.message,

      'side': side,
      'doorNumber': side,
      'sideGate': side.toString(),
      'rfidGate': gate,

      'contenedor': ocrContenedor,
      'contenedor1': ocrContenedor1,
      'contenedor2': ocrContenedor2,
      'ocrContainerNumbers': ocrContainerNumbers,
      'ocrContainerCount': ocrContainerCount,
      'ocrVehicleType': ocrVehicleType,
      'ocrContainerValid': ocrContainerValid,
      'ocrRouteBypass': ocrRouteBypass,

      'ocrFacialStarted': false,
      'ocrFacialOk': false,
    });

    setState(() {});

    _placaTimeoutTimer = Timer(
      const Duration(seconds: _placaTimeoutSeconds),
      _onPlacaTimeout,
    );

    LogService.instance.logRequest('RFID_SESSION_START', {
      'placa': placa,
      'side': side,
      'gate': gate,
      'contenedor1': ocrContenedor1,
      'ocrContainerNumbers': ocrContainerNumbers,
    });
  }

  void _onPlacaTimeout() {
    if (!mounted) return;

    final manager = _manager;
    if (manager == null) return;

    StatusLogBus.instance.addText(
      'OCR_RFID',
      'Tiempo agotado. Limpieza de sesión.',
    );
    LogService.instance.logWarning('RFID_SESSION_TIMEOUT', {
      'placa': _placaSesion,
    });

    _placaSesion = null;
    _ultimoSideDetectado = null;
    _navigating = false;
    _validating = false;
    _consultandoConductor = false;
    _weightStable = false;
    _facialStarted = false;

    manager.resetDriver();
    manager.resetVehiculo();
    manager.resetImportador();
    manager.resetContenedores();
    manager.resetPesos();
    manager.clearError();
    manager.setTransaccionActiva(false);

    manager.setManyWithoutNotify({
      'side': null,
      'doorNumber': null,
      'sideGate': null,
      'rfidGate': null,
      'ocrFacialStarted': false,
      'ocrFacialOk': false,
    });

    setState(() {});
  }

  // ---------------------------------------------------------------------------
  // FLUJO PRINCIPAL
  // ---------------------------------------------------------------------------

  Future<void> _tryProcessFlow(int? sideFromRfid) async {
    final manager = _manager;
    if (manager == null) return;

    if (!mounted ||
        _validating ||
        _navigating ||
        _navigated ||
        _consultandoConductor)
      return;
    if (_placaSesion == null || _placaSesion!.trim().isEmpty) return;
    if (!_ocrDetected) return;
    if (!_weightStable) return;
    if (manager.transaccionActiva) return;

    _consultandoConductor = true;
    _validating = true;
    _facialStarted = true;

    final placa = _placaSesion!.trim().toUpperCase();
    final sw = Stopwatch()..start();

    manager.setPesoActualBascula(_lastWeight);
    manager.set('vehiculoPlaca', placa);

    if (sideFromRfid != null && sideFromRfid > 0) {
      manager.setManyWithoutNotify({
        'side': sideFromRfid,
        'doorNumber': sideFromRfid,
        'sideGate': sideFromRfid.toString(),
      });
    }

    manager.setMany({
      'isLoading': true,
      'mensajeInferior':
          'Validando facial del conductor...\nConsultando conductor por placa.',
      'ocrFacialStarted': true,
      'ocrFacialOk': false,
    });

    try {
      // -- PASO 1: Conseguir conductor ------------------------------------------
      final conductorRes = await _datosApiService.conseguirYGuardarEnManager(
        placa: placa,
        manager: manager,
      );

      final chofer = conductorRes?.conductor?.chofer?.trim();

      if (!mounted) return;

      if (chofer == null || chofer.isEmpty) {
        final message =
            conductorRes?.conductor?.desError ??
            conductorRes?.services?.atkGetUltimoChoferPorPlaca?.message ??
            'No se encontró conductor para la placa $placa';

        _failAndNavigateToError(
          message: message,
          logTag: 'OCR_CONDUCTOR_NOT_FOUND_NAV_ERROR',
          extra: {'placa': placa},
        );
        return;
      }

      manager.setManyWithoutNotify({
        'driverCedula': chofer,
        'driverId': chofer,
        'isLoading': true,
        'mensajeInferior':
            'Conductor encontrado.\nValidando datos del conductor...',
        'ocrFacialStarted': true,
        'ocrFacialOk': false,
      });

      // -- PASO 2: Data completa del conductor ----------------------------------
      final dataConductorRes = await _datosApiService
          .conseguirDataYGuardarEnManager(ruc: chofer, manager: manager);

      final dataConductor = dataConductorRes?.conductor;

      if (!mounted) return;

      if (dataConductor == null || !dataConductor.isOk) {
        final message =
            dataConductor?.errorMsg ??
            dataConductorRes?.services?.atkGetDataPerson?.message ??
            'No se encontró data del conductor $chofer';

        _failAndNavigateToError(
          message: message,
          logTag: 'OCR_DATA_CONDUCTOR_NOT_FOUND_NAV_ERROR',
          extra: {
            'placa': placa,
            'chofer': chofer,
            'errorCode': dataConductor?.errorCode,
          },
        );
        return;
      }

      manager.setManyWithoutNotify({
        'isLoading': true,
        'mensajeInferior': 'Facial validado.\nData del conductor encontrada.',
        'ocrFacialStarted': true,
        'ocrFacialOk': true,
      });

      if (mounted) setState(() {});

      await _navigateAfterDataConductor(sw);
    } catch (e, st) {
      LogService.instance.logError('OCR_PROCESS_FLOW_ERROR', e, st);

      _validating = false;
      _consultandoConductor = false;
      _navigating = true;

      _teardown();

      if (!mounted) return;

      final errorMsg =
          manager.errorMessage ?? (e is Exception ? e.toString() : '$e');
      _navigateToError(_cleanError(errorMsg));
    }
  }

  Future<void> _navigateAfterDataConductor(Stopwatch sw) async {
    final manager = _manager;
    if (manager == null) return;

    try {
      final tipoMov = _normalizeTipoMov(manager.transactionType);
      final cargaSuelta = _normalizeFlag(manager.vehiculoTipoCarga);

      _runInBackground(
        LogService.instance.logRequest('OCR_DATA_CONDUCTOR_READY_NAVIGATE', {
          'elapsedMs': sw.elapsedMilliseconds,
          'tipoMov': tipoMov,
          'driverCedula': manager.driverCedula,
          'driverName': manager.driverName,
        }),
        'OCR_DATA_CONDUCTOR_READY_NAVIGATE_LOG_ERROR',
      );

      if (tipoMov.isEmpty) {
        throw Exception('No existe tipo de movimiento para navegar.');
      }

      manager.setManyWithoutNotify({
        'isLoading': true,
        'mensajeInferior':
            'Procesando transacción $tipoMov...\nPor favor espere.',
      });

      _navigating = true;
      _navigated = true;
      manager.setTransaccionActiva(true);

      _teardown();

      if (!mounted) return;

      await _navigateToTransaction(tipoMov, cargaSuelta);
    } catch (e, st) {
      LogService.instance.logError('OCR_DATA_CONDUCTOR_NAV_ERROR', e, st);

      _navigating = true;
      _teardown();

      if (!mounted) return;

      final errorMsg =
          manager.errorMessage ?? (e is Exception ? e.toString() : '$e');
      _navigateToError(_cleanError(errorMsg));
    } finally {
      _validating = false;
      _consultandoConductor = false;
    }
  }

  // ---------------------------------------------------------------------------
  // RESOLUCIÓN DE TIPO DE MOVIMIENTO
  // ---------------------------------------------------------------------------
  Future<String> _resolverTipoMovPorPlacaOcr({
    required String placa,
    required AtkTransactionManager manager,
  }) async {
    if (_consultandoTransaccionPlaca) {
      return _normalizeTipoMov(manager.transactionType);
    }

    _consultandoTransaccionPlaca = true;

    try {
      final side =
          _int(manager.get('side')) ?? _int(manager.get('doorNumber')) ?? 0;
      final kiosk = _appManager?.kioskConfig;

      final envPlaca = await _datosApiService.consultarPlacaMuelle(
        input: ConsultarPlacaRequest(
          garitaNumero: int.tryParse(kiosk?.gate ?? ''),
          garitaLetra: kiosk?.gateLetter,
          tpg: int.tryParse((kiosk?.patio ?? '').replaceAll('TPG', '')),
          usuarioNombre: dotenv.env['USERNAME'],
          permisoMuelle: 1,
          placa: placa,
        ),
      );

      if (envPlaca.errorCode != 0) {
        LogService.instance.logWarning('OCR_AUTO_CONSULTAR_PLACA_FAIL', {
          'placa': placa,
          'errorCode': envPlaca.errorCode,
        });
        return 'DESCARGA';
      }

      final envTxn = await _datosApiService.consultarTransaccionMuelle(
        input: ConsultarTransaccionRequest(
          garitaNumero: int.tryParse(kiosk?.gate ?? ''),
          garitaLetra: kiosk?.gateLetter,
          tpg: int.tryParse((kiosk?.patio ?? '').replaceAll('TPG', '')),
          usuarioNombre: dotenv.env['USERNAME'],
          permisoMuelle: '1',
          placa: placa,
          doorNumber: side,
          fecha_barrera: DateTime.now().toIso8601String(),
          brand: manager.vehiculoMarca,
          model: manager.vehiculoModelo,
          color: manager.vehiculoColor,
          companyId: null,
        ),
      );

      if (envTxn.errorCode != 0 || envTxn.data == null) {
        LogService.instance.logWarning('OCR_AUTO_CONSULTAR_TRANSACCION_FAIL', {
          'placa': placa,
          'errorCode': envTxn.errorCode,
        });
        return 'DESCARGA';
      }

      final data = envTxn.data!;
      final movements = data.movements;

      final expMovements = movements
          .where((m) => _normalizeTipoMov(m.tipoMov) == 'EXP')
          .toList();

      manager.setManyWithoutNotify({
        'ocrConsultarPlacaResponse': envPlaca.data?.toJson(),
        'ocrConsultarTransaccionResponse': data.toJson(),
        'ocrConsultarTransaccionMovements': movements
            .map((m) => m.toJson())
            .toList(),
        'ocrExpMovements': expMovements.map((m) => m.toJson()).toList(),
        'ocrExpMovementCount': expMovements.length,
      });

      if (expMovements.isEmpty) {
        LogService.instance.logWarning('OCR_AUTO_NO_EXP_MOVEMENTS', {
          'placa': placa,
          'totalMovements': movements.length,
        });
        return 'DESCARGA';
      }

      // ── CASO 1 MOVIMIENTO: flujo simple ───────────────────────────────────
      if (expMovements.length == 1) {
        final firstExp = expMovements.first;
        final firstExpJson = firstExp.toJson();
        final movVehicleAccessId = _extractVacIdFromMovement(firstExpJson);

        manager.setManyWithoutNotify({
          'transactionType': 'EXP',
          'muelleTransactionCode': 'EXP',
          'muelleTransactionName': 'Exportación Full',
          'ocrRouteDestination': 'EXP',
          'movement_active': firstExpJson,
          if (movVehicleAccessId > 0)
            'ocrDiSvVehicleAccessId': movVehicleAccessId.toString(),
          if (movVehicleAccessId > 0 &&
              (manager.atkId == null || manager.atkId!.isEmpty))
            'atkId': movVehicleAccessId.toString(),
        });

        LogService.instance.logRequest('OCR_AUTO_EXP_FOUND', {
          'placa': placa,
          'expMovementCount': 1,
          'firstTipoMov': firstExp.tipoMov,
          'movVehicleAccessId': movVehicleAccessId,
        });

        return 'EXP';
      }

      // ── CASO 2+ MOVIMIENTOS: EXP DOBLE ───────────────────────────────────
      // Identificar cuál movimiento coincide con el contenedor OCR
      // comparando con el contenedor embebido en conductor_ruc.
      //
      // Formato: "CGMU5721851-20339   " → contenedor = "CGMU5721851"
      //
      // El movimiento que NO coincide con el OCR es el de SALIDA.
      // Ese se confirma primero en OcrScannerScreen.
      // El movimiento que SÍ coincide (ENTRADA) va al ExpDobleScreen.

      final contenedorOcr = (manager.get('contenedor1') as String? ?? '')
          .trim()
          .toUpperCase();

      Map<String, dynamic>? movSalida; // NO coincide OCR → confirmar primero
      Map<String, dynamic>?
      movEntrada; // SÍ coincide OCR → procesar en pantalla

      for (final m in expMovements) {
        final mJson = m.toJson();
        final contEnMovimiento = _extractContainerFromConductorRuc(mJson);

        LogService.instance.logRequest('OCR_EXP_DOBLE_CLASSIFY_MOV', {
          'movid': mJson['movid'],
          'id': mJson['id'],
          'contEnMovimiento': contEnMovimiento,
          'contenedorOcr': contenedorOcr,
          'coincide': contEnMovimiento == contenedorOcr,
        });

        if (contEnMovimiento.isNotEmpty && contEnMovimiento == contenedorOcr) {
          movEntrada ??= mJson; // Coincide con OCR → entrada
        } else {
          movSalida ??= mJson; // No coincide → salida
        }
      }

      // Fallback si la clasificación no fue posible
      if (movSalida == null && movEntrada == null) {
        // Sin conductor_ruc útil: el primero es salida, el segundo entrada
        movSalida = expMovements[0].toJson();
        movEntrada = expMovements[1].toJson();
      } else if (movSalida == null) {
        // Todos coincidían (raro): el segundo es salida
        movSalida = expMovements.length > 1
            ? expMovements[1].toJson()
            : expMovements[0].toJson();
      } else if (movEntrada == null) {
        // Ninguno coincidió: el segundo es entrada
        movEntrada = expMovements.length > 1
            ? expMovements[1].toJson()
            : expMovements[0].toJson();
      }

      final vacIdSalida = _extractVacIdFromMovement(movSalida);
      final vacIdEntrada = _extractVacIdFromMovement(movEntrada!);

      // Guardar ambos movimientos en el manager
      manager.setManyWithoutNotify({
        'transactionType': 'EXP',
        'muelleTransactionCode': 'EXP',
        'muelleTransactionName': 'Exportación Doble',
        'ocrRouteDestination': 'EXP',

        // El movimiento de SALIDA va primero (confirm en OcrScannerScreen)
        'movement_active': movSalida,
        'ocrExpMovSalida': movSalida,
        'ocrExpMovEntrada': movEntrada,

        // VehicleAccessId del movimiento de SALIDA (el que vamos a confirmar)
        if (vacIdSalida > 0) 'ocrDiSvVehicleAccessId': vacIdSalida.toString(),
        if (vacIdSalida > 0 &&
            (manager.atkId == null || manager.atkId!.isEmpty))
          'atkId': vacIdSalida.toString(),

        // VehicleAccessId del movimiento de ENTRADA (para ExpDobleScreen)
        if (vacIdEntrada > 0)
          'ocrDiSvVehicleAccessIdEntrada': vacIdEntrada.toString(),
      });

      LogService.instance.logRequest('OCR_AUTO_EXP_DOBLE_FOUND', {
        'placa': placa,
        'expMovementCount': expMovements.length,
        'contenedorOcr': contenedorOcr,
        'movSalidaId': movSalida['id'],
        'movSalidaContainer': _extractContainerFromConductorRuc(movSalida),
        'movSalidaVacId': vacIdSalida,
        'movEntradaId': movEntrada['id'],
        'movEntradaContainer': _extractContainerFromConductorRuc(movEntrada),
        'movEntradaVacId': vacIdEntrada,
      });

      return 'EXP';
    } catch (e, st) {
      LogService.instance.logError(
        'OCR_AUTO_CONSULTAR_TRANSACCION_EXCEPTION',
        e,
        st,
      );
      return 'DESCARGA';
    } finally {
      _consultandoTransaccionPlaca = false;
    }
  }

  int _extractVacIdFromMovement(Map<String, dynamic> movJson) {
    final rawVacId =
        movJson['vehicleAccessId'] ??
        movJson['vehicle_access_id'] ??
        movJson['atk_id'] ??
        movJson['registro'] ??
        movJson['id'] ??
        (movJson['raw'] as Map<String, dynamic>?)?['id'];

    return int.tryParse(rawVacId?.toString() ?? '0') ?? 0;
  }

  String _extractContainerFromConductorRuc(Map<String, dynamic> movJson) {
    // Buscar en conductor_ruc directo, o en raw.conductor_ruc
    final raw =
        movJson['conductor_ruc']?.toString().trim() ??
        (movJson['raw'] as Map<String, dynamic>?)?['conductor_ruc']
            ?.toString()
            .trim() ??
        '';

    if (raw.isEmpty) return '';

    // El contenedor es todo lo que está antes del primer guion
    final dashIndex = raw.indexOf('-');
    if (dashIndex <= 0) return raw.trim().toUpperCase();

    return raw.substring(0, dashIndex).trim().toUpperCase();
  }
  // ---------------------------------------------------------------------------
  // NAVEGACIÓN
  // ---------------------------------------------------------------------------

  void _setRoutePreview({
    required String code,
    required String name,
    required String target,
  }) {
    _routeTransactionCode = code;
    _routeTransactionName = name;
    _routeTargetScreen = target;

    _manager?.setManyWithoutNotify({
      'ocrRouteTransactionCode': code,
      'ocrRouteTransactionName': name,
      'ocrRouteTargetScreen': target,
      'transactionType': code,
      'muelleTransactionCode': code,
      'muelleTransactionName': name,
    });

    LogService.instance.logRequest('OCR_ROUTE_PREVIEW_DEFINED', {
      'code': code,
      'name': name,
      'target': target,
    });

    if (mounted) setState(() {});
  }

  Future<void> _navigateToTransaction(
    String tipoMov,
    String cargaSuelta,
  ) async {
    final manager = _manager;
    if (manager == null) return;

    final mov = _normalizeTipoMov(tipoMov);

    final hasContainer = _hasOcrContainer(manager);
    final containerCount = _int(manager.get('ocrContainerCount')) ?? 0;
    final isDoubleContainer = containerCount > 1;

    Widget targetScreen;

    if (!hasContainer) {
      // ── SIN CONTENEDOR → PorteoSinContenedor ─────────────────────────────
      _setRoutePreview(
        code: 'PVO',
        name: 'Porteo vacío sin contenedor',
        target: 'PorteoSinContenedor',
      );

      LogService.instance.logRequest('OCR_NAV_PORTEO_SIN_CONTENEDOR', {
        'tipoMov': mov,
        'isTruckEmpty': manager.isTruckEmpty,
      });

      targetScreen = const PorteoSinContenedor();
    } else {
      // ── CON CONTENEDOR: resolver tipo ─────────────────────────────────────
      final placa = (_placaSesion ?? manager.vehiculoPlaca ?? '')
          .trim()
          .toUpperCase();

      final tipoResuelto = placa.isNotEmpty
          ? await _resolverTipoMovPorPlacaOcr(placa: placa, manager: manager)
          : 'DESCARGA';

      if (tipoResuelto == 'EXP') {
        manager.setManyWithoutNotify({
          'isLoading': true,
          'mensajeInferior':
              'Exportación detectada.\nConsultando repesaje por contenedor OCR...',
        });

        if (mounted) setState(() {});

        final contenedorOcr = (manager.get('contenedor1') as String? ?? '')
            .trim()
            .toUpperCase();

        if (contenedorOcr.isEmpty) {
          await LogService.instance
              .logWarning('OCR_EXPO_REPESAJE_CONTAINER_EMPTY', {
                'placa': placa,
                'contenedor1': manager.get('contenedor1'),
                'ocrContainerNumbers': manager.get('ocrContainerNumbers'),
              });
          _failAndNavigateToError(
            message:
                'No se pudo consultar repesaje porque el contenedor OCR está vacío.',
            logTag: 'OCR_EXPO_REPESAJE_CONTAINER_EMPTY_NAV_ERROR',
            extra: {'placa': placa},
          );
          return;
        }

        // Consultar si hay solicitud de repesaje activa para este contenedor
        final repesajeData = await _datosApiService
            .expoRepesajeYGuardarEnManager(
              contenedor: contenedorOcr,
              manager: manager,
            );

        final isRepesaje = repesajeData?.hasActiveSolicitud ?? false;
        final expMovementCount = _int(manager.get('ocrExpMovementCount')) ?? 0;

_runInBackground(
        LogService.instance.logRequest('OCR_EXPO_REPESAJE_ROUTING', {
          'placa': placa,
          'contenedor': contenedorOcr,
          'isRepesaje': isRepesaje,
          'tipoOperacion': repesajeData?.tipoOperacion,
          'solicitudId': repesajeData?.solicitudUpdateDisv?.id,
          'solicitudEstado': repesajeData?.solicitudUpdateDisv?.estado,
          'expMovementCount': expMovementCount,
        }), 'OCR_EXPO_REPESAJE_ROUTING',);

        // ════════════════════════════════════════════════════════════════════
        // RAMA A: EXP REPESAJE
        // ════════════════════════════════════════════════════════════════════
        if (isRepesaje) {
          _setRoutePreview(
            code: 'EXP_REPESAJE',
            name: 'Exportación Repesaje',
            target: 'ExpRepesajeScreen',
          );

          manager.setManyWithoutNotify({
            'isLoading': true,
            'mensajeInferior':
                'Repesaje confirmado.\nEjecutando Confirm EXP...',
            'transactionType': 'EXP_REPESAJE',
            'muelleTransactionCode': 'EXP_REPESAJE',
            'muelleTransactionName': 'Exportación Repesaje',
            'ocrRouteDestination': 'EXP_REPESAJE',
          });

          await LogService.instance
              .logRequest('OCR_NAV_EXP_REPESAJE_BEFORE_CONFIRM', {
                'placa': placa,
                'contenedor': contenedorOcr,
                'solicitudId': repesajeData?.solicitudUpdateDisv?.id,
                'solicitudEstado': repesajeData?.solicitudUpdateDisv?.estado,
                'nuevoDisv': repesajeData?.solicitudUpdateDisv?.nuevoDisv,
              });

          final confirmOk = await _ejecutarConfirmMuelleExp(
            manager: manager,
            placa: placa,
            contenedor: contenedorOcr,
            isRepesaje: true,
            expMovementCount: expMovementCount,
          );

          if (!confirmOk) return;

          // Restaurar ruta post-confirm (confirm puede cambiar transactionType)
          manager.setManyWithoutNotify({
            'isLoading': true,
            'mensajeInferior': 'Confirm EXP OK.\nRedirigiendo a repesaje...',
            'transactionType': 'EXP_REPESAJE',
            'muelleTransactionCode': 'EXP_REPESAJE',
            'muelleTransactionName': 'Exportación Repesaje',
            'ocrRouteDestination': 'EXP_REPESAJE',
            'contenedor1': contenedorOcr,
          });

          await LogService.instance
              .logRequest('OCR_NAV_EXP_REPESAJE_AFTER_CONFIRM', {
                'placa': placa,
                'contenedor': contenedorOcr,
                'solicitudId': repesajeData?.solicitudUpdateDisv?.id,
              });

          targetScreen = const ExpRepesajeScreen();

          // ════════════════════════════════════════════════════════════════════
          // RAMA B: EXP DOBLE (2+ movimientos, no repesaje)
          // ════════════════════════════════════════════════════════════════════
        } else if (expMovementCount >= 2) {
          // Leer los movimientos clasificados por _resolverTipoMovPorPlacaOcr
          final movSalidaJson =
              manager.get('ocrExpMovSalida') as Map<String, dynamic>?;
          final movEntradaJson =
              manager.get('ocrExpMovEntrada') as Map<String, dynamic>?;

          if (movSalidaJson == null) {
            _failAndNavigateToError(
              message:
                  'No se pudo identificar el movimiento de salida EXP doble.',
              logTag: 'OCR_EXP_DOBLE_MOV_SALIDA_NULL',
              extra: {'placa': placa, 'expMovementCount': expMovementCount},
            );
            return;
          }

          final contSalida = _extractContainerFromConductorRuc(movSalidaJson);
          final contEntrada = movEntradaJson != null
              ? _extractContainerFromConductorRuc(movEntradaJson)
              : contenedorOcr;

          final descargaName = 'Exportación Doble ($expMovementCount mov.)';

          _setRoutePreview(
            code: 'EXP',
            name: descargaName,
            target: 'ExpDobleScreen',
          );

          // Activar el movimiento de SALIDA para el confirm
          final vacIdSalida = _extractVacIdFromMovement(movSalidaJson);

          manager.setManyWithoutNotify({
            'isLoading': true,
            'mensajeInferior':
                'Exportación doble.\nConfirmando transacción de salida...',
            'transactionType': 'EXP',
            'muelleTransactionCode': 'EXP',
            'muelleTransactionName': descargaName,
            'ocrRouteDestination': 'EXP',
            'ocrRouteBypass': false,
            'ocrIsDoubleContainer': isDoubleContainer,
            'movement_active': movSalidaJson,
            if (vacIdSalida > 0)
              'ocrDiSvVehicleAccessId': vacIdSalida.toString(),
            if (vacIdSalida > 0) 'atkId': vacIdSalida.toString(),
          });

_runInBackground(
          LogService.instance
              .logRequest('OCR_NAV_EXP_DOBLE_CONFIRM_SALIDA_START', {
                'placa': placa,
                'expMovementCount': expMovementCount,
                'contSalida': contSalida,
                'contEntrada': contEntrada,
                'contenedorOcr': contenedorOcr,
                'vacIdSalida': vacIdSalida,
                'movSalidaId': movSalidaJson['id'],
              }), 'OCR_NAV_EXP_DOBLE_CONFIRM_SALIDA_START_ERROR',);

          // Confirm SOLO del movimiento de SALIDA
          final confirmOk = await _ejecutarConfirmMuelleExp(
            manager: manager,
            placa: placa,
            contenedor: contSalida.isNotEmpty ? contSalida : contenedorOcr,
            isRepesaje: false,
            expMovementCount: expMovementCount,
          );

          if (!confirmOk) return;

          // Guardar resultado y preparar el movimiento de ENTRADA para
          // que ExpDobleScreen lo tenga disponible.
          final confirmSalidaResponse = manager.get('confirmMuelleExpResponse');

          manager.setManyWithoutNotify({
            'isLoading': true,
            'mensajeInferior':
                'Salida confirmada.\nPreparando pantalla doble...',
            'transactionType': 'EXP',
            'muelleTransactionCode': 'EXP',
            'muelleTransactionName': descargaName,
            'ocrRouteDestination': 'EXP',
            'ocrRouteBypass': false,
            'ocrIsDoubleContainer': isDoubleContainer,

            // Resultado del confirm de SALIDA
            'expDobleConfirmSalidaOk': true,
            'expDobleConfirmSalidaResponse': confirmSalidaResponse,
            'expDobleContSalida': contSalida,

            // Movimiento de ENTRADA pendiente (se procesa en ExpDobleScreen)
            'expDobleMovEntrada': movEntradaJson,
            'expDobleContEntrada': contEntrada,
            'expDobleVacIdEntrada': _extractVacIdFromMovement(
              movEntradaJson ?? {},
            ),
            'contenedor1': contenedorOcr,
          });

          await LogService.instance
              .logRequest('OCR_NAV_EXP_DOBLE_CONFIRM_SALIDA_OK', {
                'placa': placa,
                'contSalida': contSalida,
                'contEntrada': contEntrada,
                'contenedorOcr': contenedorOcr,
                'expDobleVacIdEntrada': _extractVacIdFromMovement(
                  movEntradaJson ?? {},
                ),
              });

          targetScreen = const ExpDobleScreen();

          // ════════════════════════════════════════════════════════════════════
          // RAMA C: EXP con 1 solo movimiento, sin repesaje → error
          // ════════════════════════════════════════════════════════════════════
        } else {
          final message =
              'Exportación no válida para doble transacción.\n'
              'No es repesaje y solo se encontró $expMovementCount '
              'transacción EXP pendiente.';

          manager.setManyWithoutNotify({
            'isLoading': false,
            'transactionType': 'EXP',
            'muelleTransactionCode': 'EXP',
            'muelleTransactionName': 'Exportación incompleta',
            'ocrRouteDestination': 'EXP_INVALID_SINGLE',
          });

          await LogService.instance
              .logWarning('OCR_EXP_DOBLE_REQUIRES_TWO_MOVEMENTS', {
                'placa': placa,
                'contenedor': contenedorOcr,
                'expMovementCount': expMovementCount,
                'isRepesaje': isRepesaje,
              });

          _failAndNavigateToError(
            message: message,
            logTag: 'OCR_EXP_SINGLE_MOVEMENT_NAV_ERROR',
            extra: {
              'placa': placa,
              'contenedor': contenedorOcr,
              'expMovementCount': expMovementCount,
            },
          );
          return;
        }

        // ══════════════════════════════════════════════════════════════════════
        // DESCARGA
        // ══════════════════════════════════════════════════════════════════════
      } else {
        final descargaName = isDoubleContainer
            ? 'Descarga con $containerCount contenedores'
            : 'Descarga con contenedor';

        _setRoutePreview(
          code: 'DESCARGA',
          name: descargaName,
          target: 'DescargaScreen',
        );

        manager.setManyWithoutNotify({
          'transactionType': 'DESCARGA',
          'muelleTransactionCode': 'DESCARGA',
          'muelleTransactionName': descargaName,
          'ocrRouteBypass': false,
          'ocrRouteDestination': 'DESCARGA',
          'ocrIsDoubleContainer': isDoubleContainer,
        });

        LogService.instance.logRequest('OCR_NAV_DESCARGA_AUTO', {
          'placa': tipoResuelto == 'DESCARGA'
              ? (_placaSesion ?? manager.vehiculoPlaca ?? '')
              : '',
          'tipoResuelto': tipoResuelto,
          'containerCount': containerCount,
        });

        targetScreen = const DescargaScreen();
      }
    }

    _runInBackground(
      _markOcrAsReceivedIfNeeded(
        reason:
            'navigate_to_${_routeTargetScreen.isNotEmpty ? _routeTargetScreen : mov}',
      ),
      'OCR_UPDATE_STATUS_BACKGROUND_ERROR',
    );

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => targetScreen,
        transitionDuration: const Duration(milliseconds: 80),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (route) => false,
    );
  }
  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  int? _int(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  bool _hasOcrContainer(AtkTransactionManager manager) {
    final ocrVehicleType =
        manager.get('ocrVehicleType')?.toString().trim().toLowerCase() ?? '';
    final ocrContainerNumbers =
        manager.get('ocrContainerNumbers')?.toString().trim() ?? '';
    final contenedor = (manager.contenedor ?? '').trim();
    final containerCount = _int(manager.get('ocrContainerCount')) ?? 0;

    if (ocrVehicleType == 'truck_empty') return false;

    return containerCount > 0 ||
        ocrContainerNumbers.isNotEmpty ||
        contenedor.isNotEmpty;
  }

  void _failAndNavigateToError({
    required String message,
    required String logTag,
    Map<String, dynamic>? extra,
  }) {
    final manager = _manager;

    _validating = false;
    _consultandoConductor = false;
    _navigating = true;
    _facialStarted = false;

    manager?.setTransaccionActiva(false);
    manager?.setLoading(false);
    manager?.setError(message);
    manager?.setManyWithoutNotify({
      'ocrFacialStarted': false,
      'ocrFacialOk': false,
    });

    LogService.instance.logWarning(logTag, {'message': message, ...?extra});
    _teardown();

    if (!mounted) return;
    _navigateToError(message);
  }

  void _navigateToError(String error) {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ErrorScreen(error: error),
        transitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (route) => false,
    );
  }

  String _normalizeTipoMov(dynamic raw) {
    final t = (raw ?? '').toString().trim().toUpperCase();
    final m = RegExp(r'^[A-Z]{3}').firstMatch(t);
    return m?.group(0) ?? t;
  }

  String _normalizeFlag(dynamic raw) =>
      (raw ?? '').toString().trim().toUpperCase();

  String _cleanError(Object error) => error
      .toString()
      .replaceAll('Exception: ', '')
      .replaceAll('Error::', '')
      .replaceAll('Error:', '')
      .trim();

  // ---------------------------------------------------------------------------
  // VISUAL OCR
  // ---------------------------------------------------------------------------

  void _startOcrVisualCycle() {
    _ocrEmulationTimer?.cancel();
    _ocrCycles = 0;
    setState(() => _ocrStatus = SensorStatus.sensing);

    _ocrEmulationTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => _emulateOcrCycle(),
    );
  }

  void _emulateOcrCycle() {
    if (!mounted) {
      _ocrEmulationTimer?.cancel();
      return;
    }

    if (_ocrDetected || _ocrStatus == SensorStatus.weightOk) {
      _ocrEmulationTimer?.cancel();
      return;
    }

    _ocrCycles++;

    if (_ocrCycles <= 3) {
      setState(() => _ocrStatus = SensorStatus.badPosition);
    } else if (_ocrCycles <= 6) {
      setState(() => _ocrStatus = SensorStatus.goodPosition);
    } else {
      setState(() => _ocrStatus = SensorStatus.sensing);
      _ocrCycles = 0;
    }
  }

  void _teardown() {
    _stableTimer?.cancel();
    _stableTimer = null;
    _ocrEmulationTimer?.cancel();
    _ocrEmulationTimer = null;
    _placaTimeoutTimer?.cancel();
    _placaTimeoutTimer = null;
    _weightSub?.cancel();
    _weightSub = null;
    _ocrSub?.cancel();
    _ocrSub = null;

    try {
      _vehicleSub?.cancel();
    } catch (_) {}
    try {
      _connSub?.cancel();
    } catch (_) {}

    _vehicleSub = null;
    _connSub = null;
    _rfid?.dispose();
    _rfid = null;
    _scale?.dispose();
    _scale = null;
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final appManager = _appManager;

    if (appManager == null) {
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
                key: const ValueKey('ocr_processing'),
                title: _routeTransactionCode.isNotEmpty
                    ? 'Ruta definida'
                    : _facialStarted
                    ? 'Validando facial'
                    : 'Procesando conductor',
                subtitle: _routeTransactionCode.isNotEmpty
                    ? 'Transacción: $_routeTransactionCode\n'
                          '$_routeTransactionName\n'
                          'Destino: $_routeTargetScreen'
                    : _facialStarted
                    ? 'Consultando conductor y validando datos...'
                    : 'Consultando datos y preparando transacción...',
                primaryColor: p.azulCorporativo,
                secondaryColor: p.azulCorporativo.withValues(alpha: 0.6),
                size: size.shortestSide * 0.25,
              ),
            ),
          );
        }

        return Scaffold(
          body: Column(
            children: [
              AtkHeaderRfid(
                title: 'Lectura OCR de Contenedor',
                height: hHeader,
                assetImagePath: 'assets/images/tpg_logo.png',
                onModeChanged: (isLight) => appManager.setLight(isLight),
              ),
              AtkSubHeaderBarOcr(height: hSubHeader, sensorStatus: _ocrStatus),
              AtkBodyBarOcr(height: hBody, sensorStatus: _ocrStatus),
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

  // ---------------------------------------------------------------------------
  // CONFIRM MUELLE EXP — con extracción explícita de DISV para inicializar()
  // ---------------------------------------------------------------------------
  Future<bool> _ejecutarConfirmMuelleExp({
    required AtkTransactionManager manager,
    required String placa,
    required String contenedor,
    required bool isRepesaje,
    required int expMovementCount,
  }) async {
    final appManager = _appManager;
    if (appManager == null) {
      _failAndNavigateToError(
        message: 'No existe AppStateManager para ejecutar Confirm EXP.',
        logTag: 'OCR_CONFIRM_EXP_APP_MANAGER_NULL',
        extra: {
          'placa': placa,
          'contenedor': contenedor,
          'isRepesaje': isRepesaje,
          'expMovementCount': expMovementCount,
        },
      );
      return false;
    }

    final routeTransactionType = isRepesaje ? 'EXP_REPESAJE' : 'EXP';
    final routeDestination = isRepesaje ? 'EXP_REPESAJE' : 'EXP';

    try {
      manager.setManyWithoutNotify({
        'isLoading': true,
        'mensajeInferior': isRepesaje
            ? 'Repesaje confirmado.\nEjecutando Confirm EXP...'
            : 'Exportación doble detectada.\nEjecutando Confirm EXP...',
        'confirmTipoMov': 'EXP',
        'confirmRouteType': routeTransactionType,
        'confirmIsRepesaje': isRepesaje,
        'confirmContenedorOcr': contenedor,
      });

      if (mounted) setState(() {});

      LogService.instance.logRequest('OCR_CONFIRM_MUELLE_EXP_START', {
        'placa': placa,
        'contenedor': contenedor,
        'isRepesaje': isRepesaje,
        'expMovementCount': expMovementCount,
        'atkId': manager.atkId,
        'ocrDiSvVehicleAccessId': manager.get('ocrDiSvVehicleAccessId'),
        'movement_active': manager.get('movement_active'),
        'doorNumber': manager.get('doorNumber'),
        'side': manager.get('side'),
        'pesoActualBascula': manager.pesoActualBascula,
      });

      // Tu backend soporta EXP en el parámetro URL, no EXP_REPESAJE.
      final raw = await _confirmService.ejecutarConfirmMuelle(
        manager,
        appManager,
        'EXP',
      );

      final errorCode = _int(raw['errorCode']) ?? 1;
      final message = raw['message']?.toString() ?? '';

      LogService.instance.logRequest('OCR_CONFIRM_MUELLE_EXP_RESPONSE', {
        'errorCode': errorCode,
        'message': message,
        'isRepesaje': isRepesaje,
        'expMovementCount': expMovementCount,
        'raw': raw,
        'managerHasError': manager.hasError,
        'managerErrorMessage': manager.errorMessage,
      });

      if (errorCode != 0 || manager.hasError) {
        final errorMsg =
            manager.errorMessage ??
            (message.isNotEmpty
                ? message
                : 'Error ejecutando Confirm Muelle EXP.');

        _failAndNavigateToError(
          message: errorMsg,
          logTag: 'OCR_CONFIRM_MUELLE_EXP_FAILED',
          extra: {
            'placa': placa,
            'contenedor': contenedor,
            'isRepesaje': isRepesaje,
            'expMovementCount': expMovementCount,
            'errorCode': errorCode,
            'message': message,
          },
        );
        return false;
      }

      // ── EXTRAER DISV de atkPaConsDisvExp1 para que inicializar() lo tenga ──
      // _handleExpTransaction del ConfirmService lo intenta vía model['...'],
      // pero puede no escribir todos los campos. Aquí lo hacemos explícito
      // leyendo directo del raw JSON.
      _applyDiSvFromConfirmRaw(raw, manager, contenedor);

      // Restaurar la ruta (confirm puede haber cambiado transactionType a EXP).
      manager.setManyWithoutNotify({
        'confirmMuelleExpOk': true,
        'confirmMuelleExpResponse': raw,
        'transactionType': routeTransactionType,
        'muelleTransactionCode': routeTransactionType,
        'ocrRouteDestination': routeDestination,
        'contenedor1': contenedor,
      });

      LogService.instance.logRequest('OCR_CONFIRM_MUELLE_EXP_OK', {
        'placa': placa,
        'contenedor': contenedor,
        'isRepesaje': isRepesaje,
        'routeTransactionType': routeTransactionType,
        // Trazabilidad de qué quedó en manager para inicializar()
        'clienteExp': manager.clienteExp,
        'bookingExp': manager.bookingExp,
        'naveExp': manager.naveExp,
        'productoExp': manager.productoExp,
        'vehiculoTipoCarga': manager.vehiculoTipoCarga,
        'aniodisv': manager.aniodisv,
        'numdisv': manager.numdisv,
        'sello1Exp': manager.sello1Exp,
        'sello2Exp': manager.sello2Exp,
      });

      return true;
    } catch (e, st) {
      LogService.instance.logError(
        'OCR_CONFIRM_MUELLE_EXP_EXCEPTION',
        e,
        st,
      );

      _failAndNavigateToError(
        message: _cleanError(e),
        logTag: 'OCR_CONFIRM_MUELLE_EXP_EXCEPTION_NAV_ERROR',
        extra: {
          'placa': placa,
          'contenedor': contenedor,
          'isRepesaje': isRepesaje,
          'expMovementCount': expMovementCount,
        },
      );

      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // HELPER — extraer DISV desde raw de confirm y escribir en manager
  // ---------------------------------------------------------------------------
  void _applyDiSvFromConfirmRaw(
    Map<String, dynamic> raw,
    AtkTransactionManager manager,
    String contenedorOcr,
  ) {
    try {
      // Navegar: raw → data → services → atkPaConsDisvExp1 → data[0]
      final data = raw['data'] as Map<String, dynamic>?;
      final services = data?['services'] as Map<String, dynamic>?;
      final disvEnvelope =
          services?['atkPaConsDisvExp1'] as Map<String, dynamic>?;
      final disvList = disvEnvelope?['data'];

      Map<String, dynamic> disv = {};

      if (disvList is List && disvList.isNotEmpty) {
        final first = disvList[0];
        if (first is Map<String, dynamic>) {
          disv = first;
        } else if (first is Map) {
          disv = Map<String, dynamic>.from(first);
        }
      } else if (disvList is Map<String, dynamic>) {
        // Algunos backends devuelven objeto en lugar de lista
        disv = disvList;
      }

      if (disv.isEmpty) {
        LogService.instance.logWarning('OCR_CONFIRM_DISV_EXTRACT_EMPTY', {
          'reason': 'atkPaConsDisvExp1.data está vacío o ausente',
          'disvEnvelope': disvEnvelope,
        });
        return;
      }

      // ── Helpers locales ─────────────────────────────────────────────────────
      String? _str(dynamic v) {
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }

      int? _intVal(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString().trim());
      }

      double? _dblVal(dynamic v) {
        if (v == null) return null;
        if (v is double) return v;
        if (v is num) return v.toDouble();
        final cleaned = v.toString().trim().replaceAll(',', '.');
        return double.tryParse(cleaned);
      }

      // ── Mapear campos del DISV al manager ───────────────────────────────────
      final fields = <String, dynamic>{
        // Cliente / empresa dueña del contenedor
        if (_str(disv['nombre']) != null) 'clienteExp': _str(disv['nombre']),

        // Tipo de carga (FCL, LCL, etc.)
        if (_str(disv['tipocarga']) != null)
          'vehiculoTipoCarga': _str(disv['tipocarga']),

        // Producto
        if (_str(disv['producto']) != null)
          'productoExp': _str(disv['producto']),

        // Booking y nave
        if (_str(disv['booking']) != null) 'bookingExp': _str(disv['booking']),
        if (_str(disv['nave']) != null) 'naveExp': _str(disv['nave']),

        // Contenedor del DISV (para validación cruzada con OCR)
        if (_str(disv['numcontenedor']) != null)
          'contenedorExp': _str(disv['numcontenedor']),

        // Sellos
        if (_str(disv['sello1']) != null) 'sello1Exp': _str(disv['sello1']),
        if (_str(disv['sello2']) != null) 'sello2Exp': _str(disv['sello2']),
        if (_str(disv['sello3']) != null) 'sello3Exp': _str(disv['sello3']),
        if (_str(disv['sello4']) != null) 'sello4Exp': _str(disv['sello4']),

        // Tara OCR
        if (_dblVal(disv['tara']) != null && (_dblVal(disv['tara']) ?? 0) > 0)
          'pesoTara': disv['tara'].toString(),

        // IMO y refrigerado
        if (_str(disv['carga_imo']) != null)
          'vehiculoCargaImo': _str(disv['carga_imo']),
        if (_str(disv['refrigerado']) != null)
          'vehiculoRefrigerado': _str(disv['refrigerado']),

        // Observaciones
        if (_str(disv['observaciones']) != null)
          'vehiculoObservaciones': _str(disv['observaciones']),

        // DISV año y número (críticos para guardar)
        if (_intVal(disv['aniodisv']) != null)
          'aniodisv': _intVal(disv['aniodisv']),
        if (_intVal(disv['numdisv']) != null)
          'numdisv': _intVal(disv['numdisv']),
      };

      manager.setManyWithoutNotify(fields);

      LogService.instance.logRequest('OCR_CONFIRM_DISV_APPLIED', {
        'contenedorOcr': contenedorOcr,
        'disvNombre': disv['nombre'],
        'disvTipocarga': disv['tipocarga'],
        'disvBooking': disv['booking'],
        'disvNave': disv['nave'],
        'disvAniodisv': disv['aniodisv'],
        'disvNumdisv': disv['numdisv'],
        'fieldsApplied': fields.keys.toList(),
      });
    } catch (e, st) {
      LogService.instance.logError('OCR_CONFIRM_DISV_EXTRACT_EXCEPTION', e, st);
      // No lanzamos — no bloqueamos el flujo por fallo de extracción de DISV.
    }
  }

  Future<void> _markOcrAsReceivedIfNeeded({required String reason}) async {
    final manager = _manager;
    final appManager = _appManager;

    if (manager == null || appManager == null) return;

    if (_ocrStatusUpdateSent) {
      LogService.instance.logRequest('OCR_UPDATE_STATUS_SKIP', {
        'reason': 'already_sent',
        'flowReason': reason,
        'ocrPersistenceId': manager.ocrPersistenceId,
        'ocrStatus': manager.ocrStatus,
      });
      return;
    }

    final uuid = (manager.ocrPersistenceId ?? '').trim();

    if (uuid.isEmpty) {
      LogService.instance.logWarning('OCR_UPDATE_STATUS_SKIP', {
        'reason': 'ocrPersistenceId_empty',
        'flowReason': reason,
        'ocrTransitId': manager.ocrTransitId,
        'ocrStatus': manager.ocrStatus,
        'ocrVehicleType': manager.ocrVehicleType,
        'ocrContainerCount': manager.ocrContainerCount,
      });
      return;
    }

    final currentStatus = (manager.ocrStatus ?? '').trim().toUpperCase();

    if (currentStatus == 'RECIBIDO') {
      _ocrStatusUpdateSent = true;

      LogService.instance.logRequest('OCR_UPDATE_STATUS_SKIP', {
        'reason': 'already_received',
        'flowReason': reason,
        'uuid': uuid,
      });
      return;
    }

    try {
      final raw = await _ocrApiService.updateStatus(
        uuid: uuid,
        status: 'Recibido',
        baseUrl: appManager.kioskConfig?.ocrService,
      );

      _ocrStatusUpdateSent = true;

      manager.setManyWithoutNotify({
        'ocrStatus': 'Recibido',
        'ocrUpdateStatusOk': true,
        'ocrUpdateStatusResponse': raw,
        'ocrUpdateStatusAt': DateTime.now().toIso8601String(),
      });

      LogService.instance.logRequest('OCR_UPDATE_STATUS_OK', {
        'uuid': uuid,
        'newStatus': 'Recibido',
        'flowReason': reason,
        'response': raw,
      });
    } catch (e, st) {
      LogService.instance.logError(
        'OCR_UPDATE_STATUS_ERROR_NON_BLOCKING',
        e,
        st,
      );

      manager.setManyWithoutNotify({
        'ocrUpdateStatusOk': false,
        'ocrUpdateStatusError': e.toString(),
        'ocrUpdateStatusAt': DateTime.now().toIso8601String(),
      });
    }
  }
}
