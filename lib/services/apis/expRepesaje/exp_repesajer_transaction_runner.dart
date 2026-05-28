// lib/services/apis/expRepesaje/exp_repesaje_transaction_runner.dart
// Runner dedicado al flujo EXP REPESAJE.
// Ejecuta UN solo confirm para la solicitud de repesaje activa.

import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/error_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/confirm_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';

class ExpRespesajeTransactionRunner {
  ExpRespesajeTransactionRunner();

  final ConfirmService _confirmSvc = ConfirmService();

  Future<void> run({
    required BuildContext context,
    required AppStateManager appManager,
    required AtkTransactionManager manager,
  }) async {
    final sw = Stopwatch()..start();

    final solicitudId = manager.expoRepesajeSolicitudId;
    final contenedor = manager.contenedor1 ?? manager.expoRepesajeContenedor ?? '';
    final placa = manager.vehiculoPlaca ?? '';

    await LogService.instance.logRequest('EXP_REPESAJE_RUNNER_START', {
      'placa': placa,
      'driverCedula': manager.driverCedula,
      'contenedor': contenedor,
      'solicitudId': solicitudId,
      'solicitudEstado': manager.expoRepesajeSolicitudEstado,
      'solicitudDisv': manager.expoRepesajeSolicitudDisv,
      'solicitudNuevoDisv': manager.expoRepesajeSolicitudNuevoDisv,
      'tipoOperacion': manager.expoRepesajeTipoOperacion,
    });

    try {
      // VALIDACION PREVIA
      if (solicitudId == null || solicitudId.isEmpty) {
        throw Exception(
          'No se encontró solicitud de repesaje activa para el contenedor $contenedor.',
        );
      }

      // PASO 1: Marcar estado visual
      manager.setMany({
        'isLoading': true,
        'mensajeInferior': 'Procesando repesaje...\nSolicitud #$solicitudId activa.',
        'transactionType': 'EXP_REPESAJE',
        'muelleTransactionCode': 'EXP_REPESAJE',
        'muelleTransactionName': 'Exportación Repesaje',
      });

      await LogService.instance.logRequest('EXP_REPESAJE_RUNNER_PASO1_OK', {
        'solicitudId': solicitudId,
        'nuevoDisv': manager.expoRepesajeSolicitudNuevoDisv,
        'estado': manager.expoRepesajeSolicitudEstado,
      });

      // PASO 2: Confirm unico para el repesaje
      manager.setManyWithoutNotify({
        'isLoading': true,
        'mensajeInferior': 'Validando confirmación de repesaje...\nPor favor espere.',
      });

      await LogService.instance.logRequest('EXP_REPESAJE_RUNNER_CONFIRM_START', {
        'placa': placa,
        'solicitudId': solicitudId,
        'contenedor': contenedor,
        'tipoMov': 'EXP_REPESAJE',
      });

      final confirmRes = await _confirmSvc.ejecutarConfirmMuelle(
        manager,
        appManager,
        'EXP_REPESAJE',
      );

      if (manager.hasError) {
        throw Exception(
          manager.errorMessage ?? confirmRes['message'] ?? 'Error en confirm repesaje',
        );
      }

      // PASO 3: Extraer datos del confirm
      final cola = confirmRes['data']?['services']?['getCola']?['data']
          as Map<String, dynamic>?;
      final atkId = (cola?['atk_id'] ?? '').toString().trim();

      final catalogo = confirmRes['data']?['services']?['catalogoTitulo']?['data']
          as Map<String, dynamic>?;
      final title = (catalogo?['title'] ?? '').toString().trim();

      manager.setManyWithoutNotify({
        'atkId': atkId.isNotEmpty ? atkId : manager.atkId,
        'tituloPantalla': title.isNotEmpty ? title : 'Repesaje',
        'ocrConfirmResponse': confirmRes,
        'ocrConfirmOk': true,
        'expoRepesajeConfirmOk': true,
        'expoRepesajeConfirmAtkId': atkId,
        'expoRepesajeConfirmTitle': title,
      });

      await LogService.instance.logRequest('EXP_REPESAJE_RUNNER_CONFIRM_OK', {
        'placa': placa,
        'solicitudId': solicitudId,
        'atkId': atkId,
        'title': title,
        'elapsedMs': sw.elapsedMilliseconds,
      });

      // PASO 4: Finalizar
      sw.stop();

      manager.setMany({
        'isLoading': false,
        'mensajeInferior': 'Repesaje confirmado correctamente.',
        'transaccionActiva': true,
      });

      await LogService.instance.logRequest('EXP_REPESAJE_RUNNER_DONE', {
        'elapsedMs': sw.elapsedMilliseconds,
        'solicitudId': solicitudId,
        'atkId': atkId,
      });
    } catch (e, st) {
      sw.stop();
      await LogService.instance.logError('EXP_REPESAJE_RUNNER_ERROR', e, st);

      final errorMsg = e is Exception
          ? e.toString().replaceAll('Exception: ', '')
          : e.toString();

      manager.setMany({
        'isLoading': false,
        'hasError': true,
        'errorMessage': errorMsg,
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