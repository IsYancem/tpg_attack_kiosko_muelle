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
}
