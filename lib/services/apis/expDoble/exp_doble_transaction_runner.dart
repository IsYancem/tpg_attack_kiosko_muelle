// lib/services/apis/expDoble/exp_doble_transaction_runner.dart
// Autor: Abraham Yance
//
// Runner del flujo EXP DOBLE FULL.
//
// Procesa DOS contenedores de forma secuencial. Por cada contenedor ejecuta el
// ciclo completo contra el controller `exp-muelle-destare`:
//
//   1) confirm-muelle/EXP        (solo si aún no fue confirmado)
//   2) inicializar
//   3) validar-contenedor
//   4) guardar
//   5) terminar
//   6) esperar 3 s  +  limpiar la data de ESA transacción
//   7) repintar la pantalla para el siguiente contenedor
//
// CONTENEDOR 1 (SALIDA): es el contenedor que NO se leyó en el OCR. Su confirm
//   ya fue ejecutado por OcrScannerScreen (RAMA B), por lo que aquí se omite el
//   confirm y se reutiliza la respuesta guardada (`expDobleConfirmSalidaResponse`).
//   Su peso de báscula va en pesoSalida.
//
// CONTENEDOR 2 (ENTRADA): es el contenedor leído por el OCR. Aquí SÍ se ejecuta
//   confirm-muelle/EXP con los datos del segundo contenedor y luego el resto del
//   ciclo. Su peso de báscula va en pesoIngreso.
import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/error_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/confirm_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/expDoble/exp_doble_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';

/// Describe un contenedor a procesar dentro del flujo doble.
class _ContenedorJob {
  final int index; // 0 = SALIDA, 1 = ENTRADA
  final String etiqueta; // 'SALIDA' | 'ENTRADA'
  final String contenedor;
  final int vehicleAccessId;
  final Map<String, dynamic> movement;

  /// Si el confirm ya fue ejecutado fuera del runner (caso SALIDA en OCR).
  final bool confirmHecho;
  final Map<String, dynamic>? confirmResponse;

  const _ContenedorJob({
    required this.index,
    required this.etiqueta,
    required this.contenedor,
    required this.vehicleAccessId,
    required this.movement,
    required this.confirmHecho,
    this.confirmResponse,
  });

  // ?? FIX SALIDA: helper de rol. index 0 = SALIDA, index 1 = ENTRADA.
  bool get esSalida => index == 0;
}

class ExpDobleTransactionRunner {
  ExpDobleTransactionRunner();

  // ?? BYPASS TEMPORAL DE DEPURACIÓN:
  //   Cuando es true, el runner SOLO procesa el primer contenedor (SALIDA)
  //   y omite por completo el segundo (ENTRADA). Sirve para aislar los logs
  //   del primer contenedor. PONER EN false para volver al flujo doble real.
  static const bool _bypassSegundoContenedor = false;

  final ConfirmService _confirmSvc = ConfirmService();
  final ExpDobleService _expSvc = ExpDobleService();

  static const _esperaEntreContenedores = Duration(seconds: 3);

  /// Ejecuta el flujo doble completo.
  Future<void> run({
    required BuildContext context,
    required AppStateManager appManager,
    required AtkTransactionManager manager,
    VoidCallback? onFinished,
  }) async {
    final sw = Stopwatch()..start();

    final placa = manager.vehiculoPlaca ?? '';

    final jobs = _construirJobs(manager);

    await LogService.instance.logRequest('EXP_DOBLE_RUNNER_START', {
      'placa': placa,
      'driverCedula': manager.driverCedula,
      'totalContenedores': jobs.length,
      'bypassSegundo': _bypassSegundoContenedor, // ?? BYPASS
      'jobs': jobs
          .map(
            (j) => {
              'index': j.index,
              'etiqueta': j.etiqueta,
              'contenedor': j.contenedor,
              'vehicleAccessId': j.vehicleAccessId,
              'confirmHecho': j.confirmHecho,
              'esSalida': j.esSalida,
            },
          )
          .toList(),
    });

    try {
      if (jobs.isEmpty) {
        throw Exception(
          'No se identificaron los contenedores para la doble exportación.',
        );
      }

      manager.setMany({
        'isLoading': true,
        'transactionType': 'EXP',
        'muelleTransactionCode': 'EXP',
        'expDobleTotal': jobs.length,
        'expDobleProcesadas': 0,
        'hasError': false,
      });

      for (int i = 0; i < jobs.length; i++) {
        if (!context.mounted) break;

        final job = jobs[i];
        final esUltimo = i == jobs.length - 1;

        await _procesarContenedor(
          context: context,
          appManager: appManager,
          manager: manager,
          job: job,
        );

        // Paso 6 — esperar y limpiar la data de ESTA transacción.
        manager.setMany({
          'isLoading': true,
          'expDobleProcesadas': i + 1,
          'mensajeInferior':
              'Contenedor ${i + 1} de ${jobs.length} (${job.contenedor}) '
              'procesado.\nLimpiando datos...',
        });

        if (!esUltimo) {
          await Future.delayed(_esperaEntreContenedores);
        }
        
        if (!context.mounted) break;

        _limpiarDataTransaccion(manager);

        await LogService.instance.logRequest('EXP_DOBLE_RUNNER_CONT_DONE', {
          'index': job.index,
          'etiqueta': job.etiqueta,
          'contenedor': job.contenedor,
          'esUltimo': esUltimo,
        });

        // Paso 7 — repintar para el siguiente contenedor (si lo hay).
        if (!esUltimo) {
          final siguiente = jobs[i + 1];
          manager.setMany({
            'isLoading': true,
            'expDobleContenedorActivo': siguiente.contenedor,
            'expDobleContenedorIndexActivo': siguiente.index,
            'mensajeInferior':
                'Preparando contenedor ${i + 2} de ${jobs.length}...\n'
                '${siguiente.etiqueta}: ${siguiente.contenedor}',
          });
        }
      }

      sw.stop();

      manager.setMany({
        'isLoading': false,
        'transaccionActiva': true,
        'expDobleProcesadas': jobs.length,
        'mensajeInferior':
            'Doble exportación completada.\n'
            '${jobs.length} contenedores procesados.',
        'ocrConfirmOk': true,
      });

      await LogService.instance.logRequest('EXP_DOBLE_RUNNER_DONE', {
        'elapsedMs': sw.elapsedMilliseconds,
        'totalContenedores': jobs.length,
        'bypassSegundo': _bypassSegundoContenedor, // ?? BYPASS
      });

      if (context.mounted) {
        if (onFinished != null) {
          onFinished();
        }
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

  // ---------------------------------------------------------------------------
  // Procesa UN contenedor: confirm? ? inicializar ? validar ? guardar ? terminar
  // ---------------------------------------------------------------------------
  Future<void> _procesarContenedor({
    required BuildContext context,
    required AppStateManager appManager,
    required AtkTransactionManager manager,
    required _ContenedorJob job,
  }) async {
    // Dejar al manager apuntando a ESTE contenedor
    manager.setMany({
      'isLoading': true,
      'contenedor1': job.contenedor,
      'contenedorExp': job.contenedor,
      'movement_active': job.movement,
      'expDobleMovimientoActual': job.movement,
      'expDobleMovimientoIndex': job.index,
      'expDobleContenedorActivo': job.contenedor,
      'expDobleContenedorIndexActivo': job.index,
      'expDobleVacIdActivo': job.vehicleAccessId,
      // ?? FIX SALIDA: marcar rol del contenedor activo para que el service
      //   decida en qué campo va el peso de báscula (pesoSalida vs pesoIngreso).
      'expDobleEsSalida': job.esSalida,
      if (job.vehicleAccessId > 0) 'atkId': job.vehicleAccessId.toString(),
      if (job.vehicleAccessId > 0)
        'ocrDiSvVehicleAccessId': job.vehicleAccessId.toString(),
      'mensajeInferior':
          '${job.etiqueta}: ${job.contenedor}\nIniciando transacción...',
    });

    // -- PASO 1: CONFIRM (solo si no se hizo antes)
    if (!job.confirmHecho) {
      manager.setMany({
        'isLoading': true,
        'mensajeInferior': '${job.etiqueta}: ${job.contenedor}\nConfirmando...',
      });

      final confirmRaw = await _confirmSvc.ejecutarConfirmMuelle(
        manager,
        appManager,
        'EXP',
      );

      final errorCode = _int(confirmRaw['errorCode']) ?? 1;
      if (errorCode != 0 || manager.hasError) {
        throw Exception(
          manager.errorMessage ??
              (confirmRaw['message']?.toString().isNotEmpty == true
                  ? confirmRaw['message'].toString()
                  : 'Error en confirm EXP del contenedor ${job.contenedor}.'),
        );
      }

      _aplicarDisvDesdeConfirm(confirmRaw, manager, job.contenedor);
    } else {
      // Reutilizar confirm SALIDA
      if (job.confirmResponse != null) {
        _aplicarDisvDesdeConfirm(job.confirmResponse!, manager, job.contenedor);
      }
    }

    // Volver a fijar contenedor + id real por si confirm/inicializar los cambió
    manager.setManyWithoutNotify({
      'contenedor1': job.contenedor,
      'contenedorExp': job.contenedor,
      'expDobleVacIdActivo': job.vehicleAccessId,
      'expDobleEsSalida': job.esSalida, // ?? FIX SALIDA
      if (job.vehicleAccessId > 0) 'atkId': job.vehicleAccessId.toString(),
      if (job.vehicleAccessId > 0)
        'ocrDiSvVehicleAccessId': job.vehicleAccessId.toString(),
      'transactionType': 'EXP',
      'muelleTransactionCode': 'EXP',
    });

    // -- PASO 2: INICIALIZAR
    manager.setMany({
      'isLoading': true,
      'mensajeInferior': '${job.etiqueta}: ${job.contenedor}\nInicializando...',
    });
    await _expSvc.inicializar(manager, appManager);
    _abortarSiError(manager, 'inicializar', job);

    // -- PASO 3: VALIDAR CONTENEDOR
    manager.setMany({
      'isLoading': true,
      'mensajeInferior':
          '${job.etiqueta}: ${job.contenedor}\nValidando contenedor...',
    });
    await _expSvc.validarContenedor(manager, appManager);
    _abortarSiError(manager, 'validar-contenedor', job);

    // -- PASO 4: GUARDAR
    // ?? FIX SALIDA: dejar el peso de báscula en la clave correcta según rol.
    //   SALIDA (index 0)  -> pesoSalida = báscula, pesoIngreso = null
    //   ENTRADA (index 1) -> pesoIngreso = báscula, pesoSalida = null
    manager.setMany({
      'isLoading': true,
      'mensajeInferior': '${job.etiqueta}: ${job.contenedor}\nGuardando...',

      // SALIDA: pesoSalida tiene báscula, pesoIngreso va en 0
      // ENTRADA: pesoIngreso tiene báscula, pesoSalida va en 0
      'pesoIngreso': job.esSalida ? 0.0 : manager.pesoActualBascula,
      'pesoSalida': job.esSalida ? manager.pesoActualBascula : 0.0,
    });
    await _expSvc.guardar(manager, appManager);
    _abortarSiError(manager, 'guardar', job);

    // -- PASO 5: TERMINAR
    manager.setMany({
      'isLoading': true,
      'mensajeInferior': '${job.etiqueta}: ${job.contenedor}\nTerminando...',
    });
    await _expSvc.terminar(manager, appManager);
    _abortarSiError(manager, 'terminar', job);

    await LogService.instance.logRequest('EXP_DOBLE_RUNNER_CONT_OK', {
      'index': job.index,
      'etiqueta': job.etiqueta,
      'contenedor': job.contenedor,
      'esSalida': job.esSalida,
      'atkId': manager.atkId,
    });
  }

  void _abortarSiError(
    AtkTransactionManager manager,
    String paso,
    _ContenedorJob job,
  ) {
    if (manager.hasError) {
      throw Exception(
        manager.errorMessage ??
            'Error en "$paso" del contenedor ${job.contenedor}.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Construye los jobs (SALIDA primero, ENTRADA después) desde el manager.
  // ---------------------------------------------------------------------------
  List<_ContenedorJob> _construirJobs(AtkTransactionManager manager) {
    final jobs = <_ContenedorJob>[];

    final contSalida = (manager.get('expDobleContSalida') as String? ?? '')
        .trim()
        .toUpperCase();
    final contEntrada =
        (manager.get('expDobleContEntrada') as String? ??
                manager.contenedor1 ??
                '')
            .trim()
            .toUpperCase();

    final movSalida =
        (manager.get('expDobleMovSalida') as Map<String, dynamic>?) ??
        (manager.get('movement_active') as Map<String, dynamic>?) ??
        <String, dynamic>{};
    final movEntrada =
        (manager.get('expDobleMovEntrada') as Map<String, dynamic>?) ??
        <String, dynamic>{};

    final vacIdSalida =
        _int(manager.get('expDobleVacIdSalida')) ??
        _extractVacId(movSalida) ??
        _int(manager.atkId) ??
        0;
    final vacIdEntrada =
        _int(manager.get('expDobleVacIdEntrada')) ??
        _extractVacId(movEntrada) ??
        0;

    final confirmSalidaOk =
        (manager.get('expDobleConfirmSalidaOk') as bool?) ?? false;
    final confirmSalidaResp =
        manager.get('expDobleConfirmSalidaResponse') as Map<String, dynamic>?;

    if (contSalida.isNotEmpty) {
      jobs.add(
        _ContenedorJob(
          index: 0,
          etiqueta: 'SALIDA',
          contenedor: contSalida,
          vehicleAccessId: vacIdSalida,
          movement: movSalida,
          confirmHecho: confirmSalidaOk && confirmSalidaResp != null,
          confirmResponse: confirmSalidaResp,
        ),
      );
    }

    // ?? BYPASS TEMPORAL: cuando _bypassSegundoContenedor es true NO se agrega
    //   el job de ENTRADA, así el runner procesa solo la SALIDA.
    if (_bypassSegundoContenedor) {
      LogService.instance.logWarning('EXP_DOBLE_BYPASS_SEGUNDO_CONTENEDOR', {
        'motivo':
            'Bypass de depuración activo: solo se procesa el contenedor SALIDA.',
        'contEntradaOmitido': contEntrada,
        'vacIdEntradaOmitido': vacIdEntrada,
      });
      return jobs;
    }

    if (contEntrada.isNotEmpty && contEntrada != contSalida) {
      jobs.add(
        _ContenedorJob(
          index: 1,
          etiqueta: 'ENTRADA',
          contenedor: contEntrada,
          vehicleAccessId: vacIdEntrada,
          movement: movEntrada,
          confirmHecho: false,
        ),
      );
    }

    return jobs;
  }

  // ---------------------------------------------------------------------------
  // Limpia la data de UNA transacción.
  // ---------------------------------------------------------------------------
  void _limpiarDataTransaccion(AtkTransactionManager manager) {
    manager.reset('exportador');
    manager.reset('expMuelleRepesaje');

    const transientes = <String>[
      'atkId',
      'contenedorExp',
      'pesoTara',
      'pesoIngreso',
      'pesoSalida',
      'sello1Exp',
      'sello2Exp',
      'sello3Exp',
      'sello4Exp',
      'confirmMuelleExpOk',
      'confirmMuelleExpResponse',
      'movement_active',
      'expMuelleInicializarResponse',
      'expMuelleGuardarResponse',
      'expMuelleTerminarResponse',
      'expMuelleGuardarNumero',
      'expMuelleGuardarOk',
      'expMuelleValidarContenedorOk',
      'expMuelleContenedorValidado',
      'errorMessage',
      // ?? FIX SALIDA: limpiar el flag de rol entre contenedores.
      'expDobleEsSalida',
    ];
    for (final k in transientes) {
      manager.set(k, null);
    }

    manager.set('hasError', false);
  }

  // ---------------------------------------------------------------------------
  // Extrae el DISV de la respuesta de confirm (atkPaConsDisvExp1).
  // ---------------------------------------------------------------------------
  void _aplicarDisvDesdeConfirm(
    Map<String, dynamic> raw,
    AtkTransactionManager manager,
    String contenedor,
  ) {
    try {
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
        disv = disvList;
      }

      if (disv.isEmpty) {
        LogService.instance.logWarning('EXP_DOBLE_DISV_EXTRACT_EMPTY', {
          'contenedor': contenedor,
        });
        return;
      }

      String? str(dynamic v) {
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }

      int? intVal(dynamic v) {
        if (v == null) return null;
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString().trim());
      }

      double? dblVal(dynamic v) {
        if (v == null) return null;
        if (v is double) return v;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString().trim().replaceAll(',', '.'));
      }

      final fields = <String, dynamic>{
        if (str(disv['nombre']) != null) 'clienteExp': str(disv['nombre']),
        if (str(disv['tipocarga']) != null)
          'vehiculoTipoCarga': str(disv['tipocarga']),
        if (str(disv['producto']) != null) 'productoExp': str(disv['producto']),
        if (str(disv['booking']) != null) 'bookingExp': str(disv['booking']),
        if (str(disv['nave']) != null) 'naveExp': str(disv['nave']),
        if (str(disv['numcontenedor']) != null)
          'contenedorExp': str(disv['numcontenedor']),
        if (str(disv['sello1']) != null) 'sello1Exp': str(disv['sello1']),
        if (str(disv['sello2']) != null) 'sello2Exp': str(disv['sello2']),
        if (str(disv['sello3']) != null) 'sello3Exp': str(disv['sello3']),
        if (str(disv['sello4']) != null) 'sello4Exp': str(disv['sello4']),
        if (dblVal(disv['tara']) != null && (dblVal(disv['tara']) ?? 0) > 0)
          'pesoTara': disv['tara'].toString(),
        if (str(disv['carga_imo']) != null)
          'vehiculoCargaImo': str(disv['carga_imo']),
        if (str(disv['refrigerado']) != null)
          'vehiculoRefrigerado': str(disv['refrigerado']),
        if (str(disv['observaciones']) != null)
          'vehiculoObservaciones': str(disv['observaciones']),
        if (intVal(disv['aniodisv']) != null)
          'aniodisv': intVal(disv['aniodisv']),
        if (intVal(disv['numdisv']) != null) 'numdisv': intVal(disv['numdisv']),
      };

      manager.setMany(fields);

      LogService.instance.logRequest('EXP_DOBLE_DISV_APPLIED', {
        'contenedor': contenedor,
        'nombre': disv['nombre'],
        'aniodisv': disv['aniodisv'],
        'numdisv': disv['numdisv'],
        'fields': fields.keys.toList(),
      });
    } catch (e, st) {
      LogService.instance.logError('EXP_DOBLE_DISV_EXTRACT_EX', e, st);
    }
  }

  int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }

  int? _extractVacId(Map<String, dynamic> m) {
    if (m.isEmpty) return null;
    final raw =
        m['vehicleAccessId'] ??
        m['vehicle_access_id'] ??
        m['atk_id'] ??
        m['registro'] ??
        m['id'] ??
        (m['raw'] as Map<String, dynamic>?)?['id'];
    final v = int.tryParse(raw?.toString() ?? '');
    return (v != null && v > 0) ? v : null;
  }
}
