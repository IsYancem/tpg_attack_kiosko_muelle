// lib/services/apis/dsp_transaction_runner.dart
// OPTIMIZADO 2025-12-17 - Con imagen de mapa en ticket
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/models/dsp/dsp_transaccion_request_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/print/ticket_dsp_model.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/rfidScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/error_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/dsp/dsp_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/image_cache_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/gate_control_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/atk_utils.dart';

class DspTransactionRunner {
  final DspService _dspService;
  final LogService _log;

  static const _progressDelay = Duration(milliseconds: 200);

  DspTransactionRunner({DspService? dspService, LogService? log})
    : _dspService = dspService ?? DspService(),
      _log = log ?? LogService.instance;

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
    await _showProgress(manager, '📋 Preparando solicitud de despacho...');

    final now = DateTime.now()
        .toIso8601String()
        .replaceAll('T', ' ')
        .substring(0, 19);

    final req = DspTransaccionRequestModel(
      ruc_tpg: appManager.kioskConfig!.rucTpg,
      placa: manager.vehiculoPlaca ?? '',
      vehicleAccessId: int.tryParse(manager.atkId ?? '0') ?? 0,
      codchofer: manager.driverId ?? '',
      numregAtk:
          (manager.atkId != null && RegExp(r'^\d+$').hasMatch(manager.atkId!))
          ? manager.atkId!
          : '0',
      peso: manager.pesoActualBascula,
      gate: int.tryParse(appManager.kioskConfig?.gate ?? '0') ?? 0,
      deviceId: appManager.kioskConfig?.gate,
      codEmpresa: appManager.kioskConfig!.gateLetter,
      codEmpresaF: appManager.kioskConfig!.gateLetter,
      cedulaChofer: manager.driverCedula,
      numt: 0,
      now: now,
      patio: appManager.kioskConfig?.patio,
      codProducto: manager.vehiculoProducto,
      codBuque: manager.vehiculoNave,
      bascula: int.tryParse(appManager.kioskConfig?.gate ?? '0'),
      doorNumber: 1,
      doorOut: 2,
      monitorHost: appManager.kioskConfig?.kioskServer,
      monitorPort: appManager.kioskConfig?.kioskServerPort,
    );

    print(req.toJson());
    
    try {
      await _dspService.ejecutarTransaccionDsp(req, manager);

      if (manager.hasError) {
        if (!context.mounted) return;
        _navigateToError(context, manager.errorMessage ?? 'Error');
        return;
      }

      await _showProgress(manager, '🖨️ Preparando comprobante de ingreso...');
      await _showProgress(manager, '🚧 Abriendo barrera de acceso...');
      await _showProgress(manager, '✅ Transacción completada exitosamente');

      manager.setMany({
        'isLoading': false,
        'tituloPantalla': 'DESPACHO FULL',
        'mensajeInferior':
            'Bienvenido, por favor continúe.\nSu comprobante de ingreso puede ser verificado desde la APP de TPG',
      });

      _executeBackgroundTasks(manager, appManager);

      await Future.delayed(const Duration(seconds: 15));

      manager.resetAll();
      manager.setFlowRemainingSeconds(null);

      if (context.mounted) {
        _navigateToRfid(context);
      }
    } catch (e, st) {
      _log.logError('DSP_RUNNER_EX', e, st);

      manager.setMany({
        'isLoading': false,
        'hasError': true,
        'errorMessage': 'Error ejecutando servicio DSP: $e',
        'mensajeInferior': 'Error ejecutando servicio DSP: $e',
      });

      if (context.mounted) {
        _navigateToError(context, '$e');
      }
    }
  }

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
      _imprimirTicketDsp(manager, appManager),
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
      _log.logWarning('DSP_GATE_OPEN_FAILED', {'error': '$e'});
    }
  }

  /// ✅ CORREGIDO: Ahora incluye la imagen del mapa
  Future<void> _imprimirTicketDsp(
    AtkTransactionManager manager,
    AppStateManager appManager,
  ) async {
    try {
      // ✅ Asegurar que tenemos los bytes del mapa si hay URL válida
      if (manager.mapaUrl != null &&
          manager.mapaUrl!.isNotEmpty &&
          !manager.mapaUrl!.contains('not_found') &&
          manager.mapaBytes == null) {
        print(
          '🗺️ [DSP_PRINT] Descargando mapa para ticket: ${manager.mapaUrl}',
        );
        try {
          final bytes = await ImageCacheService.instance.getImage(
            manager.mapaUrl!,
          );
          if (bytes != null) {
            manager.setManyWithoutNotify({'mapaBytes': bytes});
            print('✅ [DSP_PRINT] Mapa descargado: ${bytes.length} bytes');
          }
        } catch (e) {
          print('⚠️ [DSP_PRINT] Error descargando mapa: $e');
        }
      }

      final ticketData = TicketDspModel(
        atkId: int.tryParse(manager.atkId ?? '0') ?? 0,
        turno: manager.turno ?? '',
        placa: manager.vehiculoPlaca ?? '',
        contenedor: manager.contenedor ?? manager.contenedor1 ?? '',
        dres: manager.dres ?? '',
        ubicacion: manager.ubicacion ?? '',
        bloque: manager.ubicacion ?? '',
        programado: manager.ponchadoFechaProgramado ?? '',
        entrada: _formatearFechaActual(),
        apellidos: '',
        nombres: manager.driverName ?? '',
        choferIdentification: manager.driverCedula ?? '',
      );

      // ✅ CORREGIDO: Usar manager.mapaBytes en lugar de null
      await PrintService.printDspTicket(
        ticketData: ticketData,
        mapaImageBytes: manager.mapaBytes,
        saveToSpecificPath: true,
        autoPrint: true,
      );

      print(
        '✅ [DSP_PRINT] Ticket impreso ${manager.mapaBytes != null ? "CON" : "SIN"} mapa',
      );
    } catch (e, st) {
      _log.logError('DSP_PRINT_TICKET_ERROR', e, st);
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
