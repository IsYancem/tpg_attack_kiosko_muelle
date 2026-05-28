import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/models/psc/psc_models.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/ocrScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/error_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/psc/psc_api_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/staapisac_api_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/gate_control_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/env_utils.dart';

class PscTransactionRunner {
  PscTransactionRunner({PscApiService? api, StaapisacApiService? staapisacApi})
    : _api = api ?? const PscApiService(),
      _staapisacApi = staapisacApi ?? StaapisacApiService();

  final PscApiService _api;
  final StaapisacApiService _staapisacApi;

  bool _running = false;

  String _usuario() => KioskUserEnv.usuario;

  Future<void> run({
    required BuildContext context,
    required AppStateManager appManager,
    required AtkTransactionManager manager,
  }) async {
    if (_running) {
      await LogService.instance.logWarning('PSC_RUNNER_SKIPPED', {
        'reason': 'Ya existe un runner PSC ejecutándose',
        'snapshot': _snapshotManager(manager),
      });
      return;
    }

    _running = true;
    final sw = Stopwatch()..start();

    try {
      manager.clearError();
      manager.setMany({
        'isLoading': true,
        'mensajeInferior': 'Validando porteo sin contenedor...',
        'pscRunning': true,
        'pscGuardado': false,
        'pscTerminado': false,
        'pscGateOpenRequested': false,
        'pscGateOpenOk': false,
        'pscGateOpenGate': null,
        'pscGateOpenSide': null,
      });

      await _logRunnerStart(appManager, manager);

      // ─────────────────────────────────────────────
      // PASO 1: NAVEGAR
      // ─────────────────────────────────────────────
      final navegarPayload = _buildNavegarRequest(appManager, manager);
      await _logStepPayload(
        step: 'NAVEGAR',
        path: '/psc/navegar',
        payload: navegarPayload,
        manager: manager,
      );

      final navegarRes = await _api.navegar(
        appState: appManager,
        body: navegarPayload,
      );

      _applyNavegar(manager, navegarRes);

      await _logStepResult(
        step: 'NAVEGAR',
        path: '/psc/navegar',
        res: navegarRes,
        manager: manager,
      );

      if (!navegarRes.isOk || navegarRes.data?.okToNavigate != true) {
        throw Exception('NAVEGAR: ${navegarRes.message}');
      }

      // ─────────────────────────────────────────────
      // PASO 2: INICIALIZAR
      // ─────────────────────────────────────────────
      manager.setMany({
        'isLoading': true,
        'mensajeInferior': 'Consultando foto del conductor...',
      });

      await _loadDriverPhotoForPsc(appManager: appManager, manager: manager);

      manager.setMany({
        'isLoading': true,
        'mensajeInferior': 'Inicializando porteo sin contenedor...',
      });

      final initPayload = _buildInicializarRequest(appManager, manager);
      await _logStepPayload(
        step: 'INICIALIZAR',
        path: '/psc/psc/inicializar',
        payload: initPayload,
        manager: manager,
      );

      final initRes = await _api.inicializar(
        appState: appManager,
        body: initPayload,
      );

      _applyInicializar(manager, initRes);

      await _logStepResult(
        step: 'INICIALIZAR',
        path: '/psc/psc/inicializar',
        res: initRes,
        manager: manager,
      );

      if (!initRes.isOk || initRes.data?.okToNavigate != true) {
        throw Exception('INICIALIZAR: ${initRes.message}');
      }

      // ─────────────────────────────────────────────
      // PASO 3: GUARDAR
      // ─────────────────────────────────────────────
      manager.setMany({
        'isLoading': true,
        'mensajeInferior': 'Guardando porteo sin contenedor...',
      });

      final guardarPayload = _buildGuardarRequest(appManager, manager);
      await _logStepPayload(
        step: 'GUARDAR',
        path: '/psc/psc/guardar',
        payload: guardarPayload,
        manager: manager,
      );

      final guardarRes = await _api.guardar(
        appState: appManager,
        body: guardarPayload,
      );

      _applyGuardar(manager, guardarRes);

      await _logStepResult(
        step: 'GUARDAR',
        path: '/psc/psc/guardar',
        res: guardarRes,
        manager: manager,
      );

      if (!guardarRes.isOk || guardarRes.data?.ok != true) {
        throw Exception('GUARDAR: ${guardarRes.message}');
      }

      // ─────────────────────────────────────────────
      // PASO 4: TERMINAR
      // ─────────────────────────────────────────────
      manager.setMany({
        'isLoading': true,
        'mensajeInferior': 'Terminando porteo sin contenedor...',
      });

      final terminarPayload = _buildTerminarRequest(manager);
      await _logStepPayload(
        step: 'TERMINAR',
        path: '/psc/psc/terminar',
        payload: terminarPayload,
        manager: manager,
      );

      final terminarRes = await _api.terminar(
        appState: appManager,
        body: terminarPayload,
      );

      _applyTerminar(manager, terminarRes);

      await _logStepResult(
        step: 'TERMINAR',
        path: '/psc/psc/terminar',
        res: terminarRes,
        manager: manager,
      );

      if (!terminarRes.isOk || terminarRes.data?.okToNavigate != true) {
        throw Exception('TERMINAR: ${terminarRes.message}');
      }

      // ─────────────────────────────────────────────
      // PASO 5: ABRIR BARRERA
      // ─────────────────────────────────────────────
      manager.setMany({
        'isLoading': true,
        'mensajeInferior': 'Abriendo barrera...',
        'pscRunning': true,
        'pscTerminado': true,
      });

      await _openGateAfterSuccess(appManager: appManager, manager: manager);

      manager.setMany({
        'isLoading': true,
        'mensajeInferior': 'Barrera abierta. Retornando a lectura OCR...',
        'pscRunning': false,
        'pscTerminado': true,
      });

      await LogService.instance.logRequest('PSC_RUNNER_OK', {
        'latencyMs': sw.elapsedMilliseconds,
        'snapshot': _snapshotManager(manager),
      });

      // IMPORTANTE:
      // Esperar 3 segundos antes de volver al OCR para evitar novedades.
      await Future.delayed(const Duration(seconds: 3));

      await _resetTransactionBeforeOcr(manager);

      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const OcrScannerScreen(),
          transitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
        (route) => false,
      );
    } catch (e, st) {
      await LogService.instance.logError('PSC_RUNNER_ERROR', e, st);

      await LogService.instance.logRequest('PSC_RUNNER_FAIL_CONTEXT', {
        'latencyMs': sw.elapsedMilliseconds,
        'error': _cleanError(e),
        'snapshot': _snapshotManager(manager),
      });

      manager.setMany({'isLoading': false, 'pscRunning': false});

      manager.setError(_cleanError(e));

      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => ErrorScreen(error: _cleanError(e)),
          transitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
        (route) => false,
      );
    } finally {
      _running = false;

      await LogService.instance.logRequest('PSC_RUNNER_END', {
        'latencyMs': sw.elapsedMilliseconds,
        'running': _running,
        'snapshot': _snapshotManager(manager),
      });
    }
  }

  JsonMap _buildNavegarRequest(
    AppStateManager appManager,
    AtkTransactionManager manager,
  ) {
    final doorNumber = _doorNumber(manager);

    return {
      'placaCapturada': _s(manager.vehiculoPlaca),
      'placaDigitada': _s(manager.vehiculoPlaca),
      'peso': manager.pesoActualBascula,
      'ruc': _s(manager.driverCedula ?? manager.conseguirConductorChofer),
      'porteoPesoLimite': appManager.porteoPeso,
      'vehicleAccessId': _vehicleAccessId(manager),
      'usuario': _usuario(),
      'bascula': appManager.kioskConfig?.gate,
      'puerta': doorNumber,
    };
  }

  JsonMap _buildInicializarRequest(
    AppStateManager appManager,
    AtkTransactionManager manager,
  ) {
    final names = _splitName(manager.driverName);

    return {
      'placa': _s(manager.vehiculoPlaca),
      'pesoIngreso': manager.pesoActualBascula,
      'firstName': _s(manager.conseguirDataConductorFirstName ?? names.$1),
      'lastName': _s(manager.conseguirDataConductorLastName ?? names.$2),
      'licenseType': _s(
        manager.conseguirDataConductorLicenseType ?? manager.driverLicenciaTipo,
      ),
      'licenseExpiration': _s(
        manager.conseguirDataConductorLicenseExpirationDate ??
            manager.driverLicenciaExp,
      ),
      'identificacion': _s(
        manager.conseguirDataConductorIdentificationNumber ??
            manager.driverCedula,
      ),
      'tpgOrigen': _tpg(appManager),
      'tpgDestino': _tpg(appManager),
      'tieneFoto': manager.hasPhoto,
      'msgFoto': manager.driverAlerta,
    };
  }

  JsonMap _buildGuardarRequest(
    AppStateManager appManager,
    AtkTransactionManager manager,
  ) {
    final doorNumber = _doorNumber(manager);

    return {
      'tipoTran': 'I',
      'placa': _s(manager.vehiculoPlaca),
      'codProducto': 'P01',
      'codTipoCarga': 'T01',
      'codBuque': 'B01',
      'garitaLetra': _garitaLetra(appManager),
      'cedulaChofer': _s(manager.driverCedula),
      'pesoIngreso': manager.pesoActualBascula,
      'estado': 'C',
      'estadoUp': 'C',
      'numTrans': _s(manager.conseguirConductorNumTran),
      'tpg': _tpg(appManager),
      'garitaNumero': _int(appManager.kioskConfig?.gate),
      'doorNumber': doorNumber,
      'fechaBarrera': _fechaBarreraNow(),
      'usuarioNombre': _usuario(),
      'ruc': _s(manager.driverCedula),
      'ciaTransporte': _s(
        manager.driverEmpresa ??
            manager.conseguirDataConductorCompanyName ??
            manager.vehiculoEmpresa,
      ),
      'permisoMuelle': _s(manager.get('PERMISOMUELLE')),
      'nombresChofer': _s(manager.driverName),
    };
  }

  JsonMap _buildTerminarRequest(AtkTransactionManager manager) {
    return {
      'guardado': manager.get('pscGuardado') == true,
      'vehicleAccessId': _vehicleAccessIdAsInt(manager),
      'doorNumber': _doorNumber(manager),
      'next': 'OCR',
    };
  }

  void _applyNavegar(
    AtkTransactionManager manager,
    PscApiEnvelope<PscNavegarData> res,
  ) {
    final data = res.data;

    manager.setManyWithoutNotify({
      'pscNavegarRaw': res.raw,
      'pscNavegarErrorCode': res.errorCode,
      'pscNavegarMessage': res.message,
      'pscOkToNavigate': data?.okToNavigate,
      'pscPlacaUsada': data?.placaUsada,
      'pscPeso': data?.peso,
      'pscRuc': data?.ruc,
      'pscPorteoPesoLimite': data?.porteoPesoLimite,
      'pscNavegarWarnings': data?.warnings,
      'pscNavegarServices': data?.services,
    });

    manager.setMany({
      'mensajeInferior': res.isOk
          ? 'Validación inicial correcta.'
          : 'No se pudo validar porteo sin contenedor.',
    });
  }

  void _applyInicializar(
    AtkTransactionManager manager,
    PscApiEnvelope<PscInicializarData> res,
  ) {
    final data = res.data;

    manager.setManyWithoutNotify({
      'pscInicializarRaw': res.raw,
      'pscInicializarErrorCode': res.errorCode,
      'pscInicializarMessage': res.message,
      'pscInicializarOkToNavigate': data?.okToNavigate,
      'pscInicializarServices': data?.services,
      'pscInicializarControls': data?.controls,
      'pscInicializarUiHints': data?.uiHints,
    });

    if (data != null) {
      manager.setManyWithoutNotify({
        'vehiculoPlaca': data.placa ?? manager.vehiculoPlaca,
        'pesoIngreso': data.pesoIngreso?.toStringAsFixed(0),
        'driverName': data.nombreConductor ?? manager.driverName,
        'driverLicenciaTipo': data.tipoLicencia ?? manager.driverLicenciaTipo,
        'driverLicenciaExp':
            data.expiracionLicencia ?? manager.driverLicenciaExp,
        'driverCedula': data.cedula ?? manager.driverCedula,
      });
    }

    manager.setMany({
      'mensajeInferior': res.isOk
          ? 'Pantalla inicializada correctamente.'
          : 'No se pudo inicializar porteo sin contenedor.',
    });
  }

  void _applyGuardar(
    AtkTransactionManager manager,
    PscApiEnvelope<PscGuardarData> res,
  ) {
    final data = res.data;

    manager.setManyWithoutNotify({
      'pscGuardarRaw': res.raw,
      'pscGuardarErrorCode': res.errorCode,
      'pscGuardarMessage': res.message,
      'pscGuardarOk': data?.ok,
      'pscGuardarNumero': data?.numero,
      'pscGuardarResultado': data?.resultado,
      'pscGuardarServices': data?.services,
      'pscGuardarControls': data?.controls,
      'pscGuardado': res.isOk && data?.ok == true,
      'numTrans': data?.numero?.toString() ?? manager.numTrans,
    });

    manager.setMany({
      'mensajeInferior': res.isOk
          ? 'Porteo guardado correctamente.'
          : 'No se pudo guardar porteo sin contenedor.',
    });
  }

  void _applyTerminar(
    AtkTransactionManager manager,
    PscApiEnvelope<PscTerminarData> res,
  ) {
    final data = res.data;

    manager.setManyWithoutNotify({
      'pscTerminarRaw': res.raw,
      'pscTerminarErrorCode': res.errorCode,
      'pscTerminarMessage': res.message,
      'pscTerminarOkToNavigate': data?.okToNavigate,
      'pscTerminarServices': data?.services,
      'pscTerminarControls': data?.controls,
      'pscTerminarUiHints': data?.uiHints,
      'pscTerminado': res.isOk && data?.okToNavigate == true,
    });

    manager.setMany({
      'mensajeInferior': res.isOk
          ? 'Porteo terminado correctamente.'
          : 'No se pudo terminar porteo sin contenedor.',
    });
  }

  Future<void> _openGateAfterSuccess({
    required AppStateManager appManager,
    required AtkTransactionManager manager,
  }) async {
    final kioskCfg = appManager.kioskConfig;
    final gateCfg = appManager.gateConfig;

    final url = _s(kioskCfg?.controlGateService);

    // Header:
    // Este va como headers['api-key'].
    final headerApiKey = _s(gateCfg?.apiKey);

    // Body:
    // Este va dentro del JSON que se codifica a base64:
    // {"gate": 92, "api_key": keyPlc, "side": 1}
    final bodyApiKey = _s(gateCfg?.keyPlc);

    final gate = _rfidGate(manager);
    final side = _rfidSide(manager);

    await LogService.instance.logRequest('PSC_GATE_OPEN_START', {
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
      'snapshot': _snapshotManager(manager),
    });

    if (url.isEmpty ||
        headerApiKey.isEmpty ||
        bodyApiKey.isEmpty ||
        gate <= 0 ||
        side <= 0) {
      await LogService.instance.logWarning('PSC_GATE_OPEN_SKIPPED', {
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
        'snapshot': _snapshotManager(manager),
      });

      manager.setManyWithoutNotify({
        'pscGateOpenRequested': true,
        'pscGateOpenOk': false,
        'pscGateOpenGate': gate,
        'pscGateOpenSide': side,
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
      'pscGateOpenRequested': true,
      'pscGateOpenOk': opened,
      'pscGateOpenGate': gate,
      'pscGateOpenSide': side,
    });

    await LogService.instance.logRequest('PSC_GATE_OPEN_RESULT', {
      'opened': opened,
      'url': url,
      'urlSource': 'kioskConfig.controlGateService',
      'gate': gate,
      'side': side,
      'gateLocation': gate.toString(),
      'headerApiKeySource': 'gateConfig.apiKey',
      'bodyApiKeySource': 'gateConfig.keyPlc',
      'snapshot': _snapshotManager(manager),
    });

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

  Future<void> _logRunnerStart(
    AppStateManager appManager,
    AtkTransactionManager manager,
  ) async {
    await LogService.instance.logRequest('PSC_RUNNER_START', {
      'usuario': _usuario(),
      'kiosk': {
        'gate': appManager.kioskConfig?.gate,
        'gateLetter': appManager.kioskConfig?.gateLetter,
        'patio': appManager.kioskConfig?.patio,
        'kioskServer': appManager.kioskConfig?.kioskServer,
        'kioskServerPort': appManager.kioskConfig?.kioskServerPort,
      },
      'snapshot': _snapshotManager(manager),
    });
  }

  Future<void> _logStepPayload({
    required String step,
    required String path,
    required JsonMap payload,
    required AtkTransactionManager manager,
  }) async {
    await LogService.instance.logRequest('PSC_STEP_START', {
      'step': step,
      'path': path,
      'timestamp': DateTime.now().toIso8601String(),
    });

    await LogService.instance.logSpExec(
      service: 'PSC_$step',
      path: path,
      method: 'POST',
      payload: payload,
      context: {'snapshotBefore': _snapshotManager(manager)},
    );

    await LogService.instance.logRequest('PSC_STEP_PAYLOAD', {
      'step': step,
      'path': path,
      'payload': payload,
      'payloadPretty': _prettyJson(payload),
      'snapshotBefore': _snapshotManager(manager),
    });
  }

  Future<void> _logStepResult<T>({
    required String step,
    required String path,
    required PscApiEnvelope<T> res,
    required AtkTransactionManager manager,
  }) async {
    await LogService.instance.logSpResult(
      service: 'PSC_$step',
      path: path,
      errorCode: res.errorCode,
      message: res.message,
      data: {
        'raw': res.raw,
        'data': res.raw['data'],
        'snapshotAfter': _snapshotManager(manager),
      },
    );

    await LogService.instance.logRequest('PSC_STEP_RESULT', {
      'step': step,
      'path': path,
      'errorCode': res.errorCode,
      'message': res.message,
      'raw': res.raw,
      'rawPretty': _prettyJson(res.raw),
      'snapshotAfter': _snapshotManager(manager),
    });

    await LogService.instance.logRequest('PSC_MANAGER_SNAPSHOT', {
      'step': step,
      'snapshot': _snapshotManager(manager),
    });
  }

  Map<String, dynamic> _snapshotManager(AtkTransactionManager manager) {
    return {
      'vehiculoPlaca': manager.vehiculoPlaca,
      'pesoActualBascula': manager.pesoActualBascula,
      'driverCedula': manager.driverCedula,
      'driverName': manager.driverName,
      'driverEmpresa': manager.driverEmpresa,
      'driverLicenciaTipo': manager.driverLicenciaTipo,
      'driverLicenciaExp': manager.driverLicenciaExp,
      'transactionType': manager.transactionType,
      'isTruckEmpty': manager.isTruckEmpty,
      'ocrFlowType': manager.ocrFlowType,
      'ocrVehicleType': manager.get('ocrVehicleType'),
      'ocrContainerNumbers': manager.get('ocrContainerNumbers'),
      'contenedor': manager.contenedor,
      'side': manager.get('side'),
      'sideGate': manager.sideGate,
      'doorNumber': manager.get('doorNumber'),
      'rfidGate': manager.get('rfidGate'),
      'vehicleAccessId': _vehicleAccessId(manager),
      'atkId': manager.atkId,
      'numTrans': manager.numTrans,
      'conseguirConductorChofer': manager.conseguirConductorChofer,
      'conseguirConductorNumTran': manager.conseguirConductorNumTran,
      'conseguirConductorTipoTran': manager.conseguirConductorTipoTran,
      'conseguirConductorCodtipo': manager.conseguirConductorCodtipo,
      'conseguirConductorCodContenedor':
          manager.conseguirConductorCodContenedor,
      'conseguirDataConductorIdentificationNumber':
          manager.conseguirDataConductorIdentificationNumber,
      'conseguirDataConductorFullName': manager.conseguirDataConductorFullName,
      'conseguirDataConductorCompanyName':
          manager.conseguirDataConductorCompanyName,
      'pscRunning': manager.get('pscRunning'),
      'pscGuardado': manager.get('pscGuardado'),
      'pscTerminado': manager.get('pscTerminado'),
      'pscGateOpenRequested': manager.get('pscGateOpenRequested'),
      'pscGateOpenOk': manager.get('pscGateOpenOk'),
      'pscGateOpenGate': manager.get('pscGateOpenGate'),
      'pscGateOpenSide': manager.get('pscGateOpenSide'),
      'pscNavegarErrorCode': manager.get('pscNavegarErrorCode'),
      'pscNavegarMessage': manager.get('pscNavegarMessage'),
      'pscInicializarErrorCode': manager.get('pscInicializarErrorCode'),
      'pscInicializarMessage': manager.get('pscInicializarMessage'),
      'pscGuardarErrorCode': manager.get('pscGuardarErrorCode'),
      'pscGuardarMessage': manager.get('pscGuardarMessage'),
      'pscGuardarNumero': manager.get('pscGuardarNumero'),
      'pscTerminarErrorCode': manager.get('pscTerminarErrorCode'),
      'pscTerminarMessage': manager.get('pscTerminarMessage'),
      'hasError': manager.hasError,
      'errorMessage': manager.errorMessage,
      'isLoading': manager.isLoading,
      'mensajeInferior': manager.mensajeInferior,
      'driverPhotoUrlLen': manager.driverPhotoUrl?.length ?? 0,
      'driverAlerta': manager.driverAlerta,
      'driverId': manager.driverId,
      'pscDriverPhotoLoaded': manager.get('pscDriverPhotoLoaded'),
      'pscDriverPhotoId': manager.get('pscDriverPhotoId'),
      'pscDriverPhotoMessage': manager.get('pscDriverPhotoMessage'),
    };
  }

  String _prettyJson(dynamic value) {
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('Error:', '')
        .trim();
  }

  String _s(dynamic value) => (value ?? '').toString().trim();

  double? _double(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _int(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  int? _tpg(AppStateManager appManager) {
    final dynamic a = appManager;
    final dynamic kiosk = a.kioskConfig;

    final raw =
        (kiosk?.patio ?? kiosk?.tpg ?? kiosk?.group ?? kiosk?.groupType ?? '')
            .toString()
            .toUpperCase()
            .replaceAll('TPG', '')
            .trim();

    return int.tryParse(raw);
  }

  String? _garitaLetra(AppStateManager appManager) {
    final dynamic a = appManager;
    final dynamic kiosk = a.kioskConfig;

    final value =
        (kiosk?.gateLetter ?? kiosk?.garitaLetra ?? kiosk?.letter ?? '')
            .toString()
            .trim()
            .toUpperCase();

    return value.isEmpty ? null : value;
  }

  int _doorNumber(AtkTransactionManager manager) {
    return _int(
          manager.get('side') ?? manager.get('doorNumber') ?? manager.sideGate,
        ) ??
        0;
  }

  dynamic _vehicleAccessId(AtkTransactionManager manager) {
    return manager.get('vehicleAccessId') ??
        manager.get('vehiculoAccessId') ??
        manager.get('id') ??
        manager.get('atkId');
  }

  int? _vehicleAccessIdAsInt(AtkTransactionManager manager) {
    return int.tryParse((_vehicleAccessId(manager) ?? '').toString());
  }

  (String?, String?) _splitName(String? fullName) {
    final clean = (fullName ?? '').trim();
    if (clean.isEmpty) return (null, null);

    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length == 1) return (parts.first, null);

    return (parts.first, parts.skip(1).join(' '));
  }

  String _fechaBarreraNow() {
    final now = DateTime.now();

    String two(int value) => value.toString().padLeft(2, '0');

    return '${now.year}-'
        '${two(now.month)}-'
        '${two(now.day)} '
        '${two(now.hour)}:'
        '${two(now.minute)}:'
        '${two(now.second)}';
  }

  Future<void> _resetTransactionBeforeOcr(AtkTransactionManager manager) async {
    final before = _snapshotManager(manager);

    await LogService.instance.logRequest('PSC_RESET_BEFORE_OCR_START', {
      'reason': 'PSC completado correctamente; limpiando data antes de OCR',
      'snapshotBefore': before,
    });

    manager.resetAll();

    manager.resetAllWithDefaults({
      'mensajeInferior': null,
      'errorMessage': null,
      'ocrFacialStarted': false,
      'ocrFacialOk': false,
      'pscRunning': false,
      'pscGuardado': false,
      'pscTerminado': false,
      'pscGateOpenRequested': false,
      'pscGateOpenOk': false,
      'pscGateOpenGate': null,
      'pscGateOpenSide': null,
      'side': null,
      'doorNumber': null,
      'sideGate': null,
      'rfidGate': null,
    });

    await LogService.instance.logRequest('PSC_RESET_BEFORE_OCR_DONE', {
      'snapshotAfter': _snapshotManager(manager),
    });
  }

  Future<void> _loadDriverPhotoForPsc({
    required AppStateManager appManager,
    required AtkTransactionManager manager,
  }) async {
    final photoId = _resolveStaapisacPhotoId(manager);

    await LogService.instance.logRequest('PSC_DRIVER_PHOTO_START', {
      'photoId': photoId,
      'hasStaapisacAuth': appManager.hasStaapisacAuth,
      'driverCedula': manager.driverCedula,
      'driverId': manager.driverId,
      'conseguirDataConductorId': manager.conseguirDataConductorId,
      'conseguirDataConductorIdentificationNumber':
          manager.conseguirDataConductorIdentificationNumber,
    });

    if (photoId.isEmpty) {
      manager.setManyWithoutNotify({
        'driverPhotoUrl': null,
        'driverAlerta': 'No se encontró ID para consultar foto del conductor.',
        'pscDriverPhotoLoaded': false,
        'pscDriverPhotoMessage': 'ID de foto vacío',
      });

      await LogService.instance.logWarning('PSC_DRIVER_PHOTO_SKIPPED', {
        'reason': 'No se encontró ID para consultar foto del conductor',
        'snapshot': _snapshotManager(manager),
      });

      return;
    }

    try {
      if (!appManager.hasStaapisacAuth) {
        await LogService.instance.logRequest('PSC_STAAPISAC_LOGIN_START', {
          'reason': 'No hay token STAAPISAC antes de consultar foto',
        });

        await _staapisacApi.loginStaapisac(appState: appManager);

        await LogService.instance.logRequest('PSC_STAAPISAC_LOGIN_OK', {
          'hasStaapisacAuth': appManager.hasStaapisacAuth,
        });
      }

      final imgB64 = await _staapisacApi.getFotoChoferBase64(
        appState: appManager,
        choferId: photoId,
      );

      final hasImage = imgB64 != null && imgB64.trim().isNotEmpty;

      manager.setMany({
        'driverPhotoUrl': hasImage ? imgB64 : null,
        'driverPhotoBase64': hasImage ? imgB64 : null,
        'driverAlerta': hasImage ? null : 'Conductor sin foto registrada.',
        'pscDriverPhotoLoaded': hasImage,
        'pscDriverPhotoId': photoId,
        'pscDriverPhotoMessage': hasImage ? 'OK' : 'Sin foto registrada',
      });

      await LogService.instance.logRequest('PSC_DRIVER_PHOTO_RESULT', {
        'photoId': photoId,
        'hasImage': hasImage,
        'imageLength': imgB64?.length ?? 0,
        'savedDriverPhotoUrl': hasImage,
        'savedDriverPhotoBase64': hasImage,
        'snapshot': _snapshotManager(manager),
      });
    } catch (e, st) {
      await LogService.instance.logError('PSC_DRIVER_PHOTO_ERROR', e, st);

      manager.setMany({
        'driverPhotoUrl': null,
        'driverAlerta': 'No se pudo consultar foto del conductor.',
        'pscDriverPhotoLoaded': false,
        'pscDriverPhotoId': photoId,
        'pscDriverPhotoMessage': _cleanError(e),
      });
    }
  }

  String _resolveStaapisacPhotoId(AtkTransactionManager manager) {
    final candidates = <String?>[
      manager.driverCedula,
      manager.conseguirDataConductorIdentificationNumber,
      manager.conseguirConductorChofer,
    ];

    for (final value in candidates) {
      final clean = value?.trim();
      if (clean != null && clean.isNotEmpty) {
        return clean;
      }
    }

    return '';
  }
}
