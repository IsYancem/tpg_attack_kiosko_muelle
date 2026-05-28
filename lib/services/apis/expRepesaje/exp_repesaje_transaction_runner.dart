// lib/services/apis/expRepesaje/exp_repesaje_transaction_runner.dart
// Autor: Abraham Yance
//
// Runner dedicado al flujo EXP REPESAJE.
// Orquesta la secuencia:
//   PASO 1 → inicializar
//   PASO 2 → validar-contenedor  (OCR vs DISV local + remoto)
//   PASO 3 → guardar
//   PASO 4 → terminar
//
// Si cualquier paso falla el flujo se detiene y se navega a ErrorScreen.
// La clase de confirm anterior (ConfirmService) NO se usa aquí.

import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/ocrScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/error_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/expRepesaje/exp_muelle_repesaje_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/gate_control_service.dart';

class ExpRespesajeTransactionRunner {
  ExpRespesajeTransactionRunner();

  final ExpMuelleRepesajeService _svc = ExpMuelleRepesajeService();
  final _log = LogService.instance;

  Future<void> run({
    required BuildContext context,
    required AppStateManager appManager,
    required AtkTransactionManager manager,
  }) async {
    final sw = Stopwatch()..start();

    final placa = manager.vehiculoPlaca ?? '';
    final contenedorOcr = (manager.get('contenedor1') as String? ?? '')
        .trim()
        .toUpperCase();
    final solicitudId = manager.expoRepesajeSolicitudId;

    await _log.logRequest('EXP_REPESAJE_RUNNER_START', {
      'placa': placa,
      'driverCedula': manager.driverCedula,
      'contenedorOcr': contenedorOcr,
      'solicitudId': solicitudId,
      'solicitudEstado': manager.expoRepesajeSolicitudEstado,
      'solicitudNuevoDisv': manager.expoRepesajeSolicitudNuevoDisv,
      'tipoOperacion': manager.expoRepesajeTipoOperacion,
      'atkId': manager.atkId,
    });

    try {
      // ── VALIDACIÓN PREVIA ──────────────────────────────────────────────────
      if (contenedorOcr.isEmpty) {
        throw ExpMuelleRepesajeServiceException(
          'No se encontró contenedor OCR para procesar el repesaje.',
        );
      }

      // ══════════════════════════════════════════════════════════════════════
      // PASO 1: INICIALIZAR
      // ══════════════════════════════════════════════════════════════════════
      manager.setMany({
        'isLoading': true,
        'mensajeInferior':
            'Inicializando transacción EXP...\nContenedor: $contenedorOcr',
        'transactionType': 'EXP_REPESAJE',
        'muelleTransactionCode': 'EXP_REPESAJE',
        'muelleTransactionName': 'Exportación Repesaje',
      });

      await _log.logRequest('EXP_REPESAJE_RUNNER_PASO1_START', {
        'placa': placa,
        'contenedor': contenedorOcr,
      });

      final inicializarRes = await _svc.inicializar(
        manager: manager,
        appManager: appManager,
      );

      await _log.logRequest('EXP_REPESAJE_RUNNER_PASO1_OK', {
        'numtrans': inicializarRes.data?.numtrans,
        'estado': inicializarRes.data?.estado,
        'contenedorDisv': inicializarRes.data?.contenedor,
        'tara': inicializarRes.data?.tara,
        'isSalida': inicializarRes.data?.isSalida,
      });

      if (!context.mounted) return;

      // ══════════════════════════════════════════════════════════════════════
      // PASO 2: VALIDAR CONTENEDOR (OCR vs DISV)
      // ══════════════════════════════════════════════════════════════════════
      manager.setManyWithoutNotify({
        'isLoading': true,
        'mensajeInferior':
            'Validando contenedor con DISV...\nOCR: $contenedorOcr',
      });

      await _log.logRequest('EXP_REPESAJE_RUNNER_PASO2_START', {
        'contenedorOcr': contenedorOcr,
        'contenedorDisv': inicializarRes.data?.contenedor,
      });

      final validarRes = await _svc.validarContenedor(
        manager: manager,
        appManager: appManager,
      );

      await _log.logRequest('EXP_REPESAJE_RUNNER_PASO2_OK', {
        'esValido': validarRes.data?.esValido,
        'contenedorValidado': validarRes.data?.contenedorValidado,
      });

      if (!context.mounted) return;

      // ══════════════════════════════════════════════════════════════════════
      // PASO 3: GUARDAR
      // ══════════════════════════════════════════════════════════════════════
      manager.setManyWithoutNotify({
        'isLoading': true,
        'mensajeInferior':
            'Guardando transacción EXP...\nPeso: ${manager.pesoActualBascula} kg',
      });

      await _log.logRequest('EXP_REPESAJE_RUNNER_PASO3_START', {
        'contenedor': contenedorOcr,
        'pesoIngreso': manager.pesoActualBascula,
        'tara': manager.pesoTara,
        'atkId': manager.atkId,
      });

      final guardarRes = await _svc.guardar(
        manager: manager,
        appManager: appManager,
      );

      await _log.logRequest('EXP_REPESAJE_RUNNER_PASO3_OK', {
        'numero': guardarRes.data?.numero,
        'contenedorValidadoDisv': guardarRes.data?.contenedorValidadoDisv,
        'enListaNegra': guardarRes.data?.enListaNegra,
      });

      if (!context.mounted) return;

      // ══════════════════════════════════════════════════════════════════════
      // PASO 4: TERMINAR
      // ══════════════════════════════════════════════════════════════════════
      manager.setManyWithoutNotify({
        'isLoading': true,
        'mensajeInferior': 'Finalizando transacción...\nPor favor espere.',
      });

      await _log.logRequest('EXP_REPESAJE_RUNNER_PASO4_START', {
        'atkId': manager.atkId,
        'pesoIngreso': manager.pesoActualBascula,
      });

      final terminarRes = await _svc.terminar(
        manager: manager,
        appManager: appManager,
      );

      await _log.logRequest('EXP_REPESAJE_RUNNER_PASO4_OK', {
        'estado': terminarRes.data?.estado,
        'isAutorizado': terminarRes.data?.isAutorizado,
        'isBloqueado': terminarRes.data?.isBloqueado,
      });

      if (!context.mounted) return;

      // ══════════════════════════════════════════════════════════════════════
      // FINALIZAR
      // ══════════════════════════════════════════════════════════════════════
      sw.stop();

      final estadoFinal = terminarRes.data?.estado ?? 'PROCESADO';

      manager.setMany({
        'isLoading': false,
        'mensajeInferior': 'Transacción completada.\nEstado: $estadoFinal',
        'transaccionActiva': false,
        'ocrConfirmOk': true,
        'expoRepesajeConfirmOk': true,
      });

      await _log.logRequest('EXP_REPESAJE_RUNNER_DONE', {
        'elapsedMs': sw.elapsedMilliseconds,
        'placa': placa,
        'contenedor': contenedorOcr,
        'numtrans': inicializarRes.data?.numtrans,
        'estadoFinal': estadoFinal,
      });

      if (!context.mounted) return;

      manager.setMany({
        'isLoading': true,
        'mensajeInferior': 'Transacción completada.\nAbriendo barrera...',
        'expRepesajeGateOpenRequested': false,
        'expRepesajeGateOpenOk': false,
        'expRepesajeGateOpenGate': null,
        'expRepesajeGateOpenSide': null,
      });

      await _openGateAfterSuccess(appManager: appManager, manager: manager);

      if (!context.mounted) return;

      manager.setMany({
        'isLoading': false,
        'mensajeInferior': 'Repesaje completado. Barrera abierta.',
        'expRepesajeGateOpenOk': true,
      });

      const totalSeconds = 10;

      for (int i = totalSeconds; i >= 0; i--) {
        if (!context.mounted) return;

        manager.setFlowRemainingSeconds(i);

        if (i == 0) break;
        await Future.delayed(const Duration(seconds: 1));
      }

      await _log.logRequest('EXP_REPESAJE_AUTO_EXIT', {
        'after_seconds': totalSeconds,
        'placa': manager.vehiculoPlaca,
        'contenedor': manager.get('contenedor1'),
        'rfidGate': manager.get('rfidGate'),
        'side': manager.get('side'),
        'doorNumber': manager.get('doorNumber'),
        'expRepesajeGateOpenRequested': manager.get(
          'expRepesajeGateOpenRequested',
        ),
        'expRepesajeGateOpenOk': manager.get('expRepesajeGateOpenOk'),
        'expRepesajeGateOpenGate': manager.get('expRepesajeGateOpenGate'),
        'expRepesajeGateOpenSide': manager.get('expRepesajeGateOpenSide'),
      });

      manager.resetAll();
      manager.setFlowRemainingSeconds(null);

      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const OcrScannerScreen(),
          transitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
        (route) => false,
      );
    } catch (e, st) {
      sw.stop();
      await _log.logError('EXP_REPESAJE_RUNNER_ERROR', e, st);

      String errorMsg;

      if (e is ExpMuelleRepesajeServiceException) {
        errorMsg = e.message;
        await _log.logRequest('EXP_REPESAJE_RUNNER_STEP_FAILED', {
          'step': e.step,
          'message': e.message,
          'elapsedMs': sw.elapsedMilliseconds,
        });
      } else {
        errorMsg = e is Exception
            ? e.toString().replaceAll('Exception: ', '')
            : e.toString();
      }

      manager.setMany({
        'isLoading': false,
        'hasError': true,
        'errorMessage': errorMsg,
        'ocrConfirmOk': false,
        'expoRepesajeConfirmOk': false,
      });

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => ErrorScreen(error: errorMsg),
            transitionDuration: const Duration(milliseconds: 150),
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
          ),
          (route) => false,
        );
      }
    }
  }

  Future<void> _openGateAfterSuccess({
    required AppStateManager appManager,
    required AtkTransactionManager manager,
  }) async {
    final kioskCfg = appManager.kioskConfig;
    final gateCfg = appManager.gateConfig;

    final url = _s(kioskCfg?.controlGateService);

    // Header: va como headers['api-key']
    final headerApiKey = _s(gateCfg?.apiKey);

    // Body: va dentro del JSON base64: {"gate": 92, "api_key": keyPlc, "side": 1}
    final bodyApiKey = _s(gateCfg?.keyPlc);

    final gate = _rfidGate(manager);

    // IMPORTANTE:
    // Según tu regla, en EXP REPESAJE siempre abrimos side 1.
    const side = 1;

    await _log.logRequest('EXP_REPESAJE_GATE_OPEN_START', {
      'url': url,
      'urlSource': 'kioskConfig.controlGateService',
      'gate': gate,
      'side': side,
      'sideRule': 'EXP_REPESAJE siempre side=1',
      'headerApiKeySource': 'gateConfig.apiKey',
      'bodyApiKeySource': 'gateConfig.keyPlc',
      'managerRfidGate': manager.get('rfidGate'),
      'managerSide': manager.get('side'),
      'managerDoorNumber': manager.get('doorNumber'),
      'sideGate': manager.sideGate,
      'kioskControlGateService': kioskCfg?.controlGateService,
      'gateConfigApiKeyLen': headerApiKey.length,
      'gateConfigKeyPlcLen': bodyApiKey.length,
      'hasUrl': url.isNotEmpty,
      'hasHeaderApiKey': headerApiKey.isNotEmpty,
      'hasBodyApiKey': bodyApiKey.isNotEmpty,
      'snapshot': _snapshotExpRepesaje(manager),
    });

    if (url.isEmpty ||
        headerApiKey.isEmpty ||
        bodyApiKey.isEmpty ||
        gate <= 0) {
      await _log.logWarning('EXP_REPESAJE_GATE_OPEN_SKIPPED', {
        'reason': 'Configuración incompleta para abrir barrera',
        'urlEmpty': url.isEmpty,
        'headerApiKeyEmpty': headerApiKey.isEmpty,
        'bodyApiKeyEmpty': bodyApiKey.isEmpty,
        'gate': gate,
        'side': side,
        'kioskControlGateService': kioskCfg?.controlGateService,
        'gateConfigApiKeyLen': headerApiKey.length,
        'gateConfigKeyPlcLen': bodyApiKey.length,
        'managerRfidGate': manager.get('rfidGate'),
        'snapshot': _snapshotExpRepesaje(manager),
      });

      manager.setManyWithoutNotify({
        'expRepesajeGateOpenRequested': true,
        'expRepesajeGateOpenOk': false,
        'expRepesajeGateOpenGate': gate,
        'expRepesajeGateOpenSide': side,
      });

      throw Exception(
        'No se pudo abrir barrera: controlGateService/apiKey/keyPlc/gate no válidos.',
      );
    }

    final opened = await GateControlService.instance.openGate(
      url: url,
      headerApiKey: headerApiKey,
      bodyApiKey: bodyApiKey,
      gateLocation: gate.toString(),
      gate: gate,
      side: side,
    );

    manager.setManyWithoutNotify({
      'expRepesajeGateOpenRequested': true,
      'expRepesajeGateOpenOk': opened,
      'expRepesajeGateOpenGate': gate,
      'expRepesajeGateOpenSide': side,
    });

    await _log.logRequest('EXP_REPESAJE_GATE_OPEN_RESULT', {
      'opened': opened,
      'url': url,
      'gate': gate,
      'side': side,
      'gateLocation': gate.toString(),
      'snapshot': _snapshotExpRepesaje(manager),
    });

    if (!opened) {
      throw Exception('No se pudo abrir la barrera.');
    }
  }

  int _rfidGate(AtkTransactionManager manager) {
    return _int(manager.get('rfidGate')) ?? 0;
  }

  int? _int(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _s(dynamic value) => (value ?? '').toString().trim();

  Map<String, dynamic> _snapshotExpRepesaje(AtkTransactionManager manager) {
    return {
      'vehiculoPlaca': manager.vehiculoPlaca,
      'contenedor': manager.contenedor,
      'contenedor1': manager.get('contenedor1'),
      'contenedor2': manager.get('contenedor2'),
      'ocrContainerNumbers': manager.get('ocrContainerNumbers'),
      'ocrContainerCount': manager.get('ocrContainerCount'),
      'pesoActualBascula': manager.pesoActualBascula,
      'pesoIngreso': manager.pesoIngreso,
      'pesoTara': manager.pesoTara,
      'driverCedula': manager.driverCedula,
      'driverName': manager.driverName,
      'transactionType': manager.transactionType,
      'rfidGate': manager.get('rfidGate'),
      'side': manager.get('side'),
      'doorNumber': manager.get('doorNumber'),
      'sideGate': manager.sideGate,
      'expMuelleNumtrans': manager.expMuelleNumtrans,
      'expMuelleEstado': manager.expMuelleEstado,
      'expMuelleGuardarOk': manager.expMuelleGuardarOk,
      'expMuelleTerminarOk': manager.expMuelleTerminarOk,
      'expMuelleTerminarEstado': manager.expMuelleTerminarEstado,
      'expRepesajeGateOpenRequested': manager.get(
        'expRepesajeGateOpenRequested',
      ),
      'expRepesajeGateOpenOk': manager.get('expRepesajeGateOpenOk'),
      'expRepesajeGateOpenGate': manager.get('expRepesajeGateOpenGate'),
      'expRepesajeGateOpenSide': manager.get('expRepesajeGateOpenSide'),
      'isLoading': manager.isLoading,
      'mensajeInferior': manager.mensajeInferior,
      'hasError': manager.hasError,
      'errorMessage': manager.errorMessage,
    };
  }
}
