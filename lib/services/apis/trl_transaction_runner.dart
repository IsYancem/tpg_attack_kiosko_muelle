// lib/services/apis/trl_transaction_runner.dart
// OPTIMIZADO 2025-12-09 - Con mensajes de progreso (200ms cada paso)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tpg_attack_kiosko_muelle/models/trl/trl_transaccion_response_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/print/ticket_trl_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/trl/trl_transaction_request_model.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/rfidScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/error_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/trl_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/gate_control_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/atk_utils.dart';
import 'package:tpg_attack_kiosko_muelle/utils/env_utils.dart';

class TrlTransactionRunner {
  final TrlService _trlService;
  final LogService _log;

  // ✅ Duración de cada mensaje de progreso
  static const _progressDelay = Duration(milliseconds: 200);

  TrlTransactionRunner({TrlService? trlService, LogService? log})
    : _trlService = trlService ?? TrlService(),
      _log = log ?? LogService.instance;

  /// Datos extraídos para impresión
  TrlConsCntData? _trlDataCnt1;
  TrlConsCntData? _trlDataCnt2;

  /// ✅ Helper para mostrar mensaje de progreso
  Future<void> _showProgress(
    AtkTransactionManager manager,
    String mensaje,
  ) async {
    manager.setManyWithoutNotify({'mensajeInferior': mensaje});
    await Future.delayed(_progressDelay);
  }

  Future<void> run({
    required BuildContext context,
    required AppStateManager appManager,
    required AtkTransactionManager manager,
  }) async {
    // ═══════════════════════════════════════════════════════════════
    // PASO 1: Preparar request
    // ═══════════════════════════════════════════════════════════════
    await _showProgress(manager, '📋 Preparando solicitud de traslado...');

    final now = DateTime.now()
        .toIso8601String()
        .replaceAll('T', ' ')
        .substring(0, 19);

    final kioskConfig = appManager.kioskConfig!;
    final gateConfig = appManager.gateConfig;
    final int atkId = int.tryParse(manager.atkId ?? '') ?? 0;
    final String kioskServer = appManager.kioskConfig!.kioskServer;
    final String kioskPort = appManager.kioskConfig!.kioskServerPort.toString();
    final int gate = int.tryParse(gateConfig!.gateLocation) ?? 0;

    final req = TrlTransaccionRequestModel(
      placa: manager.vehiculoPlaca ?? '',
      cedula: manager.driverCedula ?? manager.driverId,
      contenedor1: manager.contenedor1,
      contenedor2: manager.contenedor2,
      peso: manager.pesoActualBascula,
      gate: gate,
      letra: kioskConfig.gateLetter,
      patio: kioskConfig.patio,
      patioStr: kioskConfig.patio,
      atkId: atkId,
      now: now,
      usuario: KioskUserEnv.usuario,
      kioskServer: kioskServer,
      kioskPort: kioskPort,
    );

    try {
      // ═══════════════════════════════════════════════════════════════
      // PASO 2: Ejecutar TrlService
      // ═══════════════════════════════════════════════════════════════
      final model = await _trlService.ejecutarTransaccionTrl(req, manager);

      // Extraer datos para impresión
      _extractTrlData(model);

      // ═══════════════════════════════════════════════════════════════
      // PASO 3: Verificar error
      // ═══════════════════════════════════════════════════════════════
      if (manager.hasError) {
        if (!context.mounted) return;
        _navigateToError(context, manager.errorMessage ?? 'Error');
        return;
      }

      // ═══════════════════════════════════════════════════════════════
      // PASO 4: Preparando impresión
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '🖨️ Preparando comprobante de traslado...');

      // ═══════════════════════════════════════════════════════════════
      // PASO 5: Abriendo barrera
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '🚧 Abriendo barrera de acceso...');

      // ═══════════════════════════════════════════════════════════════
      // PASO 6: Finalizando
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '✅ Transacción completada exitosamente');

      // ═══════════════════════════════════════════════════════════════
      // PASO 7: Actualizar UI éxito
      // ═══════════════════════════════════════════════════════════════
      manager.setMany({
        'isLoading': false,
        'tituloPantalla': 'TRASLADO',
        'mensajeInferior':
            'Bienvenido, por favor continúe.\nSu comprobante de ingreso puede ser verificado desde la APP de TPG',
      });

      // ═══════════════════════════════════════════════════════════════
      // PASO 8: Background tasks (fire-and-forget)
      // ═══════════════════════════════════════════════════════════════
      _executeBackgroundTasks(manager, appManager);

      // ═══════════════════════════════════════════════════════════════
      // PASO 9: Esperar 15 segundos
      // ═══════════════════════════════════════════════════════════════
      await Future.delayed(const Duration(seconds: 15));

      // ═══════════════════════════════════════════════════════════════
      // PASO 10: Reset y navegación
      // ═══════════════════════════════════════════════════════════════
      manager.resetAll();
      manager.setFlowRemainingSeconds(null);

      if (context.mounted) {
        _navigateToRfid(context);
      }
    } catch (e, st) {
      _log.logError('TRL_RUNNER_EX', e, st);

      manager.setMany({
        'isLoading': false,
        'hasError': true,
        'errorMessage': 'Error ejecutando servicio TRL: $e',
        'mensajeInferior': 'Error ejecutando servicio TRL: $e',
      });

      if (context.mounted) {
        _navigateToError(context, '$e');
      }
    }
  }

  /// Extrae los datos de TRL del response para usarlos en la impresión
  void _extractTrlData(TrlTransaccionResponseModel model) {
    _trlDataCnt1 = null;
    _trlDataCnt2 = null;

    final services = model.data?.services ?? {};

    if (services.containsKey('trl_cons_cnt1')) {
      final step = services['trl_cons_cnt1']!;
      final data = step.dataAsMap;
      if (step.errorCode == 0 && data != null) {
        _trlDataCnt1 = TrlConsCntData.fromJson(data);
      }
    }

    if (services.containsKey('trl_cons_cnt2')) {
      final step = services['trl_cons_cnt2']!;
      final data = step.dataAsMap;
      if (step.errorCode == 0 && data != null) {
        _trlDataCnt2 = TrlConsCntData.fromJson(data);
      }
    }
  }

  /// ✅ Tareas background (fire-and-forget)
  void _executeBackgroundTasks(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) {
    final controlUrl = appManager.kioskConfig!.controlGateService;
    final gateLocation = appManager.gateConfig!.gateLocation;
    final apiKeyHeader = appManager.gateConfig!.apiKey;
    final apiKeyBody = appManager.gateConfig!.keyPlc;
    final gateNumber = int.tryParse(appManager.kioskConfig!.gate);
    final originalSide = int.tryParse(manager.sideGate ?? '') ?? 1;
    final sideNumber = AtkUtils.invertSide(originalSide);

    Future.wait([
      _imprimirTicketTrl(manager, appManager),
      if (gateNumber != null)
        _abrirBarrera(
          controlUrl: controlUrl,
          apiKey: apiKeyHeader,
          keyPlc: apiKeyBody,
          gateLocation: gateLocation,
          gate: gateNumber,
          side: sideNumber,
        ),
    ]).catchError((_) => <void>[]);
  }

  /// ✅ Navegación fluida
  void _navigateToError(BuildContext context, String error) {
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

  void _navigateToRfid(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const RfidScreen(),
        transitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
      (route) => false,
    );
  }

  Future<void> _abrirBarrera({
    required String controlUrl,
    required String apiKey,
    required String keyPlc,
    required String gateLocation,
    required int gate,
    required int side,
  }) async {
    try {
      await GateControlService.instance.openGate(
        url: controlUrl,
        bodyApiKey: keyPlc,
        headerApiKey: apiKey,
        gateLocation: gateLocation,
        gate: gate,
        side: side,
      );
    } catch (e) {
      _log.logWarning('TRL_GATE_OPEN_FAILED', {'error': '$e'});
    }
  }

  Future<void> _imprimirTicketTrl(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) async {
    try {
      final ticketData = TicketTrlModel(
        atkId: int.tryParse(manager.atkId ?? '0') ?? 0,
        placa: manager.vehiculoPlaca ?? '',
        entrada: _formatearFechaActual(),
        origen: _trlDataCnt1?.origen ?? manager.origenTrl ?? '',
        destino: _trlDataCnt1?.destino ?? manager.destinoTrl ?? '',
        peso: _trlDataCnt1?.peso?.toString() ?? manager.pesoIngreso ?? '',
        gate: appManager.kioskConfig?.gate,
        numTranBascula: int.tryParse(manager.atkId ?? '0'),
        contenedor1: _trlDataCnt1?.bl ?? manager.contenedor1 ?? '',
        anioOperacion1: _trlDataCnt1?.anoOperacion,
        corOperacion1: _trlDataCnt1?.corOperacion,
        detalle1: _trlDataCnt1?.detalle ?? manager.detalle1,
        contenedor2: _trlDataCnt2?.bl ?? manager.contenedor2,
        anioOperacion2: _trlDataCnt2?.anoOperacion,
        corOperacion2: _trlDataCnt2?.corOperacion,
        detalle2: _trlDataCnt2?.detalle ?? manager.detalle2,
        apellidos: '',
        nombres: manager.driverName ?? '',
      );

      await PrintService.printTrlTicket(
        ticketData: ticketData,
        saveToSpecificPath: true,
        autoPrint: true,
      );
    } catch (e, st) {
      _log.logError('TRL_PRINT_TICKET_ERROR', e, st);
    }
  }

  String _formatearFechaActual() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
  }
}
