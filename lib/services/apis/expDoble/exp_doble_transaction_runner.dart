// lib/services/apis/expDoble/exp_doble_transaction_runner.dart
// Runner dedicado al flujo EXP DOBLE / EXP estándar.
// Itera sobre la lista ocrExpMovements e invoca confirm una vez
// por cada movimiento EXP, tratando cada uno como entidad separada.

import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/error_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/confirm_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';

// Resultado de un confirm individual por movimiento EXP.
class ExpDobleConfirmResult {
  final int index;
  final Map<String, dynamic> movement;
  final bool ok;
  final String? atkId;
  final String? title;
  final String? errorMessage;
  final Map<String, dynamic>? confirmResponse;
  final int elapsedMs;

  const ExpDobleConfirmResult({
    required this.index,
    required this.movement,
    required this.ok,
    this.atkId,
    this.title,
    this.errorMessage,
    this.confirmResponse,
    required this.elapsedMs,
  });

  Map<String, dynamic> toJson() => {
        'index': index,
        'movement': movement,
        'ok': ok,
        if (atkId != null) 'atkId': atkId,
        if (title != null) 'title': title,
        if (errorMessage != null) 'errorMessage': errorMessage,
        'elapsedMs': elapsedMs,
      };
}

class ExpDobleTransactionRunner {
  ExpDobleTransactionRunner();

  final ConfirmService _confirmSvc = ConfirmService();

  Future<void> run({
    required BuildContext context,
    required AppStateManager appManager,
    required AtkTransactionManager manager,
  }) async {
    final sw = Stopwatch()..start();

    final placa = manager.vehiculoPlaca ?? '';
    final contenedor1 = manager.contenedor1 ?? '';
    final contenedor2 = manager.contenedor2 ?? '';

    // Leer la lista de movimientos EXP guardada por OcrScannerScreen.
    final rawMovements =
        manager.get('ocrExpMovements') as List<dynamic>? ?? [];

    final movements = rawMovements
        .whereType<Map<String, dynamic>>()
        .toList();

    final totalMovements = movements.length;

    await LogService.instance.logRequest('EXP_DOBLE_RUNNER_START', {
      'placa': placa,
      'driverCedula': manager.driverCedula,
      'contenedor1': contenedor1,
      'contenedor2': contenedor2,
      'totalExpMovements': totalMovements,
      'atkId': manager.atkId,
    });

    try {
      if (movements.isEmpty) {
        throw Exception(
          'No se encontraron movimientos EXP para procesar en la transacción.',
        );
      }

      // PASO 1: Marcar inicio
      manager.setMany({
        'isLoading': true,
        'mensajeInferior':
            'Procesando $totalMovements transacción${totalMovements > 1 ? 'es' : ''} EXP...\nPor favor espere.',
        'transactionType': 'EXP',
        'muelleTransactionCode': 'EXP',
        'expDobleTotal': totalMovements,
        'expDobleProcesadas': 0,
        'expDobleResultados': <Map<String, dynamic>>[],
      });

      // PASO 2: Confirm por cada movimiento EXP
      final resultados = <ExpDobleConfirmResult>[];

      for (int i = 0; i < movements.length; i++) {
        if (!context.mounted) break;

        final movement = movements[i];
        final tipoMov = movement['tipoMov']?.toString() ?? 'EXP';
        final numTransaccion = movement['numTransaccion']?.toString() ??
            movement['num_transaccion']?.toString() ??
            movement['correlativo']?.toString() ??
            '${i + 1}';

        final stepSw = Stopwatch()..start();

        await LogService.instance.logRequest(
          'EXP_DOBLE_RUNNER_CONFIRM_STEP_START',
          {
            'index': i,
            'total': totalMovements,
            'tipoMov': tipoMov,
            'numTransaccion': numTransaccion,
            'movement': movement,
          },
        );

        // Marcar progreso visual
        manager.setManyWithoutNotify({
          'isLoading': true,
          'mensajeInferior':
              'Confirmando transacción ${i + 1} de $totalMovements...\n'
              'Tipo: $tipoMov  |  N°: $numTransaccion',
          'expDobleProcesadas': i,
          // Guardar el movimiento activo para que el confirm sepa cuál procesar.
          'movement_active': movement,
          'expDobleMovimientoActual': movement,
          'expDobleMovimientoIndex': i,
        });

        try {
          final confirmRes = await _confirmSvc.ejecutarConfirmMuelle(
            manager,
            appManager,
            tipoMov,
          );

          stepSw.stop();

          // Si el manager tiene error después del confirm, registrarlo
          // pero continuar con los demás movimientos.
          if (manager.hasError) {
            final errMsg = manager.errorMessage ?? 'Error en movimiento $numTransaccion';

            await LogService.instance.logWarning(
              'EXP_DOBLE_RUNNER_CONFIRM_STEP_MANAGER_ERROR',
              {
                'index': i,
                'numTransaccion': numTransaccion,
                'errorMessage': errMsg,
              },
            );

            resultados.add(ExpDobleConfirmResult(
              index: i,
              movement: movement,
              ok: false,
              errorMessage: errMsg,
              confirmResponse: confirmRes,
              elapsedMs: stepSw.elapsedMilliseconds,
            ));

            // Limpiar error del manager para no bloquear los siguientes.
            manager.clearError();
            continue;
          }

          // Extraer atkId y title del confirm exitoso.
          final cola = confirmRes['data']?['services']?['getCola']?['data']
              as Map<String, dynamic>?;
          final atkId = (cola?['atk_id'] ?? '').toString().trim();

          final catalogo =
              confirmRes['data']?['services']?['catalogoTitulo']?['data']
                  as Map<String, dynamic>?;
          final title = (catalogo?['title'] ?? '').toString().trim();

          final resultado = ExpDobleConfirmResult(
            index: i,
            movement: movement,
            ok: true,
            atkId: atkId.isNotEmpty ? atkId : null,
            title: title.isNotEmpty ? title : null,
            confirmResponse: confirmRes,
            elapsedMs: stepSw.elapsedMilliseconds,
          );

          resultados.add(resultado);

          // Si es el primer confirm exitoso, guardar atkId principal.
          if (i == 0 && atkId.isNotEmpty) {
            manager.setManyWithoutNotify({
              'atkId': atkId,
              'tituloPantalla': title.isNotEmpty ? title : 'EXP',
            });
          }

          await LogService.instance.logRequest(
            'EXP_DOBLE_RUNNER_CONFIRM_STEP_OK',
            {
              'index': i,
              'numTransaccion': numTransaccion,
              'atkId': atkId,
              'title': title,
              'elapsedMs': stepSw.elapsedMilliseconds,
            },
          );
        } catch (e, st) {
          stepSw.stop();

          await LogService.instance.logError(
            'EXP_DOBLE_RUNNER_CONFIRM_STEP_EXCEPTION',
            e,
            st,
          );

          resultados.add(ExpDobleConfirmResult(
            index: i,
            movement: movement,
            ok: false,
            errorMessage: e.toString(),
            elapsedMs: stepSw.elapsedMilliseconds,
          ));

          // Limpiar y continuar con el siguiente.
          manager.clearError();
        }
      }

      // PASO 3: Consolidar resultados
      sw.stop();

      final exitosas = resultados.where((r) => r.ok).length;
      final fallidas = resultados.where((r) => !r.ok).length;

      final resultadosJson = resultados.map((r) => r.toJson()).toList();

      manager.setMany({
        'isLoading': false,
        'mensajeInferior':
            'Procesamiento completado.\n$exitosas de $totalMovements transacciones confirmadas.',
        'transaccionActiva': true,
        'expDobleTotal': totalMovements,
        'expDobleProcesadas': totalMovements,
        'expDobleExitosas': exitosas,
        'expDobleFallidas': fallidas,
        'expDobleResultados': resultadosJson,
        'ocrConfirmOk': exitosas > 0,
      });

      await LogService.instance.logRequest('EXP_DOBLE_RUNNER_DONE', {
        'elapsedMs': sw.elapsedMilliseconds,
        'totalMovements': totalMovements,
        'exitosas': exitosas,
        'fallidas': fallidas,
        'resultados': resultadosJson,
      });

      // Si TODAS fallaron, navegar a error.
      if (exitosas == 0) {
        final primerError = resultados.isNotEmpty
            ? (resultados.first.errorMessage ?? 'Error en todas las transacciones EXP')
            : 'No se procesó ninguna transacción EXP';

        throw Exception(primerError);
      }

    } catch (e, st) {
      sw.stop();
      await LogService.instance.logError('EXP_DOBLE_RUNNER_ERROR', e, st);

      final errorMsg = e is Exception
          ? e.toString().replaceAll('Exception: ', '')
          : e.toString();

      manager.setMany({
        'isLoading': false,
        'hasError': true,
        'errorMessage': errorMsg,
        'ocrConfirmOk': false,
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