import 'dart:async';

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
  final LogService _log = LogService.instance;

  static const int _successDelaySeconds = 2;

  Future<void> run({
    required BuildContext context,
    required AppStateManager appManager,
    required AtkTransactionManager manager,
  }) async {
    final sw = Stopwatch()..start();

    final placa = (manager.vehiculoPlaca ?? '').trim().toUpperCase();
    final contenedorOcr = (manager.get('contenedor1') as String? ?? '')
        .trim()
        .toUpperCase();

    _logBg(
      _log.logRequest('EXP_REPESAJE_RUNNER_START', {
        'placa': placa,
        'driverCedula': manager.driverCedula,
        'contenedorOcr': contenedorOcr,
        'contenedorOcrPresente': contenedorOcr.isNotEmpty,
        'solicitudId': manager.expoRepesajeSolicitudId,
        'solicitudEstado': manager.expoRepesajeSolicitudEstado,
        'solicitudNuevoDisv': manager.expoRepesajeSolicitudNuevoDisv,
        'tipoOperacion': manager.expoRepesajeTipoOperacion,
        'atkId': manager.atkId,
      }),
      'EXP_REPESAJE_RUNNER_START_LOG_ERROR',
    );

    try {
      // ⚠️ Antes aquí se lanzaba excepción si contenedorOcr estaba vacío.
      // Ahora el OCR es OPCIONAL: el contenedor puede resolverse desde el DISV
      // que devuelve inicializar(). Solo se registra el estado.
      if (contenedorOcr.isEmpty) {
        _logBg(
          _log.logRequest('EXP_REPESAJE_RUNNER_SIN_CONTENEDOR_OCR', {
            'placa': placa,
            'nota':
                'OCR no entregó contenedor. Se intentará resolver por DISV en inicializar().',
          }),
          'EXP_REPESAJE_RUNNER_SIN_CONTENEDOR_OCR_LOG_ERROR',
        );
      }

      manager.setManyWithoutNotify({
        'isLoading': true,
        'mensajeInferior': 'Procesando repesaje exportación...',
        'transactionType': 'EXP_REPESAJE',
        'muelleTransactionCode': 'EXP_REPESAJE',
        'muelleTransactionName': 'Exportación Repesaje',
      });

      // ══════════════════════════════════════════════════════════════════════
      // PASO 1: INICIALIZAR
      // ══════════════════════════════════════════════════════════════════════
      _logBg(
        _log.logRequest('EXP_REPESAJE_RUNNER_PASO1_START', {
          'placa': placa,
          'contenedorOcr': contenedorOcr,
        }),
        'EXP_REPESAJE_RUNNER_PASO1_START_LOG_ERROR',
      );

      final inicializarRes = await _svc.inicializar(
        manager: manager,
        appManager: appManager,
      );

      _logBg(
        _log.logRequest('EXP_REPESAJE_RUNNER_PASO1_OK', {
          'numtrans': inicializarRes.data?.numtrans,
          'estado': inicializarRes.data?.estado,
          'contenedorDisv': inicializarRes.data?.contenedor,
          'tara': inicializarRes.data?.tara,
          'isSalida': inicializarRes.data?.isSalida,
        }),
        'EXP_REPESAJE_RUNNER_PASO1_OK_LOG_ERROR',
      );

      if (!context.mounted) return;

      // ══════════════════════════════════════════════════════════════════════
      // RESOLVER CONTENEDOR DE TRABAJO (OCR opcional)
      // OCR si vino; si no, el del DISV devuelto por inicializar().
      // ══════════════════════════════════════════════════════════════════════
      final contenedorDisv = (inicializarRes.data?.contenedor ?? '')
          .trim()
          .toUpperCase();

      final contenedorTrabajo = contenedorOcr.isNotEmpty
          ? contenedorOcr
          : contenedorDisv;

      if (contenedorTrabajo.isEmpty) {
        throw ExpMuelleRepesajeServiceException(
          'No se encontró contenedor para el repesaje (ni por OCR ni por DISV).',
          step: 'RESOLVER_CONTENEDOR',
        );
      }

      // Si el OCR no dio contenedor, se adopta el del DISV para que guardar()
      // y terminar() (que leen de manager) lo tengan disponible.
      if (contenedorOcr.isEmpty) {
        manager.setManyWithoutNotify({
          'contenedor1': contenedorTrabajo,
          'contenedorExp': contenedorTrabajo,
          'expRepesajeContenedorDesdeDisv': true,
        });

        _logBg(
          _log.logRequest('EXP_REPESAJE_RUNNER_CONTENEDOR_ADOPTADO_DISV', {
            'contenedorDisv': contenedorDisv,
            'contenedorTrabajo': contenedorTrabajo,
          }),
          'EXP_REPESAJE_RUNNER_CONTENEDOR_ADOPTADO_DISV_LOG_ERROR',
        );
      }

      // ══════════════════════════════════════════════════════════════════════
      // PASO 2: VALIDACIÓN LOCAL OCR VS DISV (solo si el OCR trajo contenedor)
      // ══════════════════════════════════════════════════════════════════════
      _validarContenedorLocalOrFail(
        contenedorOcr: contenedorOcr,
        contenedorDisv: contenedorDisv,
      );

      manager.setManyWithoutNotify({
        'expMuelleContenedorValidado': contenedorTrabajo,
        'expMuelleValidarContenedorOk': true,
      });

      _logBg(
        _log.logRequest('EXP_REPESAJE_RUNNER_PASO2_LOCAL_OK', {
          'contenedorOcr': contenedorOcr,
          'contenedorDisv': contenedorDisv,
          'contenedorTrabajo': contenedorTrabajo,
          'ocrOpcional': contenedorOcr.isEmpty,
          'nota':
              'OCR opcional. Se omite HTTP validar-contenedor; guardar valida en backend.',
        }),
        'EXP_REPESAJE_RUNNER_PASO2_LOCAL_OK_LOG_ERROR',
      );

      if (!context.mounted) return;

      // ══════════════════════════════════════════════════════════════════════
      // PASO 3: GUARDAR
      // ══════════════════════════════════════════════════════════════════════
      manager.setManyWithoutNotify({
        'isLoading': true,
        'mensajeInferior': 'Guardando repesaje exportación...',
      });

      _logBg(
        _log.logRequest('EXP_REPESAJE_RUNNER_PASO3_START', {
          'contenedor': contenedorTrabajo,
          'pesoIngreso': manager.pesoActualBascula,
          'tara': manager.pesoTara,
          'atkId': manager.atkId,
          'ocrDiSvVehicleAccessId': manager.get('ocrDiSvVehicleAccessId'),
        }),
        'EXP_REPESAJE_RUNNER_PASO3_START_LOG_ERROR',
      );

      final guardarRes = await _svc.guardar(
        manager: manager,
        appManager: appManager,
      );

      _logBg(
        _log.logRequest('EXP_REPESAJE_RUNNER_PASO3_OK', {
          'numero': guardarRes.data?.numero,
          'contenedorValidadoDisv': guardarRes.data?.contenedorValidadoDisv,
          'enListaNegra': guardarRes.data?.enListaNegra,
        }),
        'EXP_REPESAJE_RUNNER_PASO3_OK_LOG_ERROR',
      );

      if (!context.mounted) return;

      // ══════════════════════════════════════════════════════════════════════
      // PASO 4: TERMINAR
      // ══════════════════════════════════════════════════════════════════════
      manager.setManyWithoutNotify({
        'isLoading': true,
        'mensajeInferior': 'Finalizando repesaje exportación...',
      });

      _logBg(
        _log.logRequest('EXP_REPESAJE_RUNNER_PASO4_START', {
          'atkId': manager.atkId,
          'ocrDiSvVehicleAccessId': manager.get('ocrDiSvVehicleAccessId'),
          'pesoIngreso': manager.pesoActualBascula,
        }),
        'EXP_REPESAJE_RUNNER_PASO4_START_LOG_ERROR',
      );

      final terminarRes = await _svc.terminar(
        manager: manager,
        appManager: appManager,
      );

      _logBg(
        _log.logRequest('EXP_REPESAJE_RUNNER_PASO4_OK', {
          'estado': terminarRes.data?.estado,
          'isAutorizado': terminarRes.data?.isAutorizado,
          'isBloqueado': terminarRes.data?.isBloqueado,
        }),
        'EXP_REPESAJE_RUNNER_PASO4_OK_LOG_ERROR',
      );

      if (!context.mounted) return;

      sw.stop();

      final estadoFinal = terminarRes.data?.estado ?? 'PROCESADO';

      manager.setManyWithoutNotify({
        'isLoading': true,
        'mensajeInferior': 'Repesaje completado. Abriendo barrera...',
        'transaccionActiva': false,
        'ocrConfirmOk': true,
        'expoRepesajeConfirmOk': true,
        'expRepesajeGateOpenRequested': false,
        'expRepesajeGateOpenOk': false,
        'expRepesajeGateOpenGate': null,
        'expRepesajeGateOpenSide': null,
      });

      _logBg(
        _log.logRequest('EXP_REPESAJE_RUNNER_DONE', {
          'elapsedMs': sw.elapsedMilliseconds,
          'placa': placa,
          'contenedor': contenedorTrabajo,
          'numtrans': inicializarRes.data?.numtrans,
          'estadoFinal': estadoFinal,
        }),
        'EXP_REPESAJE_RUNNER_DONE_LOG_ERROR',
      );

      // ══════════════════════════════════════════════════════════════════════
      // PASO 5: ABRIR BARRERA
      // ══════════════════════════════════════════════════════════════════════
      await _openGateAfterSuccess(appManager: appManager, manager: manager);

      if (!context.mounted) return;

      manager.setManyWithoutNotify({
        'isLoading': false,
        'mensajeInferior': 'Repesaje completado. Barrera abierta.',
        'expRepesajeGateOpenOk': true,
        'flowRemainingSeconds': _successDelaySeconds,
      });

      await Future.delayed(const Duration(seconds: _successDelaySeconds));

      manager.setFlowRemainingSeconds(null);

      _logBg(
        _log.logRequest('EXP_REPESAJE_AUTO_EXIT', {
          'after_seconds': _successDelaySeconds,
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
        }),
        'EXP_REPESAJE_AUTO_EXIT_LOG_ERROR',
      );

      manager.resetAll();
      manager.setFlowRemainingSeconds(null);

      if (!context.mounted) return;

      _navigateToOcr(context);
    } catch (e, st) {
      sw.stop();

      await _log.logError('EXP_REPESAJE_RUNNER_ERROR', e, st);

      final errorMsg = _resolveErrorMessage(e);

      if (e is ExpMuelleRepesajeServiceException) {
        _logBg(
          _log.logRequest('EXP_REPESAJE_RUNNER_STEP_FAILED', {
            'step': e.step,
            'message': e.message,
            'elapsedMs': sw.elapsedMilliseconds,
          }),
          'EXP_REPESAJE_RUNNER_STEP_FAILED_LOG_ERROR',
        );
      }

      manager.setManyWithoutNotify({
        'isLoading': false,
        'hasError': true,
        'errorMessage': errorMsg,
        'ocrConfirmOk': false,
        'expoRepesajeConfirmOk': false,
        'transaccionActiva': false,
      });

      if (!context.mounted) return;

      _navigateToError(context, errorMsg);
    }
  }

  void _validarContenedorLocalOrFail({
    required String contenedorOcr,
    required String? contenedorDisv,
  }) {
    final ocr = contenedorOcr.trim().toUpperCase();
    final disv = (contenedorDisv ?? '').trim().toUpperCase();

    // OCR OPCIONAL: si no vino contenedor por OCR, no hay nada que comparar.
    // El flujo continúa con el contenedor del DISV.
    if (ocr.isEmpty) {
      return;
    }

    // Si hay OCR y DISV, deben coincidir.
    if (disv.isNotEmpty && ocr != disv) {
      throw ExpMuelleRepesajeServiceException(
        'El contenedor leído por OCR ($ocr) no coincide con el contenedor del DISV ($disv).',
        step: 'VALIDAR_CONTENEDOR_LOCAL',
      );
    }
  }

  Future<void> _openGateAfterSuccess({
    required AppStateManager appManager,
    required AtkTransactionManager manager,
  }) async {
    final kioskCfg = appManager.kioskConfig;
    final gateCfg = appManager.gateConfig;

    final url = _s(kioskCfg?.controlGateService);
    final headerApiKey = _s(gateCfg?.apiKey);
    final bodyApiKey = _s(gateCfg?.keyPlc);
    final gate = _rfidGate(manager);

    // Regla de negocio: EXP REPESAJE siempre side 1.
    const side = 1;

    _logBg(
      _log.logRequest('EXP_REPESAJE_GATE_OPEN_START', {
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
      }),
      'EXP_REPESAJE_GATE_OPEN_START_LOG_ERROR',
    );

    if (url.isEmpty ||
        headerApiKey.isEmpty ||
        bodyApiKey.isEmpty ||
        gate <= 0) {
      manager.setManyWithoutNotify({
        'expRepesajeGateOpenRequested': true,
        'expRepesajeGateOpenOk': false,
        'expRepesajeGateOpenGate': gate,
        'expRepesajeGateOpenSide': side,
      });

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

    _logBg(
      _log.logRequest('EXP_REPESAJE_GATE_OPEN_RESULT', {
        'opened': opened,
        'url': url,
        'gate': gate,
        'side': side,
        'gateLocation': gate.toString(),
        'snapshot': _snapshotExpRepesaje(manager),
      }),
      'EXP_REPESAJE_GATE_OPEN_RESULT_LOG_ERROR',
    );

    if (!opened) {
      throw Exception('No se pudo abrir la barrera.');
    }
  }

  void _navigateToOcr(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const OcrScannerScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (_, __, ___, child) => child,
      ),
      (route) => false,
    );
  }

  void _navigateToError(BuildContext context, String errorMsg) {
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ErrorScreen(error: errorMsg),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (_, __, ___, child) => child,
      ),
      (route) => false,
    );
  }

  void _logBg(Future<dynamic> future, String tag) {
    unawaited(
      future.catchError((error, stackTrace) async {
        await _log.logError(tag, error, stackTrace);
      }),
    );
  }

  String _resolveErrorMessage(Object error) {
    if (error is ExpMuelleRepesajeServiceException) {
      return error.message;
    }

    return error
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('Error::', '')
        .replaceAll('Error:', '')
        .trim();
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
