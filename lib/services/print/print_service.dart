// lib/services/print/print_service.dart
// Autor: Abraham Yance
// Fecha: 2025-12-10
// Descripción: Servicio principal de impresión que actúa como fachada
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tpg_attack_kiosko_muelle/models/dspcs/dspcs_transaccion_response_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/print/ticket_dspCS_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/print/ticket_dsp_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/print/ticket_exm_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/print/ticket_res_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/print/ticket_trl_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/print/ticket_exp_model.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_exm_ruta_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_exm_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_exp_ruta_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_res_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_result.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_dsp_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_dsp_cs_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_trl_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_exp_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_auto_service.dart';

class PrintService {
  static final PrintService _instance = PrintService._internal();
  factory PrintService() => _instance;
  PrintService._internal();

  /// Inicia el proceso de impresión según el tipo de ticket
  static Future<bool> startPrint({
    required String tipo,
    required dynamic ticketData,
    Uint8List? mapaImageBytes,
    List<DspCsDresConsItem>? dresData,
    bool saveToSpecificPath = true,
    bool autoPrint = true,
  }) async {
    LogService.instance.logRequest('PrintService.startPrint', {
      'action': 'starting_print_process',
      'tipo': tipo,
      'save_to_specific_path': saveToSpecificPath,
      'auto_print': autoPrint,
      'has_map_image': mapaImageBytes != null,
      'has_dres_data': dresData?.isNotEmpty ?? false,
      'ticket_data_type': ticketData.runtimeType.toString(),
    });

    try {
      switch (tipo.toUpperCase()) {
        case 'DSP':
          return await PrintDspService.printTicket(
            ticketData: ticketData as TicketDspModel,
            mapaImageBytes: mapaImageBytes,
            saveToSpecificPath: saveToSpecificPath,
            autoPrint: autoPrint,
          );

        case 'DSP-CS':
          return await PrintDspCsService.printTicket(
            ticketData: ticketData as TicketDspCsModel,
            dresData: dresData,
            saveToSpecificPath: saveToSpecificPath,
            autoPrint: autoPrint,
          );

        case 'TRL':
          return await PrintTrlService.printTicket(
            ticketData: ticketData as TicketTrlModel,
            saveToSpecificPath: saveToSpecificPath,
            autoPrint: autoPrint,
          );

        case 'EXP':
          return await PrintExpService.printTicket(
            ticketData: ticketData as TicketExpModel,
            saveToSpecificPath: saveToSpecificPath,
            autoPrint: autoPrint,
          );

        case 'EXM':
          return await PrintExmService.printTicket(
            ticketData: ticketData as TicketExmModel,
            saveToSpecificPath: saveToSpecificPath,
            autoPrint: autoPrint,
          );

        case 'RES':
          return await PrintResService.printTicket(
            ticketData: ticketData as TicketResModel,
            saveToSpecificPath: saveToSpecificPath,
            autoPrint: autoPrint,
          );

        default:
          LogService.instance.logWarning('PrintService.startPrint', {
            'warning': 'unsupported_print_type',
            'tipo': tipo,
          });
          return false;
      }
    } catch (e, st) {
      LogService.instance.logError('PrintService.startPrint', e, st);
      return false;
    }
  }

  /// Método directo para imprimir ticket RES
  static Future<bool> printResTicket({
    required TicketResModel ticketData,
    bool saveToSpecificPath = true,
    bool autoPrint = true,
  }) async {
    return await PrintResService.printTicket(
      ticketData: ticketData,
      saveToSpecificPath: saveToSpecificPath,
      autoPrint: autoPrint,
    );
  }

  /// Método directo para imprimir ticket DSP
  static Future<bool> printDspTicket({
    required TicketDspModel ticketData,
    Uint8List? mapaImageBytes,
    bool saveToSpecificPath = true,
    bool autoPrint = true,
  }) async {
    return await PrintDspService.printTicket(
      ticketData: ticketData,
      mapaImageBytes: mapaImageBytes,
      saveToSpecificPath: saveToSpecificPath,
      autoPrint: autoPrint,
    );
  }

  /// Método directo para imprimir ticket DSP-CS
  static Future<bool> printDspCsTicket({
    required TicketDspCsModel ticketData,
    List<DspCsDresConsItem>? dresData,
    bool saveToSpecificPath = true,
    bool autoPrint = true,
  }) async {
    return await PrintDspCsService.printTicket(
      ticketData: ticketData,
      dresData: dresData,
      saveToSpecificPath: saveToSpecificPath,
      autoPrint: autoPrint,
    );
  }

  /// Método directo para imprimir ticket TRL
  static Future<bool> printTrlTicket({
    required TicketTrlModel ticketData,
    bool saveToSpecificPath = true,
    bool autoPrint = true,
  }) async {
    return await PrintTrlService.printTicket(
      ticketData: ticketData,
      saveToSpecificPath: saveToSpecificPath,
      autoPrint: autoPrint,
    );
  }

  /// ✅ NUEVO: Método directo para imprimir ticket EXP
  static Future<bool> printExpTicket({
    required TicketExpModel ticketData,
    bool saveToSpecificPath = true,
    bool autoPrint = true,
  }) async {
    return await PrintExpService.printTicket(
      ticketData: ticketData,
      saveToSpecificPath: saveToSpecificPath,
      autoPrint: autoPrint,
    );
  }

  /// Método para imprimir automáticamente un archivo PDF
  static Future<PrintResult> printPdfFile(File pdfFile) async {
    return await PrintAutoService.printPdfSilently(pdfFile);
  }

  /// ✅ NUEVO: Método para imprimir ticket EXP combinado con datos de RUTA
  static Future<bool> printExpTicketCombinado({
    required TicketExpModel ticketData,
    String? ubicacion,
    String? bloque,
    String? bahia,
    String? danios,
    String? mapaUrl,
    Uint8List? mapaImageBytes,
    bool saveToSpecificPath = true,
    bool autoPrint = true,
  }) async {
    try {
      // Si no hay datos de RUTA, imprimir ticket normal
      if (ubicacion == null) {
        return await PrintExpService.printTicket(
          ticketData: ticketData,
          saveToSpecificPath: saveToSpecificPath,
          autoPrint: autoPrint,
        );
      }

      // Crear un servicio combinado
      return await PrintExpRutaService.printTicketCombinado(
        ticketData: ticketData,
        ubicacion: ubicacion,
        bloque: bloque,
        bahia: bahia,
        danios: danios,
        mapaUrl: mapaUrl,
        mapaImageBytes: mapaImageBytes,
        saveToSpecificPath: saveToSpecificPath,
        autoPrint: autoPrint,
      );
    } catch (e, st) {
      LogService.instance.logError('PRINT_EXP_COMBINADO_ERROR', e, st);
      // Fallback a ticket normal
      return await PrintExpService.printTicket(
        ticketData: ticketData,
        saveToSpecificPath: saveToSpecificPath,
        autoPrint: autoPrint,
      );
    }
  }

  /// Método directo para imprimir ticket EXM
  static Future<bool> printExmTicket({
    required TicketExmModel ticketData,
    bool saveToSpecificPath = true,
    bool autoPrint = true,
  }) async {
    return await PrintExmService.printTicket(
      ticketData: ticketData,
      saveToSpecificPath: saveToSpecificPath,
      autoPrint: autoPrint,
    );
  }

  /// Método para imprimir ticket EXM combinado con datos de RUTA
  static Future<bool> printExmTicketCombinado({
    required TicketExmModel ticketData,
    String? ubicacion,
    String? bloque,
    String? bahia,
    String? danios,
    String? mapaUrl,
    Uint8List? mapaImageBytes,
    bool saveToSpecificPath = true,
    bool autoPrint = true,
  }) async {
    try {
      // Si no hay datos de RUTA, imprimir ticket normal
      if (ubicacion == null) {
        return await PrintExmService.printTicket(
          ticketData: ticketData,
          saveToSpecificPath: saveToSpecificPath,
          autoPrint: autoPrint,
        );
      }

      // Crear un servicio combinado
      return await PrintExmRutaService.printTicketCombinado(
        ticketData: ticketData,
        ubicacion: ubicacion,
        bloque: bloque,
        bahia: bahia,
        danios: danios,
        mapaUrl: mapaUrl,
        mapaImageBytes: mapaImageBytes,
        saveToSpecificPath: saveToSpecificPath,
        autoPrint: autoPrint,
      );
    } catch (e, st) {
      LogService.instance.logError('PRINT_EXM_COMBINADO_ERROR', e, st);
      // Fallback a ticket normal
      return await PrintExmService.printTicket(
        ticketData: ticketData,
        saveToSpecificPath: saveToSpecificPath,
        autoPrint: autoPrint,
      );
    }
  }
}
