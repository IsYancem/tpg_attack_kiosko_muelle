// lib/services/apis/exm/exm_transaction_runner.dart
// Autor: Abraham Yance
// Fecha: 2025-12-16
// Descripción: Orquestador de transacción EXM (inicializar → guardar → terminar)

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/models/print/ticket_exm_model.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/rfidScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/error_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/exm/exm_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/image_cache_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/gate_control_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/atk_utils.dart';
import 'package:http/http.dart' as http;

class ExmTransactionRunner {
  final ExmService _exmService;
  final LogService _log;

  static const _progressDelay = Duration(milliseconds: 200);
  static bool _isRunning = false;
  static bool get isRunning => _isRunning;

  ExmTransactionRunner({ExmService? exmService, LogService? log})
    : _exmService = exmService ?? ExmService(),
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
    if (_isRunning) {
      _log.logWarning('EXM_RUNNER_SKIPPED', {
        'reason': 'Ya existe un runner ejecutándose',
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('⚠️ [EXM_RUNNER] Ignorando llamada: ya está corriendo');
      return;
    }

    _isRunning = true;
    final sw = Stopwatch()..start();

    try {
      // PASO 1: INICIALIZAR
      await _showProgress(
        manager,
        '🔐 Inicializando transacción de exportación vacíos...',
      );

      final inicializarResult = await _exmService.inicializar(
        manager,
        appManager,
      );

      if (inicializarResult['errorCode'] != 0) {
        await _handleError(
          context,
          manager,
          appManager,
          'inicializar',
          inicializarResult['message'] ?? 'Error en inicialización EXM',
        );
        return;
      }

      // PASO 2: Validar datos antes de guardar
      await _showProgress(manager, '✅ Validando datos recibidos...');

      try {
        _validateDataForGuardar(manager);
      } catch (e) {
        _log.logError('EXM_VALIDATION_FAILED', e, StackTrace.current);
        await _handleError(
          context,
          manager,
          appManager,
          'validación',
          'Datos incompletos del inicializador: $e',
        );
        return;
      }

      // PASO 3: GUARDAR
      await _showProgress(manager, '💾 Guardando transacción...');

      _log.logRequest('EXM_GUARDAR_CALL', {
        'timestamp': DateTime.now().toIso8601String(),
        'atkId': manager.atkId,
        'placa': manager.vehiculoPlaca,
      });

      final guardarResult = await _exmService.guardar(manager, appManager);

      _log.logRequest('EXM_GUARDAR_RESPONSE', {
        'timestamp': DateTime.now().toIso8601String(),
        'errorCode': guardarResult['errorCode'],
      });

      // PASO 3.1: RECARGAR DATOS (DISV)
      await _showProgress(
        manager,
        '🔄 Recargando datos del contenedor (DISV)...',
      );

      try {
        final recargarResult = await _exmService.recargarDatos(
          manager,
          appManager,
        );

        if (recargarResult['errorCode'] != 0) {
          _log.logWarning('EXM_RECARGAR_DATOS_FAILED', {
            'message': recargarResult['message'],
            'errorCode': recargarResult['errorCode'],
          });

          await _showProgress(
            manager,
            '⚠️ No se pudo recargar datos (continuando)...',
          );
        } else {
          await _showProgress(manager, '✅ Datos recargados correctamente');
        }
      } catch (e, st) {
        _log.logError('EXM_RECARGAR_DATOS_EXCEPTION', e, st);
        await _showProgress(
          manager,
          '⚠️ Error recargando datos (continuando)...',
        );
      }

      if (guardarResult['errorCode'] != 0) {
        await _handleError(
          context,
          manager,
          appManager,
          'guardar',
          guardarResult['message'] ?? 'Error al guardar EXM',
        );
        return;
      }

      // PASO 3: CONSULTAR RUTA (proyección y mapa)
      await _showProgress(
        manager,
        '🗺️ Consultando proyección y generando ticket de ubicación...',
      );

      Map<String, dynamic>? rutaResult;

      try {
        rutaResult = await _exmService.consultarRuta(manager, appManager);

        if (rutaResult['errorCode'] != 0) {
          _log.logWarning('EXM_RUTA_FAILED', {
            'message': rutaResult['message'],
            'errorCode': rutaResult['errorCode'],
          });
          await _showProgress(
            manager,
            '⚠️ Servicio de ubicación no disponible, continuando...',
          );
        } else {
          _log.logRequest('EXM_RUTA_SUCCESS', {
            'errorCode': rutaResult['errorCode'],
            'message': rutaResult['message'],
          });

          // Extraer y cachear el mapa
          await _procesarMapaRuta(rutaResult, manager);

          await _showProgress(manager, '✅ Ubicación generada exitosamente');
        }
      } catch (e, st) {
        _log.logError('EXM_RUTA_EXCEPTION', e, st);
        await _showProgress(
          manager,
          '⚠️ Error en servicio de ubicación, continuando...',
        );
      }

      if (rutaResult != null) {
        manager.setManyWithoutNotify({'rutaResult': rutaResult});
      }

      // PASO 4: TERMINAR
      await _showProgress(manager, '🚧 Finalizando y abriendo barrera...');

      final terminarResult = await _exmService.terminar(manager, appManager);

      if (terminarResult['errorCode'] != 0) {
        await _handleError(
          context,
          manager,
          appManager,
          'terminar',
          terminarResult['message'] ?? 'Error al terminar EXM',
        );
        return;
      }

      // PASO 5: ÉXITO - Actualizar UI
      await _showProgress(manager, '✅ Transacción completada exitosamente');

      manager.setMany({
        'isLoading': false,
        'tituloPantalla': 'EXPORTACIÓN VACÍOS',
        'mensajeInferior':
            'Transacción completada exitosamente.\nSu comprobante ha sido generado.\nPuede continuar hacia la salida.',
      });

      // PASO 6: Background tasks (fire-and-forget)
      _executeBackgroundTasks(manager, appManager, rutaResult);

      _log.logRequest('EXM_COMPLETE', {
        'latency_ms': sw.elapsedMilliseconds,
        'atkId': manager.atkId,
      });

      // PASO 7: Esperar 15 segundos y resetear
      await Future.delayed(const Duration(seconds: 15));

      manager.resetAll();
      manager.setFlowRemainingSeconds(null);

      if (context.mounted) {
        _navigateToRfid(context);
      }
    } catch (e, st) {
      _log.logError('EXM_RUNNER_EX', e, st);
      manager.setMany({
        'isLoading': false,
        'hasError': true,
        'errorMessage': 'Error ejecutando servicio EXM: $e',
        'mensajeInferior': 'Error ejecutando servicio EXM: $e',
      });
      if (context.mounted) _navigateToError(context, '$e');
    } finally {
      _isRunning = false;
      _log.logRequest('EXM_RUNNER_END', {
        'latency_ms': sw.elapsedMilliseconds,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  // Después de inicializar, antes de guardar
  void _validateDataForGuardar(AtkTransactionManager manager) {
    final missingFields = <String>[];

    if (manager.atkId == null || manager.atkId!.isEmpty)
      missingFields.add('atkId');
    if (manager.vehiculoPlaca == null || manager.vehiculoPlaca!.isEmpty)
      missingFields.add('placa');
    if (manager.contenedor1 == null || manager.contenedor1!.isEmpty)
      missingFields.add('contenedor');
    if (manager.pesoIngreso == null || manager.pesoIngreso!.isEmpty)
      missingFields.add('pesoIngreso');
    if (manager.pesoTara == null || manager.pesoTara!.isEmpty)
      missingFields.add('pesoTara');

    if (missingFields.isNotEmpty) {
      throw Exception(
        '❌ Campos faltantes del inicializador: ${missingFields.join(", ")}',
      );
    }

    // Validar que tara sea mayor a 0
    final tara = double.tryParse(manager.pesoTara ?? '0') ?? 0;
    if (tara <= 0) {
      throw Exception('❌ Tara debe ser mayor a 0. Tara recibida: $tara');
    }
  }

  Future<void> _procesarMapaRuta(
    Map<String, dynamic> rutaResult,
    AtkTransactionManager manager,
  ) async {
    try {
      final data = rutaResult['data'] as Map<String, dynamic>?;
      if (data == null) return;

      final printData = data['print'] as Map<String, dynamic>?;
      if (printData == null) return;

      final mapa = printData['mapa'] as Map<String, dynamic>?;
      if (mapa == null) return;

      final mapaUrl = mapa['ruta']?.toString();
      if (mapaUrl == null || mapaUrl.isEmpty) return;

      manager.setManyWithoutNotify({'mapaUrl': mapaUrl});

      final bytes = await ImageCacheService.instance.getImage(mapaUrl);
      if (bytes != null) {
        manager.setManyWithoutNotify({'mapaBytes': bytes});
        print('✅ [EXM_RUNNER] Mapa cacheado y guardado en manager');
      }
    } catch (e) {
      print('⚠️ [EXM_RUNNER] Error procesando mapa: $e');
    }
  }

  Future<void> _handleError(
    BuildContext context,
    AtkTransactionManager manager,
    AppStateManager appManager,
    String paso,
    String errorMessage,
  ) async {
    _log.logWarning('EXM_ERROR_$paso', {'error': errorMessage});

    await _showProgress(
      manager,
      '⚠️ Error detectado, cancelando transacción...',
    );

    try {
      await _exmService.cancelar(manager, appManager);
      await _showProgress(manager, '🔄 Transacción cancelada correctamente');
    } catch (e) {
      _log.logError('EXM_CANCELAR_FAILED', e, StackTrace.current);
      await _showProgress(manager, '❌ Error al cancelar transacción');
    }

    manager.setMany({
      'isLoading': false,
      'hasError': true,
      'errorMessage': errorMessage,
      'mensajeInferior': errorMessage,
    });

    if (context.mounted) {
      _navigateToError(context, errorMessage);
    }
  }

  void _executeBackgroundTasks(
    AtkTransactionManager manager,
    AppStateManager appManager,
    Map<String, dynamic>? rutaResult,
  ) {
    final controlUrl = appManager.kioskConfig!.controlGateService;
    final gateLocation = appManager.gateConfig!.gateLocation;
    final apiKeyHeader = appManager.gateConfig!.apiKey;
    final apiKeyBody = appManager.gateConfig!.keyPlc;
    final gateNumber = int.tryParse(appManager.kioskConfig!.gate);
    final originalSide = int.tryParse(manager.sideGate ?? '') ?? 1;
    final sideNumber = AtkUtils.invertSide(originalSide);

    Future.wait([
      _imprimirTicketCombinado(manager, appManager, rutaResult),
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
      _log.logWarning('EXP_GATE_OPEN_FAILED', {'error': '$e'});
    }
  }

  Future<void> _imprimirTicketCombinado(
    AtkTransactionManager manager,
    AppStateManager appManager,
    Map<String, dynamic>? rutaResult,
  ) async {
    try {
      Map<String, dynamic>? rutaData;
      String? ubicacion;
      String? bloque;
      String? bahia;
      String? danios;
      Uint8List? mapaImageBytes;

      String? mapaUrl; // ✅ 1) DECLARAR AQUÍ (fuera del if)

      if (rutaResult != null && rutaResult['errorCode'] == 0) {
        rutaData = rutaResult['data'] as Map<String, dynamic>?;
        if (rutaData != null) {
          final printData = rutaData['print'] as Map<String, dynamic>?;
          if (printData != null) {
            final info = printData['info'] as Map<String, dynamic>?;
            if (info != null) {
              ubicacion = info['ubicacion']?.toString();
              bloque = info['bloque']?.toString();
              bahia = info['bahia']?.toString();
              danios = info['danios']?.toString();
            }

            final mapa = printData['mapa'] as Map<String, dynamic>?;
            if (mapa != null) {
              mapaUrl = mapa['ruta']?.toString(); // ✅ 2) ASIGNAR AQUÍ
              if (mapaUrl != null && mapaUrl.isNotEmpty) {
                try {
                  mapaImageBytes = await _descargarImagenMapa(mapaUrl);
                } catch (e) {
                  print('❌ Error descargando imagen del mapa: $e');
                  mapaUrl =
                      'https://www.tpg.com.ec/MapaTPG/default.png'; // opcional
                  mapaImageBytes = await _descargarImagenMapa(mapaUrl);
                }
              }
            }
          }
        }
      }

      final ticketData = TicketExmModel(
        atkId: int.tryParse(manager.atkId ?? '0') ?? 0,
        placa: manager.vehiculoPlaca ?? '',
        contenedor: manager.contenedor1 ?? manager.contenedorExp ?? '',
        clienteExportador: manager.clienteExp ?? '',
        producto: manager.productoExp ?? '',
        booking: manager.bookingExp ?? '',
        nave: manager.naveExp ?? '',
        pesoIngreso:
            manager.pesoIngreso ?? manager.pesoActualBascula.toString(),
        tara: manager.pesoTara ?? '0',
        tipoCarga: manager.vehiculoTipoCarga ?? '',
        cargaIMO: manager.vehiculoCargaImo ?? 'N',
        refrigerado: manager.vehiculoRefrigerado ?? 'N',
        entrada:
            manager.exmFechaIng ??
            manager.exmMonitorFechaBarrera?.toString() ??
            _formatearFechaActual(),
        choferNombre: manager.driverName ?? '',
        choferCedula: manager.driverCedula ?? '',
        observaciones: (danios != null && danios.trim().isNotEmpty)
            ? danios.trim()
            : (manager.vehiculoObservaciones?.trim().isNotEmpty == true
                  ? manager.vehiculoObservaciones!.trim()
                  : null),
      );

      await PrintService.printExmTicketCombinado(
        ticketData: ticketData,
        ubicacion: ubicacion,
        bloque: bloque,
        bahia: bahia,
        danios: danios,
        mapaUrl: mapaUrl,
        mapaImageBytes: mapaImageBytes,
        saveToSpecificPath: true,
        autoPrint: true,
      );
    } catch (e, st) {
      _log.logError('EXM_PRINT_TICKET_ERROR', e, st);
      // Intenta imprimir solo el ticket EXP (sin datos de ruta)
      try {
        final ticketData = TicketExmModel(
          atkId: int.tryParse(manager.atkId ?? '0') ?? 0,
          placa: manager.vehiculoPlaca ?? '',
          contenedor: manager.contenedor1 ?? manager.contenedorExp ?? '',
          clienteExportador: manager.clienteExp ?? '',
          producto: manager.productoExp ?? '',
          booking: manager.bookingExp ?? '',
          nave: manager.naveExp ?? '',
          pesoIngreso:
              manager.pesoIngreso ?? manager.pesoActualBascula.toString(),
          tara: manager.pesoTara ?? '0',
          tipoCarga: manager.vehiculoTipoCarga ?? '',
          cargaIMO: manager.vehiculoCargaImo ?? 'N',
          refrigerado: manager.vehiculoRefrigerado ?? 'N',
          entrada: _formatearFechaActual(),
          choferNombre: manager.driverName ?? '',
          choferCedula: manager.driverCedula ?? '',
        );

        await PrintService.printExmTicket(
          ticketData: ticketData,
          saveToSpecificPath: true,
          autoPrint: true,
        );
      } catch (e2, st2) {
        _log.logError('EXM_PRINT_FALLBACK_ERROR', e2, st2);
      }
    }
  }

  Future<Uint8List?> _descargarImagenMapa(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print('❌ Error al descargar imagen: $e');
    }
    return null;
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
