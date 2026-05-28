// lib/screens/rfid/rfid_screen.dart
// Autor: Abraham Yance
// Fecha: 2025-11-21
// 🛰️ Lectura RFID — Detecta vehículos y navega por flujo normal RFID

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/models/websockets/websocket_models.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/faceScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/muelle/muelleTransaction_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/transactions/incoming/resIncoming_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/placa_auth_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/connectivity_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/rfid_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/status_log_bus.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyRfid/atkHeaderBar_rfid.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyRfid/atkRfidLog_rfid.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyRfid/atkRfidWaiting_rfid.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyRfid/atkSubheaderBar_rfid.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/atkFooterBar_common.dart';

class RfidScreen extends StatefulWidget {
  const RfidScreen({super.key});

  @override
  State<RfidScreen> createState() => _RfidScreenState();
}

void _dbg(String tag, [Map<String, dynamic>? data]) {
  final ts = DateTime.now().toIso8601String();
  final payload = data == null ? '' : ' | $data';

  // ignore: avoid_print
  print('🧭 [RFID_FLOW][$ts] $tag$payload');
}

class _RfidScreenState extends State<RfidScreen> {
  RfidService? _rfid;
  late final AtkTransactionManager _manager;

  // 🔌 Suscripciones
  StreamSubscription<VehicleResponse>? _vehicleSub;
  StreamSubscription<bool>? _connSub;

  // 📦 Estado de lectura
  String? _placaLeida;
  bool _navigating = false;
  String? _placaSesion;

  Timer? _placaTimeoutTimer;
  static const int _placaTimeoutSeconds = 120;

  int? _ultimoSideDetectado;

  String? _lastProcessedEventKey;
  DateTime? _lastProcessedAt;
  static const Duration _eventDedupWindow = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();

    final appState = context.read<AppStateManager>();
    _manager = context.read<AtkTransactionManager>();

    _navigating = false;
    _placaSesion = null;
    _placaLeida = null;
    _ultimoSideDetectado = null;
    _lastProcessedEventKey = null;
    _lastProcessedAt = null;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      _manager.setTransaccionActiva(false);

      await _initConnectivityAndScreen(appState);
    });
  }

  Future<void> _initConnectivityAndScreen(AppStateManager appState) async {
    print('⚡ INIT_START');
    final cm = ConnectivityManager.instance;

    // Asegurar que el CM base esté listo (sin force)
    await cm.ensureInitialized(appState);
    if (!mounted) return;

    // Cancelar suscripciones viejas
    await _vehicleSub?.cancel();
    await _connSub?.cancel();
    _vehicleSub = null;
    _connSub = null;

    // Crear instancia RFID fresca SIN conectar aún
    _rfid = await cm.reinitRfid(appState);
    print('🖥️ SCREEN rfidService hashCode: ${_rfid.hashCode}');

    // ← PRIMERO suscribirse
    _vehicleSub = _rfid!.vehicleDetected$.listen(_onVehicleDetected);
    _connSub = _rfid!.isConnected$.listen((ok) {
      LogService.instance.logRequest('RFID_CONNECTION', {'connected': ok});
    });
    print('🔌 SUSCRITO | hashCode: ${_rfid.hashCode}');

    // ← DESPUÉS conectar (ya hay listener, no se pierde ningún evento)
    final rfidUrl = appState.kioskConfig!.rfidService;
    await _rfid!.connect(rfidUrl);

    setState(() {});

    final routeName = ModalRoute.of(context)?.settings.name;
    LogService.instance.logScreenEnter(
      'RfidScreen',
      route: routeName,
      extra: {'theme': appState.isLight ? 'light' : 'dark'},
    );
  }

  bool _isDuplicateVehicleEvent(VehicleResponse response) {
    final record = response.record;
    if (record == null) return false;

    final key = '${response.gate}|${response.side}|${record.regNumber}';
    final now = DateTime.now();

    final isSameKey = _lastProcessedEventKey == key;
    final isInsideWindow =
        _lastProcessedAt != null &&
        now.difference(_lastProcessedAt!) <= _eventDedupWindow;

    if (isSameKey && isInsideWindow) {
      return true;
    }

    _lastProcessedEventKey = key;
    _lastProcessedAt = now;
    return false;
  }

  Future<void> _onVehicleDetected(VehicleResponse response) async {
    _dbg('EVT_START', {
      'mounted': mounted,
      'navigating': _navigating,
      'success': response.isSuccess,
      'hasRecord': response.record != null,
      'side': response.side,
      'msg': response.message,
    });

    try {
      if (!mounted) {
        _dbg('EVT_SKIP', {'reason': 'not_mounted'});
        return;
      }

      if (!response.isSuccess || response.record == null) {
        _dbg('EVT_DROP', {'reason': 'not success or null record'});
        return;
      }

      final vehicle = response.record!;
      final placa = vehicle.regNumber;

      if (_navigating && _placaSesion == placa) {
        _dbg('EVT_SKIP', {'reason': 'navigating_same_plate', 'placa': placa});
        return;
      }

      if (_navigating && _placaSesion != placa) {
        _dbg('EVT_RESET_NAV_FOR_NEW_PLATE', {
          'oldPlate': _placaSesion,
          'newPlate': placa,
        });
        _navigating = false;
      }

      if (_placaSesion != placa) {
        _lastProcessedEventKey = null;
        _lastProcessedAt = null;
      }

      if (_isDuplicateVehicleEvent(response)) {
        _dbg('EVT_DUPLICATE_SKIP', {'placa': placa, 'msg': response.message});
        return;
      }

      _placaLeida = placa;
      setState(() {});

      StatusLogBus.instance.addText('RFID', '🚗 Placa detectada: $placa');

      _dbg('PLACA_DETECTED', {
        'placa': placa,
        'prevSession': _placaSesion,
        'side': response.side,
        'veh_state': vehicle.state,
        'veh_msg': vehicle.message,
      });

      _ultimoSideDetectado = response.side;

      if (_placaSesion != placa) {
        final isMuelle = context.read<AppStateManager>().isMuelle;

        _dbg('AUTH_START', {'placa': placa, 'isMuelle': isMuelle});

        bool puedeContinuar = true;

        if (!isMuelle) {
          try {
            puedeContinuar = await PlacaAuthService()
                .ejecutarPlacaAuth(placa: placa)
                .timeout(const Duration(seconds: 10));
          } catch (e) {
            _dbg('AUTH_EXCEPTION', {'error': e.toString()});
            StatusLogBus.instance.addText('RFID', '❌ Auth exception: $e');
            _navigating = false;
            return;
          }
        }

        _dbg('AUTH_DONE', {
          'placa': placa,
          'ok': puedeContinuar,
          'isMuelle': isMuelle,
        });

        if (!puedeContinuar) {
          StatusLogBus.instance.addText('RFID', '⛔ No autorizado: $placa');
          _dbg('AUTH_DENIED', {'placa': placa});

          _placaSesion = null;
          _ultimoSideDetectado = null;
          _navigating = false;

          Future.delayed(const Duration(seconds: 2), () {
            if (!mounted) return;

            if (_placaLeida == placa && _placaSesion == null) {
              setState(() {
                _placaLeida = null;
              });
            }
          });

          return;
        }

        _dbg('SESSION_CREATE_START', {'placa': placa});
        _startNewVehicleSession(placa, vehicle);

        _dbg('SESSION_CREATED', {
          'placaSesion': _placaSesion,
          'placaLeida': _placaLeida,
        });
      } else {
        _dbg('SESSION_REUSED', {'placaSesion': _placaSesion});
      }

      _dbg('NAV_TRY_FROM_RFID', {'side': _ultimoSideDetectado});
      await _tryNavigate(_ultimoSideDetectado);
    } catch (e) {
      _dbg('EVT_FATAL_EXCEPTION', {'error': e.toString()});
      StatusLogBus.instance.addText('RFID', '❌ Handler error: $e');
      _navigating = false;
    }
  }

  Future<void> _tryNavigate(int? sideFromRfid) async {
    _dbg('TRY_NAV_ENTER', {
      'mounted': mounted,
      'navigating': _navigating,
      'transaccionActiva': _manager.transaccionActiva,
      'placaSesion': _placaSesion,
      'sideFromRfid': sideFromRfid,
    });

    LogService.instance.logRequest('NAVIGATION_ATTEMPT', {
      'placa': _placaSesion,
      'sideFromRfid': sideFromRfid,
    });

    if (!mounted || _navigating) return;
    if (_placaSesion == null) return;
    if (_manager.transaccionActiva) return;

    _navigating = true;

    try {
      final side = sideFromRfid ?? _ultimoSideDetectado ?? 1;
      final isMuelle = context.read<AppStateManager>().isMuelle;

      final Widget nextScreen = isMuelle
          ? const MuelleTransactionScreen()
          : const FaceScannerScreen();

      final nextScreenName = isMuelle
          ? 'MuelleTransactionScreen'
          : 'FaceScannerScreen';

      LogService.instance.logRequest('GATE_OPENED', {
        'side': side,
        'isMuelle': isMuelle,
        'nextScreen': nextScreenName,
      });

      _manager.setTransaccionActiva(true);
      _teardownServices();

      if (!mounted) return;

      _dbg('NAV_PUSH', {'target': nextScreenName, 'mounted': mounted});

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => nextScreen),
      );
    } catch (e) {
      _dbg('NAV_EXCEPTION', {'error': e.toString()});
      LogService.instance.logError('NAVIGATION_EXCEPTION', e);
      _navigating = false;
    }
  }

  void _startNewVehicleSession(String placa, VehicleRecord vehicle) {
    _placaTimeoutTimer?.cancel();

    _placaSesion = null;
    _placaLeida = null;
    _navigating = false;

    _manager.resetVehiculo();
    _manager.resetImportador();
    _manager.resetContenedores();
    _manager.resetPesos();
    _manager.setTransaccionActiva(false);

    _placaSesion = placa;
    _placaLeida = placa;

    _manager.set('vehiculoPlaca', placa);
    _manager.set('vehiculoRfid', vehicle.rfid);
    _manager.set('vehiculoEmpresa', vehicle.company);
    _manager.set('vehiculoMarca', vehicle.brand);
    _manager.set('vehiculoModelo', vehicle.model);
    _manager.set('vehiculoColor', vehicle.color);
    _manager.set('vehiculoEstado', vehicle.state.toString());
    _manager.set('vehiculoMensaje', vehicle.message);

    setState(() {});

    _placaTimeoutTimer = Timer(
      const Duration(seconds: _placaTimeoutSeconds),
      _onPlacaTimeout,
    );

    LogService.instance.logRequest('RFID_SESSION_START', {
      'placa': placa,
      'timeout': _placaTimeoutSeconds,
    });
  }

  void _onPlacaTimeout() {
    if (!mounted) return;

    StatusLogBus.instance.addText(
      'RFID',
      '⏱️ Tiempo agotado. Limpieza de sesión.',
    );

    LogService.instance.logWarning('RFID_SESSION_TIMEOUT', {
      'placa': _placaSesion,
    });

    _placaSesion = null;
    _placaLeida = null;
    _ultimoSideDetectado = null;
    _navigating = false;

    _manager.resetVehiculo();
    _manager.resetImportador();
    _manager.resetContenedores();
    _manager.resetPesos();
    _manager.setTransaccionActiva(false);

    setState(() {});
  }

  void _teardownServices() {
    try {
      _vehicleSub?.cancel();
    } catch (_) {}

    try {
      _connSub?.cancel();
    } catch (_) {}

    _vehicleSub = null;
    _connSub = null;
  }

  @override
  void dispose() {
    _placaTimeoutTimer?.cancel();
    _teardownServices();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final hHeader = size.height * 0.15;
    final hSubHeader = size.height * 0.08;
    final hBody1 = size.height * 0.40;
    final hBody2 = size.height * 0.29;
    final hSpaceBodys = size.height * 0.01;
    final hFooter = size.height * 0.07;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              AtkHeaderRfid(
                title: 'Monitoreando Acceso RFID',
                height: hHeader,
                assetImagePath: 'assets/images/tpg_logo.png',
                onModeChanged: (isLight) =>
                    context.read<AppStateManager>().setLight(isLight),
              ),
              AtkSubHeaderBarRfid(
                height: hSubHeader,
                personName: '',
                flowType: FlowType.entrada,
              ),
              SizedBox(
                height: hBody1,
                child: AtkRfidWaitingPanel(
                  height: hBody1,
                  placaLeida: _placaLeida,
                  contenedorLeido: null,
                  isMuelle: false,
                ),
              ),
              SizedBox(
                height: hBody2,
                child: _rfid == null
                    ? const Center(child: CircularProgressIndicator())
                    : AtkRfidLogPanel(
                        height: hBody2,
                        service: _rfid!,
                        ocrService: null,
                        maxItems: 3,
                      ),
              ),
              SizedBox(height: hSpaceBodys),
              AtkFooterBarCommon(
                height: hFooter,
                onModeChanged: (isLight) =>
                    context.read<AppStateManager>().setLight(isLight),
              ),
            ],
          ),
          Positioned(
            top: 20,
            left: 20,
            child: GestureDetector(
              onTap: _navigateToTestExp,
              child: Container(
                width: 100,
                height: 100,
                color: Colors.transparent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToTestExp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ResIncomingScreen()),
    );
  }
}
