// lib/services/apis/res/res_transaction_runner.dart
// Autor: Abraham Yance
// Fecha: 2025-12-29
// Runner: RES (flujo completo automático)
// FLUJO: init -> guardar -> imprimir -> terminar
// REGLA: si cualquier paso falla => cancelar(confirm=true) y detener

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:tpg_attack_kiosko_muelle/models/res/res_models.dart';
import 'package:tpg_attack_kiosko_muelle/models/print/ticket_res_model.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/rfidScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/error_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/res/res_api_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/res/res_txn_mapper.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/gate_control_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/atk_utils.dart';
import 'package:tpg_attack_kiosko_muelle/utils/env_utils.dart';

class ResTransactionRunner {
  ResTransactionRunner({LogService? log}) : _log = log ?? LogService.instance;

  final LogService _log;

  bool _autoCancelAttempted = false;

  static bool _isRunning = false;
  static bool get isRunning => _isRunning;

  // ✅ Duración de cada mensaje de progreso (igual estilo EXP)
  static const _progressDelay = Duration(milliseconds: 200);

  Future<void> _showProgress(
    AtkTransactionManager manager,
    String mensaje,
  ) async {
    manager.setManyWithoutNotify({'mensajeInferior': mensaje});
    manager.notifyListeners();
    await Future.delayed(_progressDelay);
  }

  Future<void> run({
    required BuildContext context,
    required AppStateManager appManager,
    required AtkTransactionManager manager,
  }) async {
    if (_isRunning) {
      _log.logWarning('RES_RUNNER_SKIPPED', {
        'reason': 'Ya existe un runner RES ejecutándose',
        'timestamp': DateTime.now().toIso8601String(),
      });
      return;
    }

    print('🚀 [RES_RUNNER] Iniciando flujo automático RES...');

    _isRunning = true;
    final sw = Stopwatch()..start();

    try {
      manager.setManyWithoutNotify({
        'isLoading': true,
        'mensajeInferior': 'RES: Iniciando flujo automático...',
      });
      manager.notifyListeners();

      // ─────────────────────────────────────────────
      // PASO 1: INIT
      // ─────────────────────────────────────────────
      await _showProgress(manager, '🔐 RES: Inicializando...');

      final initEnv = await init(
        context: context,
        appManager: appManager,
        manager: manager,
      );

      print('✅ [RES_RUNNER] Init completado con código: ${initEnv.errorCode}');

      print(initEnv.message);

      if (!initEnv.isOk) {
        await _failAndCancel(
          context: context,
          appManager: appManager,
          manager: manager,
          step: 'INIT',
          message: initEnv.message,
        );
        return;
      }

      // ─────────────────────────────────────────────
      // PASO 2: GUARDAR
      // ─────────────────────────────────────────────
      await _showProgress(manager, '💾 RES: Guardando...');

      final pesoIng = _pesoIng(manager);
      final pesoSal = _pesoSal(manager);

      final guardarEnv = await guardar(
        context: context,
        appManager: appManager,
        manager: manager,
        pesoIng: pesoIng,
        pesoSal: pesoSal,
        observacion: null,
      );

      if (!guardarEnv.isOk) {
        await _failAndCancel(
          context: context,
          appManager: appManager,
          manager: manager,
          step: 'GUARDAR',
          message: guardarEnv.message,
        );
        return;
      }

      // ─────────────────────────────────────────────
      // PASO 3: IMPRIMIR (OBLIGATORIO)
      // ─────────────────────────────────────────────
      await _showProgress(manager, '🖨️ RES: Imprimiendo...');

      final imprimirEnv = await imprimir(
        context: context,
        appManager: appManager,
        manager: manager,
        pesoSal: pesoSal,
        pesoIng: pesoIng,
      );

      if (!imprimirEnv.isOk) {
        await _failAndCancel(
          context: context,
          appManager: appManager,
          manager: manager,
          step: 'IMPRIMIR',
          message: imprimirEnv.message,
        );
        return;
      }

      // 2) Imprimes localmente (PDF) usando tu nuevo PrintResService (vía PrintService)
      final ticket = TicketResModel.fromManager(manager);
      final printed = await PrintService.startPrint(
        tipo: 'RES',
        ticketData: ticket,
        saveToSpecificPath: true,
        autoPrint: true,
      );

      if (!printed) {
        await _failAndCancel(
          context: context,
          appManager: appManager,
          manager: manager,
          step: 'PRINT_LOCAL',
          message: 'No se pudo imprimir el ticket RES (PrintService=false)',
        );
        return;
      }

      // ─────────────────────────────────────────────
      // PASO 4: TERMINAR (OBLIGATORIO)
      // ─────────────────────────────────────────────
      await _showProgress(manager, '🚧 RES: Terminando (barrera)...');

      final terminarEnv = await terminar(
        context: context,
        appManager: appManager,
        manager: manager,
      );

      if (!terminarEnv.isOk) {
        await _failAndCancel(
          context: context,
          appManager: appManager,
          manager: manager,
          step: 'TERMINAR',
          message: terminarEnv.message,
        );
        return;
      }

      // ─────────────────────────────────────────────
      // OK FINAL
      // ─────────────────────────────────────────────
      await _showProgress(manager, '✅ RES: Transacción completada');

      manager.setManyWithoutNotify({
        'isLoading': false,
        'hasError': false,
        'errorMessage': null,
        'mensajeInferior':
            'RES completado exitosamente.\nSu comprobante fue impreso.\nPuede continuar.',
      });
      manager.notifyListeners();

      // ✅ Gate open best-effort (NO cancela si falla)
      _openGateBestEffort(appManager: appManager, manager: manager);

      _log.logRequest('RES_COMPLETE', {
        'latency_ms': sw.elapsedMilliseconds,
        'atkId': manager.get('atkId'),
        'numTrans': manager.get('numTrans'),
      });

      // ✅ Esperar y volver a RFID (igual tu estilo)
      await Future.delayed(const Duration(seconds: 15));
      manager.resetAll();
      manager.setFlowRemainingSeconds(null);

      if (context.mounted) _navigateToRfid(context);
    } catch (e, st) {
      _log.logError('RES_RUNNER_EX', e, st);

      // Si explota aquí, intentamos cancelar (best-effort)
      await _tryAutoCancel(
        context: context,
        appManager: appManager,
        manager: manager,
        reason: 'RUN_EXCEPTION',
      );

      manager.setManyWithoutNotify({
        'isLoading': false,
        'hasError': true,
        'errorMessage': 'RES: Error no controlado: $e',
        'mensajeInferior': 'RES: Error no controlado: $e',
      });
      manager.notifyListeners();

      if (context.mounted) _navigateToError(context, 'RES: $e');
    } finally {
      _isRunning = false;
      _log.logRequest('RES_RUNNER_END', {
        'latency_ms': sw.elapsedMilliseconds,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  // ─────────────────────────────────────────────
  // PASOS INDIVIDUALES (los tuyos, sin cambios grandes)
  // ─────────────────────────────────────────────

  Future<ApiEnvelope<ResInitData>> init({
    required BuildContext context,
    required AppStateManager appManager,
    required AtkTransactionManager manager,
  }) async {
    manager.setManyWithoutNotify({
      'isLoading': true,
      'mensajeInferior': 'RES: Inicializando...',
    });
    manager.notifyListeners();

    final req = _buildCommon(appManager, manager);

    try {
      final env = await ResApiService.instance.init(req);
      ResTxnMapper.applyInit(manager, env);

      if (!env.isOk) {
        await _tryAutoCancel(
          context: context,
          appManager: appManager,
          manager: manager,
          reason: 'INIT_FAIL',
        );
      }

      return env;
    } catch (e, st) {
      _printErr('RES_INIT_EXCEPTION', e, st);

      manager.setManyWithoutNotify({
        'isLoading': false,
        'mensajeInferior': 'RES init: error no controlado\n$e',
      });
      manager.notifyListeners();

      await _tryAutoCancel(
        context: context,
        appManager: appManager,
        manager: manager,
        reason: 'INIT_EXCEPTION',
      );

      return const ApiEnvelope(errorCode: 1, message: 'Exception', data: null);
    }
  }

  Future<ApiEnvelope<ResGuardarData>> guardar({
    required BuildContext context,
    required AppStateManager appManager,
    required AtkTransactionManager manager,
    required double pesoIng,
    double? pesoSal,
    String? observacion,
  }) async {
    manager.setManyWithoutNotify({
      'isLoading': true,
      'mensajeInferior': 'RES: Guardando...',
    });
    manager.notifyListeners();

    final req = ResGuardarRequest()
      ..placa = _safeStr(manager.get('vehiculoPlaca'))
      ..vehicleAccessId = _toInt(manager.get('atkId'))
      ..doorNumber = _doorNumber(manager)
      ..garitaLetra = _safeStr(appManager.kioskConfig?.gateLetter)
      ..garitaNumero = _safeStr(appManager.kioskConfig?.gate)
      ..tpg = null
      ..ruc = _safeStr(manager.get('driverCedula'))
      ..nombres = _safeStr(manager.get('driverName'))
      ..usuarioNombre = appManager.requestUsername
      ..emailJefe = appManager.requestUsername
      ..pesoIng = pesoIng
      ..pesoSal = pesoSal
      ..observacion = observacion
      ..tipoTran = 'I'
      ..codProducto1 = 'P01'
      ..codTipoCarga = 'T01'
      ..codBuque = 'B01'
      ..estadoUp = 'P'
      ..numTrans = _toInt(manager.get('numTrans'));

    try {
      final env = await ResApiService.instance.guardar(req);
      ResTxnMapper.applyGuardar(manager, env);

      if (!env.isOk) {
        await _tryAutoCancel(
          context: context,
          appManager: appManager,
          manager: manager,
          reason: 'GUARDAR_FAIL',
        );
      }

      return env;
    } catch (e, st) {
      _printErr('RES_GUARDAR_EXCEPTION', e, st);

      manager.setManyWithoutNotify({
        'isLoading': false,
        'mensajeInferior': 'RES guardar: error no controlado\n$e',
      });
      manager.notifyListeners();

      await _tryAutoCancel(
        context: context,
        appManager: appManager,
        manager: manager,
        reason: 'GUARDAR_EXCEPTION',
      );

      return const ApiEnvelope(errorCode: 1, message: 'Exception', data: null);
    }
  }

  Future<ApiEnvelope<ResImprimirData>> imprimir({
    required BuildContext context,
    required AppStateManager appManager,
    required AtkTransactionManager manager,
    required double pesoSal,
    double? pesoIng,
  }) async {
    manager.setManyWithoutNotify({
      'isLoading': true,
      'mensajeInferior': 'RES: Preparando impresión...',
    });
    manager.notifyListeners();

    final req = ResImprimirRequest()
      // ✅ OBLIGATORIO
      ..placa = _safeStr(manager.get('vehiculoPlaca'))
      // ✅ OPCIONALES (solo lo que el backend espera)
      ..tipo = 'R'
      ..numTrans = _toInt(manager.get('numTrans'))
      ..pesoIng = pesoIng
      ..pesoSal = pesoSal
      ..vehicleAccessId = _toInt(manager.get('atkId'))
      ..usuarioNombre = appManager.requestUsername;

    try {
      final env = await ResApiService.instance.imprimir(req);
      ResTxnMapper.applyImprimir(manager, env);

      if (!env.isOk) {
        await _tryAutoCancel(
          context: context,
          appManager: appManager,
          manager: manager,
          reason: 'IMPRIMIR_FAIL',
        );
      }

      return env;
    } catch (e, st) {
      _printErr('RES_IMPRIMIR_EXCEPTION', e, st);

      manager.setManyWithoutNotify({
        'isLoading': false,
        'mensajeInferior': 'RES imprimir: error no controlado\n$e',
      });
      manager.notifyListeners();

      await _tryAutoCancel(
        context: context,
        appManager: appManager,
        manager: manager,
        reason: 'IMPRIMIR_EXCEPTION',
      );

      return const ApiEnvelope(errorCode: 1, message: 'Exception', data: null);
    }
  }

  Future<ApiEnvelope<ResTerminarData>> terminar({
    required BuildContext context,
    required AppStateManager appManager,
    required AtkTransactionManager manager,
  }) async {
    manager.setManyWithoutNotify({
      'isLoading': true,
      'mensajeInferior': 'RES: Terminando (barrera)...',
    });
    manager.notifyListeners();

    final req = ResTerminarRequest()
      ..placa = _safeStr(manager.get('vehiculoPlaca'))
      ..vehicleAccessId = _toInt(manager.get('atkId'))
      ..doorNumber = _doorNumber(manager)
      ..garitaLetra = _safeStr(appManager.kioskConfig?.gateLetter)
      ..garitaNumero = _safeStr(appManager.kioskConfig?.gate)
      ..tpg = null
      ..ruc = _safeStr(manager.get('driverCedula'))
      ..usuarioNombre = appManager.requestUsername
      ..emailJefe = appManager.requestUsername
      ..numTrans = _toInt(manager.get('numTrans'));

    try {
      final env = await ResApiService.instance.terminar(req);
      ResTxnMapper.applyTerminar(manager, env);

      if (!env.isOk) {
        await _tryAutoCancel(
          context: context,
          appManager: appManager,
          manager: manager,
          reason: 'TERMINAR_FAIL',
        );
      }

      return env;
    } catch (e, st) {
      _printErr('RES_TERMINAR_EXCEPTION', e, st);

      manager.setManyWithoutNotify({
        'isLoading': false,
        'mensajeInferior': 'RES terminar: error no controlado\n$e',
      });
      manager.notifyListeners();

      await _tryAutoCancel(
        context: context,
        appManager: appManager,
        manager: manager,
        reason: 'TERMINAR_EXCEPTION',
      );

      return const ApiEnvelope(errorCode: 1, message: 'Exception', data: null);
    }
  }

  Future<ApiEnvelope<ResCancelarData>> cancelar({
    required BuildContext context,
    required AppStateManager appManager,
    required AtkTransactionManager manager,
    required bool confirm,
    String? kioskServer,
    int? kioskPort,
  }) async {
    manager.setManyWithoutNotify({
      'isLoading': true,
      'mensajeInferior': 'RES: Cancelando...',
    });
    manager.notifyListeners();

    final req = ResCancelarRequest()
      ..placa = _safeStr(manager.get('vehiculoPlaca'))
      ..vehicleAccessId = _toInt(manager.get('atkId'))
      ..doorNumber = _doorNumber(manager)
      ..garitaLetra = _safeStr(appManager.kioskConfig?.gateLetter)
      ..garitaNumero = _safeStr(appManager.kioskConfig?.gate)
      ..tpg = null
      ..ruc = _safeStr(manager.get('driverCedula'))
      ..usuarioNombre = appManager.requestUsername
      ..emailJefe = appManager.requestUsername
      ..confirm = confirm
      ..numTrans = _toInt(manager.get('numTrans'))
      ..kioskServer = kioskServer
      ..kioskPort = kioskPort;

    try {
      final env = await ResApiService.instance.cancelar(req);
      ResTxnMapper.applyCancelar(manager, env);
      return env;
    } catch (e, st) {
      _printErr('RES_CANCELAR_EXCEPTION', e, st);

      manager.setManyWithoutNotify({
        'isLoading': false,
        'mensajeInferior': 'RES cancelar: error no controlado\n$e',
      });
      manager.notifyListeners();

      return const ApiEnvelope(errorCode: 1, message: 'Exception', data: null);
    }
  }

  // ─────────────────────────────────────────────
  // CANCEL FLOW (obligatorio si falla algo)
  // ─────────────────────────────────────────────

  Future<void> _failAndCancel({
    required BuildContext context,
    required AppStateManager appManager,
    required AtkTransactionManager manager,
    required String step,
    required String message,
  }) async {
    _log.logWarning('RES_FAIL_$step', {'message': message});

    await _showProgress(manager, '🧨 RES: Falló $step, cancelando...');

    await _tryAutoCancel(
      context: context,
      appManager: appManager,
      manager: manager,
      reason: 'FAIL_$step',
    );

    manager.setManyWithoutNotify({
      'isLoading': false,
      'hasError': true,
      'errorMessage': 'RES $step: $message',
      'mensajeInferior': 'RES $step: $message',
    });
    manager.notifyListeners();

    if (context.mounted) _navigateToError(context, 'RES $step: $message');
  }

  Future<void> _tryAutoCancel({
    required BuildContext context,
    required AppStateManager appManager,
    required AtkTransactionManager manager,
    required String reason,
  }) async {
    if (_autoCancelAttempted) return;
    _autoCancelAttempted = true;

    final vaId = _toInt(manager.get('atkId'));
    if (vaId == null || vaId <= 0) {
      // ignore: avoid_print
      print('⚠️ [RES_AUTO_CANCEL] Skip: atkId inválido. reason=$reason');
      return;
    }

    // ignore: avoid_print
    print(
      '🧨 [RES_AUTO_CANCEL] Ejecutando cancelar automático. reason=$reason',
    );

    await cancelar(
      context: context,
      appManager: appManager,
      manager: manager,
      confirm: true,
      kioskServer: appManager.kioskConfig?.kioskServer,
      kioskPort: appManager.kioskConfig?.kioskServerPort,
    );
  }

  // ─────────────────────────────────────────────
  // Gate (best-effort)
  // ─────────────────────────────────────────────

  void _openGateBestEffort({
    required AppStateManager appManager,
    required AtkTransactionManager manager,
  }) {
    try {
      final controlUrl = appManager.kioskConfig?.controlGateService;
      final gateLocation = appManager.gateConfig?.gateLocation;
      final apiKeyHeader = appManager.gateConfig?.apiKey;
      final apiKeyBody = appManager.gateConfig?.keyPlc;

      final gateNumber = int.tryParse(appManager.kioskConfig?.gate ?? '');
      if (controlUrl == null ||
          gateLocation == null ||
          apiKeyHeader == null ||
          apiKeyBody == null ||
          gateNumber == null) {
        return;
      }

      final originalSide =
          int.tryParse(manager.get('sideGate')?.toString() ?? '') ?? 1;
      final sideNumber = AtkUtils.invertSide(originalSide);

      unawaited(
        GateControlService.instance.openGate(
          url: controlUrl,
          bodyApiKey: apiKeyBody,
          headerApiKey: apiKeyHeader,
          gateLocation: gateLocation,
          gate: gateNumber,
          side: sideNumber,
        ),
      );
    } catch (e) {
      _log.logWarning('RES_GATE_OPEN_FAILED', {'error': '$e'});
    }
  }

  // ─────────────────────────────────────────────
  // Helpers request common + safe parsing
  // ─────────────────────────────────────────────

  ResInitRequest _buildCommon(AppStateManager app, AtkTransactionManager m) {
    final req = ResInitRequest();

    req.placa = _safeStr(m.get('vehiculoPlaca'));
    req.vehicleAccessId = _toInt(m.get('atkId'));
    req.doorNumber = _doorNumber(m);

    req.garitaLetra = _safeStr(app.kioskConfig?.gateLetter);
    req.garitaNumero = _safeStr(app.kioskConfig?.gate);

    req.tpg = null;
    req.ruc = _safeStr(m.get('driverCedula'));
    req.nombres = _safeStr(m.get('driverName'));

    req.usuarioNombre = app.requestUsername;
    req.emailJefe = app.requestUsername;

    req.fechaBarreraRaw = null;
    req.tipoMov = _safeStr(m.get('transactionType'));

    return req;
  }

  static int _doorNumber(AtkTransactionManager m) {
    final side = _toInt(m.get('sideGate'));
    return side ?? 1;
  }

  static String? _safeStr(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  double _pesoIng(AtkTransactionManager m) {
    // Prioridad: pesoIngreso ya calculado -> pesoActualBascula
    final pi = _toDouble(m.get('pesoIngreso'));
    if (pi != null && pi > 0) return pi;

    final pa = _toDouble(m.get('pesoActualBascula'));
    if (pa != null && pa > 0) return pa;

    // fallback ultra-safe
    return 0;
  }

  double _pesoSal(AtkTransactionManager m) {
    // Si tienes pesoSalida explícito úsalo, si no, usa báscula actual
    final ps = _toDouble(m.get('pesoSalida'));
    if (ps != null && ps > 0) return ps;

    final pa = _toDouble(m.get('pesoActualBascula'));
    if (pa != null && pa > 0) return pa;

    return 0;
  }

  static void _printErr(String tag, Object e, StackTrace st) {
    // ignore: avoid_print
    print('❌ [$tag] $e\n$st');
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
}
