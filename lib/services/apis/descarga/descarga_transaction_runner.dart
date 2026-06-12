// lib/services/apis/descarga/descarga_transaction_runner.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/ocrScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/error_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/descarga/descarga_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/staapisac_api_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/gate_control_service.dart';

class DescargaTransactionRunner {
  final DescargaService _service;
  final LogService _log;

  // ⏱️ Segundos que la pantalla de éxito permanece visible antes de volver al OCR.
  // Bájalo a 0–3 si quieres que sea prácticamente inmediato.
  static const int kSuccessCountdownSeconds = 5;

  DescargaTransactionRunner({DescargaService? service, LogService? log})
    : _service = service ?? DescargaService(),
      _log = log ?? LogService.instance;

  // ─────────────────────────────────────────────
  // 🔴 NAVEGACIÓN CENTRALIZADA A ERROR
  // ─────────────────────────────────────────────
  void _goToErrorScreen(
    BuildContext context,
    AtkTransactionManager manager,
    String message,
  ) {
    // 🧹 1. LIMPIAR TODA LA TRANSACCIÓN
    manager.resetAll();

    // 🚨 2. SETEAR ERROR EXPLÍCITO
    manager.setMany({
      'hasError': true,
      'errorMessage': message,
      'isLoading': false,
    });

    // 🧭 3. NAVEGAR LIMPIANDO STACK
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => ErrorScreen(error: message)),
      (route) => false,
    );
  }

  // ─────────────────────────────────────────────
  // 🚀 RUNNER PRINCIPAL
  // ─────────────────────────────────────────────
  Future<void> run({
    required BuildContext context,
    required AppStateManager appManager,
    required AtkTransactionManager manager,
  }) async {
    try {
      // PASO 1: INICIALIZAR
      manager.setManyWithoutNotify({
        'mensajeInferior': 'Inicializando descarga...',
        'isLoading': true,
      });

      final ocrContainerBeforeInit = _snapshotOcrContainerData(manager);

      // 📝 Logs de diagnóstico: NO se esperan (fuera de la ruta crítica).
      unawaited(
        _log.logRequest('DESCARGA_RUNNER_INIT_START', {
          'placa': manager.vehiculoPlaca,
          'contenedor': manager.contenedor,
          'contenedor1': manager.get('contenedor1'),
          'contenedor2': manager.get('contenedor2'),
          'ocrContainerNumbers': manager.get('ocrContainerNumbers'),
          'ocrContainerCount': manager.get('ocrContainerCount'),
          'pesoActualBascula': manager.pesoActualBascula,
          'ocrContainerBeforeInit': ocrContainerBeforeInit,
        }),
      );

      final initResp = await _service.inicializar(manager, appManager);

      final initMap = initResp.toManagerMap();

      unawaited(
        _log.logRequest('DESCARGA_RUNNER_INIT_RESPONSE_FULL', {
          'errorCode': initResp.errorCode,
          'message': initResp.message,
          'managerMap': initMap,
          'ocrContainerBeforeInit': ocrContainerBeforeInit,
        }),
      );

      if (initResp.errorCode != 0) {
        _goToErrorScreen(context, manager, initResp.message);
        return;
      }

      manager.setMany({
        ...initMap,
        'isLoading': false,
        'mensajeInferior': 'Descarga inicializada correctamente',
      });

      _restoreOcrContainerDataIfNeeded(
        manager: manager,
        before: ocrContainerBeforeInit,
      );

      final taraOcr = (manager.ocrContainer1Tare ?? '').trim();

      if (taraOcr.isNotEmpty && taraOcr != '0') {
        manager.setMany({'pesoTara': taraOcr, 'taraFuente': 'OCR'});

        unawaited(
          _log.logRequest('DESCARGA_TARA_FROM_OCR_SET', {
            'contenedor': manager.contenedor,
            'contenedor1': manager.get('contenedor1'),
            'contenedor2': manager.get('contenedor2'),
            'taraOcr': taraOcr,
          }),
        );
      }

      // 🖼️ FOTO DEL CHOFER EN PARALELO (decorativa).
      // NO bloquea guardar ni la apertura de barrera. Cuando llegue,
      // setDriverPhotoUrl() notificará y la UI se actualizará sola.
      unawaited(_loadDriverPhoto(appManager: appManager, manager: manager));

      unawaited(
        _log.logRequest('DESCARGA_RUNNER_AFTER_INIT_MANAGER_STATE', {
          'placa': manager.vehiculoPlaca,
          'contenedor': manager.contenedor,
          'contenedor1': manager.get('contenedor1'),
          'contenedor2': manager.get('contenedor2'),
          'ocrContainerNumbers': manager.get('ocrContainerNumbers'),
          'ocrContainerCount': manager.get('ocrContainerCount'),
          'pesoIngreso': manager.pesoActualBascula,
          'pesoTara': manager.pesoTara,
          'pesoPorteo': manager.pesoPorteo,
          'driverCedula': manager.driverCedula,
          'driverName': manager.driverName,
          'vehiculoEmpresa': manager.vehiculoEmpresa,
        }),
      );

      // PASO 2: GUARDAR SOLO SI INICIALIZÓ OK (ya no espera la foto)
      manager.setManyWithoutNotify({
        'isLoading': true,
        'mensajeInferior': 'Guardando descarga...',
      });

      unawaited(
        _log.logRequest('DESCARGA_RUNNER_GUARDAR_START', {
          'reason': 'Inicialización correcta, procede guardar',
          'placa': manager.vehiculoPlaca,
          'contenedor': manager.contenedor,
          'contenedor1': manager.get('contenedor1'),
          'contenedor2': manager.get('contenedor2'),
          'ocrContainerNumbers': manager.get('ocrContainerNumbers'),
          'ocrContainerCount': manager.get('ocrContainerCount'),
          'pesoIngreso': manager.pesoActualBascula,
          'pesoTara': manager.pesoTara,
          'pesoPorteo': manager.pesoPorteo,
        }),
      );

      final guardarResp = await _service.guardar(manager, appManager);

      unawaited(
        _log.logRequest('DESCARGA_RUNNER_GUARDAR_RESPONSE_FULL', {
          'errorCode': guardarResp.errorCode,
          'message': guardarResp.message,
          'managerMap': guardarResp.toManagerMap(),
          'contenedorEnviado': manager.contenedor,
          'contenedor1': manager.get('contenedor1'),
          'contenedor2': manager.get('contenedor2'),
        }),
      );

      if (guardarResp.errorCode != 0) {
        _goToErrorScreen(context, manager, guardarResp.message);
        return;
      }

      manager.setMany({
        ...guardarResp.toManagerMap(),
        'isLoading': true,
        'mensajeInferior': 'Descarga guardada. Abriendo barrera...',
        'descargaGuardada': true,
        'descargaGateOpenRequested': false,
        'descargaGateOpenOk': false,
        'descargaGateOpenGate': null,
        'descargaGateOpenSide': null,
      });

      unawaited(
        _log.logRequest('DESCARGA_RUNNER_BEFORE_GATE_OPEN', {
          'placa': manager.vehiculoPlaca,
          'contenedor': manager.contenedor,
          'contenedor1': manager.get('contenedor1'),
          'contenedor2': manager.get('contenedor2'),
          'rfidGate': manager.get('rfidGate'),
          'side': manager.get('side'),
          'doorNumber': manager.get('doorNumber'),
          'sideGate': manager.sideGate,
        }),
      );

      // 🚧 CRÍTICO: la apertura de barrera SÍ se espera.
      await _openGateAfterSuccess(appManager: appManager, manager: manager);

      manager.setMany({
        'isLoading': false,
        'mensajeInferior': 'Descarga completada. Barrera abierta.',
        'descargaGateOpenOk': true,
      });

      const totalSeconds = kSuccessCountdownSeconds;

      for (int i = totalSeconds; i >= 0; i--) {
        if (!context.mounted) return;

        manager.setFlowRemainingSeconds(i);

        if (i == 0) break;
        await Future.delayed(const Duration(seconds: 1));
      }

      unawaited(
        _log.logRequest('DESCARGA_AUTO_EXIT', {
          'after_seconds': totalSeconds,
          'placa': manager.vehiculoPlaca,
          'contenedor': manager.contenedor,
          'contenedor1': manager.get('contenedor1'),
          'contenedor2': manager.get('contenedor2'),
          'rfidGate': manager.get('rfidGate'),
          'side': manager.get('side'),
          'doorNumber': manager.get('doorNumber'),
          'descargaGateOpenRequested': manager.get('descargaGateOpenRequested'),
          'descargaGateOpenOk': manager.get('descargaGateOpenOk'),
          'descargaGateOpenGate': manager.get('descargaGateOpenGate'),
          'descargaGateOpenSide': manager.get('descargaGateOpenSide'),
        }),
      );

      manager.resetAll();
      manager.setFlowRemainingSeconds(null);

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const OcrScannerScreen()),
          (route) => false,
        );
      }
    } catch (e, st) {
      await _log.logError('DESCARGA_RUNNER_EX', e, st);

      if (!context.mounted) return;

      _goToErrorScreen(
        context,
        manager,
        'Error ejecutando descarga: ${e.toString()}',
      );
    }
  }

  Future<void> _countdownAndReturnToOcr({
    required BuildContext context,
    required AtkTransactionManager manager,
    int seconds = kSuccessCountdownSeconds,
  }) async {
    for (int i = seconds; i >= 0; i--) {
      if (!context.mounted) return;

      manager.setFlowRemainingSeconds(i);

      if (i == 0) break;
      await Future.delayed(const Duration(seconds: 1));
    }

    unawaited(
      _log.logRequest('DESCARGA_INIT_ONLY_AUTO_EXIT', {
        'after_seconds': seconds,
        'placa': manager.vehiculoPlaca,
        'contenedor': manager.contenedor,
      }),
    );

    manager.resetAll();
    manager.setFlowRemainingSeconds(null);

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const OcrScannerScreen()),
      (route) => false,
    );
  }

  Future<void> _loadDriverPhoto({
    required AppStateManager appManager,
    required AtkTransactionManager manager,
  }) async {
    final id = (manager.driverCedula ?? '').trim();

    if (id.isEmpty) {
      unawaited(
        _log.logWarning('DESCARGA_DRIVER_PHOTO_SKIP', {
          'reason': 'driverCedula empty',
        }),
      );
      return;
    }

    try {
      final imgB64 = await StaapisacApiService().getFotoChoferBase64(
        appState: appManager,
        choferId: id,
      );

      if (imgB64 == null || imgB64.isEmpty) {
        unawaited(
          _log.logWarning('DESCARGA_DRIVER_PHOTO_EMPTY', {
            'driverCedula': id,
          }),
        );
        return;
      }

      manager.setDriverPhotoUrl(imgB64);

      unawaited(
        _log.logRequest('DESCARGA_DRIVER_PHOTO_LOADED', {
          'driverCedula': id,
          'hasPhoto': true,
          'length': imgB64.length,
        }),
      );
    } catch (e, st) {
      unawaited(_log.logError('DESCARGA_DRIVER_PHOTO_FAIL', e, st));
    }
  }

  Future<void> runInicializarOnly({
    required BuildContext context,
    required AppStateManager appManager,
    required AtkTransactionManager manager,
  }) async {
    try {
      manager.setManyWithoutNotify({
        'mensajeInferior': '📋 Inicializando descarga...',
        'isLoading': true,
      });

      final ocrContainerBeforeInit = _snapshotOcrContainerData(manager);

      unawaited(
        _log.logRequest('DESCARGA_INIT_ONLY_START', {
          'placa': manager.vehiculoPlaca,
          'contenedor': manager.contenedor,
          'contenedor1': manager.get('contenedor1'),
          'contenedor2': manager.get('contenedor2'),
          'ocrContainerNumbers': manager.get('ocrContainerNumbers'),
          'ocrContainerCount': manager.get('ocrContainerCount'),
          'ocrContainerBeforeInit': ocrContainerBeforeInit,
        }),
      );

      final initResp = await _service.inicializar(manager, appManager);

      final initMap = initResp.toManagerMap();

      unawaited(
        _log.logRequest('DESCARGA_RUNNER_INIT_FULL_RESPONSE', {
          'errorCode': initResp.errorCode,
          'message': initResp.message,
          'managerMap': initMap,
          'ocrContainerBeforeInit': ocrContainerBeforeInit,
        }),
      );

      if (initResp.errorCode != 0) {
        _goToErrorScreen(context, manager, initResp.message);
        return;
      }

      manager.setMany({
        ...initMap,
        'isLoading': false,
        'mensajeInferior': '✅ Descarga inicializada',
      });

      _restoreOcrContainerDataIfNeeded(
        manager: manager,
        before: ocrContainerBeforeInit,
      );

      final taraOcr = (manager.ocrContainer1Tare ?? '').trim();

      if (taraOcr.isNotEmpty && taraOcr != '0') {
        manager.setMany({'pesoTara': taraOcr, 'taraFuente': 'OCR'});

        unawaited(
          _log.logRequest('DESCARGA_TARA_FROM_OCR_SET', {
            'contenedor': manager.contenedor,
            'contenedor1': manager.get('contenedor1'),
            'contenedor2': manager.get('contenedor2'),
            'taraOcr': taraOcr,
          }),
        );
      }

      // 🖼️ Foto en paralelo, no bloquea el flujo.
      unawaited(_loadDriverPhoto(appManager: appManager, manager: manager));

      unawaited(
        _log.logRequest('DESCARGA_INIT_ONLY_AFTER_INIT_MANAGER_STATE', {
          'placa': manager.vehiculoPlaca,
          'contenedor': manager.contenedor,
          'contenedor1': manager.get('contenedor1'),
          'contenedor2': manager.get('contenedor2'),
          'ocrContainerNumbers': manager.get('ocrContainerNumbers'),
          'ocrContainerCount': manager.get('ocrContainerCount'),
          'pesoIngreso': manager.pesoActualBascula,
          'pesoTara': manager.pesoTara,
          'driverCedula': manager.driverCedula,
          'driverName': manager.driverName,
        }),
      );

      await _countdownAndReturnToOcr(
        context: context,
        manager: manager,
        seconds: kSuccessCountdownSeconds,
      );
    } catch (e, st) {
      unawaited(_log.logError('DESCARGA_INIT_ONLY_EX', e, st));

      if (!context.mounted) return;

      _goToErrorScreen(
        context,
        manager,
        'Error inicializando descarga: ${e.toString()}',
      );
    }
  }

  Map<String, dynamic> _snapshotOcrContainerData(
    AtkTransactionManager manager,
  ) {
    return {
      'contenedor': manager.contenedor,
      'contenedor1': manager.get('contenedor1'),
      'contenedor2': manager.get('contenedor2'),
      'ocrContainerNumbers': manager.get('ocrContainerNumbers'),
      'ocrContainerCount': manager.get('ocrContainerCount'),
      'ocrContainerValid': manager.get('ocrContainerValid'),
      'ocrVehicleType': manager.get('ocrVehicleType'),
      'ocrContainersJson': manager.get('ocrContainersJson'),
      'ocrRawJson': manager.get('ocrRawJson'),
      'ocrContainer1Number': manager.get('ocrContainer1Number'),
      'ocrContainer2Number': manager.get('ocrContainer2Number'),
      'ocrContainer1Tare': manager.get('ocrContainer1Tare'),
      'ocrContainer2Tare': manager.get('ocrContainer2Tare'),
      'muelleContainerCount': manager.get('muelleContainerCount'),
      'muelleIsDoubleContainer': manager.get('muelleIsDoubleContainer'),
      'ocrIsDoubleContainer': manager.get('ocrIsDoubleContainer'),
      'ocrRouteDestination': manager.get('ocrRouteDestination'),
    };
  }

  void _restoreOcrContainerDataIfNeeded({
    required AtkTransactionManager manager,
    required Map<String, dynamic> before,
  }) {
    final restore = <String, dynamic>{};

    void restoreIfEmpty(String key) {
      final current = key == 'contenedor'
          ? manager.contenedor
          : manager.get(key);
      final previous = before[key];

      final currentEmpty = current == null || current.toString().trim().isEmpty;
      final previousNotEmpty =
          previous != null && previous.toString().trim().isNotEmpty;

      if (currentEmpty && previousNotEmpty) {
        restore[key] = previous;
      }
    }

    for (final key in [
      'contenedor',
      'contenedor1',
      'contenedor2',
      'ocrContainerNumbers',
      'ocrContainerCount',
      'ocrContainerValid',
      'ocrVehicleType',
      'ocrContainersJson',
      'ocrRawJson',
      'ocrContainer1Number',
      'ocrContainer2Number',
      'ocrContainer1Tare',
      'ocrContainer2Tare',
      'muelleContainerCount',
      'muelleIsDoubleContainer',
      'ocrIsDoubleContainer',
      'ocrRouteDestination',
    ]) {
      restoreIfEmpty(key);
    }

    final currentContenedor = (manager.contenedor ?? '').trim();
    final restoredContenedor = (restore['contenedor'] ?? '').toString().trim();
    final ocrContainers =
        (restore['ocrContainerNumbers'] ??
                manager.get('ocrContainerNumbers') ??
                before['ocrContainerNumbers'] ??
                '')
            .toString()
            .trim();

    if (currentContenedor.isEmpty &&
        restoredContenedor.isEmpty &&
        ocrContainers.isNotEmpty) {
      restore['contenedor'] = ocrContainers;
    }

    if (restore.isEmpty) {
      unawaited(
        _log.logRequest('DESCARGA_OCR_CONTAINER_RESTORE_SKIP', {
          'reason': 'No había datos OCR que restaurar o ya seguían presentes',
          'before': before,
          'current': {
            'contenedor': manager.contenedor,
            'contenedor1': manager.get('contenedor1'),
            'contenedor2': manager.get('contenedor2'),
            'ocrContainerNumbers': manager.get('ocrContainerNumbers'),
            'ocrContainerCount': manager.get('ocrContainerCount'),
          },
        }),
      );
      return;
    }

    manager.setManyWithoutNotify(restore);

    unawaited(
      _log.logRequest('DESCARGA_OCR_CONTAINER_RESTORED', {
        'restore': restore,
        'before': before,
        'after': {
          'contenedor': manager.contenedor,
          'contenedor1': manager.get('contenedor1'),
          'contenedor2': manager.get('contenedor2'),
          'ocrContainerNumbers': manager.get('ocrContainerNumbers'),
          'ocrContainerCount': manager.get('ocrContainerCount'),
          'ocrContainer1Tare': manager.get('ocrContainer1Tare'),
          'ocrContainer2Tare': manager.get('ocrContainer2Tare'),
        },
      }),
    );
  }

  Future<void> _openGateAfterSuccess({
    required AppStateManager appManager,
    required AtkTransactionManager manager,
  }) async {
    final kioskCfg = appManager.kioskConfig;
    final gateCfg = appManager.gateConfig;

    final url = _s(kioskCfg?.controlGateService);

    // Header:
    // Este valor va como headers['api-key'].
    final headerApiKey = _s(gateCfg?.apiKey);

    // Body:
    // Este valor va dentro del JSON que se codifica a base64:
    // {"gate": 92, "api_key": keyPlc, "side": 1}
    final bodyApiKey = _s(gateCfg?.keyPlc);

    final gate = _rfidGate(manager);
    final side = _rfidSide(manager);

    unawaited(
      _log.logRequest('DESCARGA_GATE_OPEN_START', {
        'url': url,
        'urlSource': 'kioskConfig.controlGateService',
        'gate': gate,
        'side': side,
        'gateSource': 'manager.rfidGate',
        'sideSource': 'manager.side / manager.doorNumber / manager.sideGate',
        'headerApiKeySource': 'gateConfig.apiKey',
        'bodyApiKeySource': 'gateConfig.keyPlc',
        'managerRfidGate': manager.get('rfidGate'),
        'managerSide': manager.get('side'),
        'managerDoorNumber': manager.get('doorNumber'),
        'sideGate': manager.sideGate,
        'kioskControlGateService': kioskCfg?.controlGateService,
        'gateConfigApiKeyLen': headerApiKey.length,
        'gateConfigKeyPlcLen': bodyApiKey.length,
        'kioskGateIgnored': kioskCfg?.gate,
        'configGateLocationIgnored': gateCfg?.gateLocation,
        'hasUrl': url.isNotEmpty,
        'hasHeaderApiKey': headerApiKey.isNotEmpty,
        'hasBodyApiKey': bodyApiKey.isNotEmpty,
        'snapshot': _snapshotDescarga(manager),
      }),
    );

    if (url.isEmpty ||
        headerApiKey.isEmpty ||
        bodyApiKey.isEmpty ||
        gate <= 0 ||
        side <= 0) {
      unawaited(
        _log.logWarning('DESCARGA_GATE_OPEN_SKIPPED', {
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
          'managerSide': manager.get('side'),
          'managerDoorNumber': manager.get('doorNumber'),
          'sideGate': manager.sideGate,
          'snapshot': _snapshotDescarga(manager),
        }),
      );

      manager.setManyWithoutNotify({
        'descargaGateOpenRequested': true,
        'descargaGateOpenOk': false,
        'descargaGateOpenGate': gate,
        'descargaGateOpenSide': side,
      });

      throw Exception(
        'No se pudo abrir barrera: controlGateService/apiKey/keyPlc/gate/side RFID no válidos.',
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
      'descargaGateOpenRequested': true,
      'descargaGateOpenOk': opened,
      'descargaGateOpenGate': gate,
      'descargaGateOpenSide': side,
    });

    unawaited(
      _log.logRequest('DESCARGA_GATE_OPEN_RESULT', {
        'opened': opened,
        'url': url,
        'urlSource': 'kioskConfig.controlGateService',
        'gate': gate,
        'side': side,
        'gateLocation': gate.toString(),
        'headerApiKeySource': 'gateConfig.apiKey',
        'bodyApiKeySource': 'gateConfig.keyPlc',
        'snapshot': _snapshotDescarga(manager),
      }),
    );

    if (!opened) {
      throw Exception('No se pudo abrir la barrera.');
    }
  }

  int _rfidGate(AtkTransactionManager manager) {
    return _int(manager.get('rfidGate')) ?? 0;
  }

  int _rfidSide(AtkTransactionManager manager) {
    return _int(
          manager.get('side') ?? manager.get('doorNumber') ?? manager.sideGate,
        ) ??
        0;
  }

  int? _int(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _s(dynamic value) => (value ?? '').toString().trim();

  Map<String, dynamic> _snapshotDescarga(AtkTransactionManager manager) {
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
      'pesoPorteo': manager.pesoPorteo,
      'driverCedula': manager.driverCedula,
      'driverName': manager.driverName,
      'transactionType': manager.transactionType,
      'rfidGate': manager.get('rfidGate'),
      'side': manager.get('side'),
      'doorNumber': manager.get('doorNumber'),
      'sideGate': manager.sideGate,
      'descargaGuardada': manager.get('descargaGuardada'),
      'descargaGateOpenRequested': manager.get('descargaGateOpenRequested'),
      'descargaGateOpenOk': manager.get('descargaGateOpenOk'),
      'descargaGateOpenGate': manager.get('descargaGateOpenGate'),
      'descargaGateOpenSide': manager.get('descargaGateOpenSide'),
      'isLoading': manager.isLoading,
      'mensajeInferior': manager.mensajeInferior,
      'hasError': manager.hasError,
      'errorMessage': manager.errorMessage,
    };
  }
}