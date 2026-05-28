// lib/services/apis/dspcs_transaction_runner.dart
// OPTIMIZADO 2025-12-09 - Con mensajes de progreso (200ms cada paso)
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/models/dspcs/dspcs_transaccion_request_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/dspcs/dspcs_transaccion_response_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/print/ticket_dspCS_model.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/rfidScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/error_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/dspcs/dspcs_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/gate_control_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/atk_utils.dart';

class DspCsTransactionRunner {
  final DspCsService _dspCsService;
  final LogService _log;

  // ✅ Duración de cada mensaje de progreso
  static const _progressDelay = Duration(milliseconds: 200);

  DspCsTransactionRunner({DspCsService? dspCsService, LogService? log})
    : _dspCsService = dspCsService ?? DspCsService(),
      _log = log ?? LogService.instance;

  /// Lista de DRES obtenidos de la respuesta para impresión
  List<DspCsDresConsItem> _dresDataList = [];

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
    await _showProgress(manager, '📋 Preparando solicitud de carga suelta...');

    final now = DateTime.now().toIso8601String();
    final pesoNum = manager.pesoActualBascula;

    final req = DspCsTransaccionRequestModel(
      rucTpg: appManager.kioskConfig!.rucTpg,
      placa: manager.vehiculoPlaca ?? '',
      vehicleAccessId: int.tryParse(manager.atkId ?? '0') ?? 0,
      codchofer: manager.driverId ?? '',
      numregAtk: manager.atkId ?? '',
      peso: pesoNum,
      gate: int.tryParse(appManager.kioskConfig?.gate ?? '0') ?? 0,
      cedulaChofer: manager.driverCedula,
      now: now,
      patio: appManager.kioskConfig?.patio ?? 'TPG2',
      monitorHost: appManager.kioskConfig?.kioskServer,
      monitorPort: appManager.kioskConfig?.kioskServerPort,
    );

    try {
      // ═══════════════════════════════════════════════════════════════
      // PASO 2: Ejecutar DspCsService
      // ═══════════════════════════════════════════════════════════════
      final model = await _dspCsService.ejecutarTransaccionDspCs(req, manager);

      // Extraer datos de DRES para impresión
      _extractDresData(model);

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
      await _showProgress(manager, '🖨️ Preparando comprobante de ingreso...');

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
      final numeroTransaccion = model.data?.numero ?? manager.atkId ?? '-';

      manager.setMany({
        'isLoading': false,
        'tituloPantalla': 'DESPACHO DE CARGA SUELTA',
        'mensajeInferior':
            'Bienvenido, por favor continúe.\nSu comprobante de ingreso puede ser verificado desde la APP de TPG\nNúmero: $numeroTransaccion',
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
      _log.logError('DSPCS_RUNNER_EX', e, st);

      manager.setMany({
        'isLoading': false,
        'hasError': true,
        'errorMessage': 'Error ejecutando servicio DSP-CS: $e',
        'mensajeInferior': 'Error ejecutando servicio DSP-CS: $e',
      });

      if (context.mounted) {
        _navigateToError(context, '$e');
      }
    }
  }

  /// Extrae los datos de DRES del response para usarlos en la impresión
  void _extractDresData(DspCsTransaccionResponseModel model) {
    _dresDataList = [];

    final services = model.data?.services ?? {};
    if (services.containsKey('dres_cons')) {
      final step = services['dres_cons']!;
      final dataList = step.dataAsList;

      if (step.errorCode == 0 && dataList != null && dataList.isNotEmpty) {
        for (final item in dataList) {
          if (item is Map<String, dynamic>) {
            _dresDataList.add(DspCsDresConsItem.fromJson(item));
          }
        }
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
      _imprimirTicketDspCs(manager, appManager),
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
      _log.logWarning('DSPCS_GATE_OPEN_FAILED', {'error': '$e'});
    }
  }

  Future<void> _imprimirTicketDspCs(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) async {
    try {
      final ticketData = TicketDspCsModel(
        atkId: int.tryParse(manager.atkId ?? '0') ?? 0,
        turno: manager.turno ?? '',
        placa: manager.vehiculoPlaca ?? '',
        programado: manager.ponchadoFechaProgramado ?? '',
        entrada: _formatearFechaActual(),
        apellidos: '',
        nombres: manager.driverName ?? '',
      );

      await PrintService.printDspCsTicket(
        ticketData: ticketData,
        dresData: _dresDataList.isNotEmpty ? _dresDataList : null,
        saveToSpecificPath: true,
        autoPrint: true,
      );
    } catch (e, st) {
      _log.logError('DSPCS_PRINT_TICKET_ERROR', e, st);
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
