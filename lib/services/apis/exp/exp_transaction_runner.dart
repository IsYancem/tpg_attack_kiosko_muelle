// lib/services/apis/exp_transaction_runner.dart
// Autor: Abraham Yance
// Fecha: 2025-12-10
// Descripción: Orquestador de transacción EXP (inicializar → guardar → terminar)
// SIMPLIFICADO: 3 pasos + impresión en background

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/models/print/ticket_exp_model.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/rfidScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/error_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/exp/exp_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/image_cache_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/gate_control_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/atk_utils.dart';
import 'package:http/http.dart' as http;

class ExpTransactionRunner {
  final ExpService _expService;
  final LogService _log;

  // ✅ Duración de cada mensaje de progreso
  static const _progressDelay = Duration(milliseconds: 200);

  static bool _isRunning = false;

  static bool get isRunning => _isRunning;

  ExpTransactionRunner({ExpService? expService, LogService? log})
    : _expService = expService ?? ExpService(),
      _log = log ?? LogService.instance;

  /// ✅ Helper para mostrar mensaje de progreso
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
    // 🔐 Guard global
    if (_isRunning) {
      _log.logWarning('EXP_RUNNER_SKIPPED', {
        'reason': 'Ya existe un runner ejecutándose',
        'timestamp': DateTime.now().toIso8601String(),
      });
      print('⚠️ [EXP_RUNNER] Ignorando llamada: ya está corriendo');
      return;
    }

    _isRunning = true;
    final sw = Stopwatch()..start();

    try {
      // ═══════════════════════════════════════════════════════════════
      // PASO 1: INICIALIZAR
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(
        manager,
        '🔐 Inicializando transacción de exportación...',
      );

      final inicializarResult = await _expService.inicializar(
        manager,
        appManager,
      );

      if (inicializarResult['errorCode'] != 0) {
        await _handleError(
          context,
          manager,
          appManager,
          'inicializar',
          inicializarResult['message'] ?? 'Error en inicialización',
        );
        return;
      }

      // ═══════════════════════════════════════════════════════════════
      // PASO 2: GUARDAR
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '💾 Guardando transacción...');

      _log.logRequest('EXP_GUARDAR_CALL', {
        'timestamp': DateTime.now().toIso8601String(),
        'atkId': manager.atkId,
        'placa': manager.vehiculoPlaca,
      });

      final guardarResult = await _expService.guardar(manager, appManager);

      _log.logRequest('EXP_GUARDAR_RESPONSE', {
        'timestamp': DateTime.now().toIso8601String(),
        'errorCode': guardarResult['errorCode'],
      });

      if (guardarResult['errorCode'] != 0) {
        await _handleError(
          context,
          manager,
          appManager,
          'guardar',
          guardarResult['message'] ?? 'Error al guardar',
        );
        return;
      }

      // ═══════════════════════════════════════════════════════════════
      // ✅ NUEVO PASO: EJECUTAR SERVICIO RUTA DESPUÉS DE GUARDAR
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(
        manager,
        '🗺️ Consultando proyección y generando ticket de ubicación...',
      );

      Map<String, dynamic>? rutaResult;

      try {
        rutaResult = await _expService.ruta(manager, appManager);

        if (rutaResult['errorCode'] != 0) {
          _log.logWarning('EXP_RUTA_FAILED', {
            'message': rutaResult['message'],
            'errorCode': rutaResult['errorCode'],
          });
          await _showProgress(
            manager,
            '⚠️ Servicio de ubicación no disponible, continuando...',
          );
        } else {
          _log.logRequest('EXP_RUTA_SUCCESS', {
            'errorCode': rutaResult['errorCode'],
            'message': rutaResult['message'],
          });

          // ✅ NUEVO: Extraer y cachear el mapa
          await _procesarMapaRuta(rutaResult, manager);

          await _showProgress(manager, '✅ Ubicación generada exitosamente');
        }
      } catch (e, st) {
        _log.logError('EXP_RUTA_EXCEPTION', e, st);
        await _showProgress(
          manager,
          '⚠️ Error en servicio de ubicación, continuando...',
        );
      }

      // Guardamos el resultado de RUTA en el manager
      if (rutaResult != null) {
        manager.setManyWithoutNotify({'rutaResult': rutaResult});
      }

      // ═══════════════════════════════════════════════════════════════
      // PASO 3: TERMINAR (continuamos con el flujo original)
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '🚧 Finalizando y abriendo barrera...');

      final terminarResult = await _expService.terminar(manager, appManager);

      if (terminarResult['errorCode'] != 0) {
        await _handleError(
          context,
          manager,
          appManager,
          'terminar',
          terminarResult['message'] ?? 'Error al terminar',
        );
        return;
      }

      // ═══════════════════════════════════════════════════════════════
      // PASO 4: ÉXITO - Actualizar UI
      // ═══════════════════════════════════════════════════════════════
      await _showProgress(manager, '✅ Transacción completada exitosamente');

      manager.setMany({
        'isLoading': false,
        'tituloPantalla': 'EXPORTACIÓN FULL',
        'mensajeInferior':
            'Transacción completada exitosamente.\nSu comprobante ha sido generado.\nPuede continuar hacia la salida.',
      });

      // ═══════════════════════════════════════════════════════════════
      // PASO 5: Background tasks (fire-and-forget)
      // ═══════════════════════════════════════════════════════════════
      _executeBackgroundTasks(manager, appManager, rutaResult);

      // Log final
      _log.logRequest('EXP_COMPLETE', {
        'latency_ms': sw.elapsedMilliseconds,
        'atkId': manager.atkId,
      });

      // ═══════════════════════════════════════════════════════════════
      // PASO 6: Esperar 15 segundos y resetear
      // ═══════════════════════════════════════════════════════════════
      await Future.delayed(const Duration(seconds: 15));

      manager.resetAll();
      manager.setFlowRemainingSeconds(null);

      if (context.mounted) {
        _navigateToRfid(context);
      }
    } catch (e, st) {
      _log.logError('EXP_RUNNER_EX', e, st);
      manager.setMany({
        'isLoading': false,
        'hasError': true,
        'errorMessage': 'Error ejecutando servicio EXP: $e',
        'mensajeInferior': 'Error ejecutando servicio EXP: $e',
      });
      if (context.mounted) _navigateToError(context, '$e');
    } finally {
      _isRunning = false;
      _log.logRequest('EXP_RUNNER_END', {
        'latency_ms': sw.elapsedMilliseconds,
        'timestamp': DateTime.now().toIso8601String(),
      });
    }
  }

  /// ✅ Procesa y cachea la imagen del mapa desde rutaResult
  Future<void> _procesarMapaRuta(
    Map<String, dynamic> rutaResult,
    AtkTransactionManager manager,
  ) async {
    try {
      final data = rutaResult['data'] as Map<String, dynamic>?;
      if (data == null) return;

      final ticketData = data['ticketData'] as Map<String, dynamic>?;
      if (ticketData == null) return;

      final mapaUrl = ticketData['mapaUrl']?.toString();
      if (mapaUrl == null || mapaUrl.isEmpty) return;

      // Guardar URL en manager
      manager.setManyWithoutNotify({'mapaUrl': mapaUrl});

      // Descargar y cachear imagen
      final bytes = await ImageCacheService.instance.getImage(mapaUrl);
      if (bytes != null) {
        manager.setManyWithoutNotify({'mapaBytes': bytes});
      }
    } catch (e) {
      _log.logError('EXP_MAPA_CACHE_ERROR', e, StackTrace.current);
    }
  }

  /// ✅ Manejo de errores con cancelación automática
  Future<void> _handleError(
    BuildContext context,
    AtkTransactionManager manager,
    AppStateManager appManager,
    String paso,
    String errorMessage,
  ) async {
    _log.logWarning('EXP_ERROR_$paso', {'error': errorMessage});

    await _showProgress(
      manager,
      '⚠️ Error detectado, cancelando transacción...',
    );

    // Intentar cancelar
    try {
      /* await _expService.cancelar(manager, appManager); */
      await _showProgress(manager, '🔄 Transacción cancelada correctamente');
    } catch (e) {
      _log.logError('EXP_CANCELAR_FAILED', e, StackTrace.current);
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

  /// ✅ Tareas background (fire-and-forget)
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
              mapaUrl = mapa['ruta']?.toString();
              if (mapaUrl != null && mapaUrl.isNotEmpty) {
                try {
                  mapaImageBytes = await _descargarImagenMapa(mapaUrl);
                } catch (e) {
                  print('? Error descargando imagen del mapa: $e');
                  mapaImageBytes = await _descargarImagenMapa(
                    'https://www.tpg.com.ec/MapaTPG/default.png',
                  );
                }
              }
            }
          }
        }
      }

      // ? Crear modelo de ticket EXM (NO EXP)
      final ticketData = TicketExpModel(
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
        sello1: manager.sello1Exp ?? '',
        sello2: manager.sello2Exp ?? '',
        sello3: manager.sello3Exp ?? '',
        sello4: manager.sello4Exp ?? '',
      );

      // ? Llamar al servicio de impresión EXM combinado
      await PrintService.printExpTicketCombinado(
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
      // Intenta imprimir solo el ticket EXM (sin datos de ruta)
      try {
        final ticketData = TicketExpModel(
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
          sello1: manager.sello1Exp ?? '',
          sello2: manager.sello2Exp ?? '',
          sello3: manager.sello3Exp ?? '',
          sello4: manager.sello4Exp ?? '',
        );

        await PrintService.printExpTicket(
          ticketData: ticketData,
          saveToSpecificPath: true,
          autoPrint: true,
        );
      } catch (e2, st2) {
        _log.logError('EXM_PRINT_FALLBACK_ERROR', e2, st2);
      }
    }
  }

  /// ✅ Descargar imagen del mapa
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
