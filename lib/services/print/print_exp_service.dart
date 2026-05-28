// lib/services/print/print_exp_service.dart
// Autor: Abraham Yance
// Fecha: 2025-12-10
// Descripción: Servicio de impresión para tickets de Exportación Full

import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:tpg_attack_kiosko_muelle/models/print/ticket_exp_model.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_utils.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_auto_service.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

/// Servicio de impresión para tickets EXP
class PrintExpService {
  /// Imprime un ticket EXP
  static Future<bool> printTicket({
    required TicketExpModel ticketData,
    bool saveToSpecificPath = true,
    bool autoPrint = true,
  }) async {
    await LogService.instance.logRequest('PrintExpService.printTicket', {
      'action': 'creating_exp_ticket_pdf',
      'atkId': ticketData.atkId,
      'placa': ticketData.placa,
      'contenedor': ticketData.contenedor,
      'save_to_specific_path': saveToSpecificPath,
      'auto_print': autoPrint,
    });

    try {
      final pdf = pw.Document();
      final logoBytes = await PrintUtils.loadLogoBytes();

      // 🔹 QR Payload optimizado
      final qrPayloadMap = _buildQrPayload(ticketData);
      final qrPayload = jsonEncode(qrPayloadMap);
      final qrCodeBytes = await PrintUtils.generateQrCode(qrPayload);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (_) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                PrintUtils.buildHeader(logoBytes),
                pw.SizedBox(height: 10),
                PrintUtils.buildSeparatorLine(),
                pw.Center(
                  child: pw.Text(
                    'EXPORTACIÓN FULL',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                PrintUtils.buildSeparatorLine(),
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Container(
                    width: 150,
                    height: 150,
                    child: pw.Image(pw.MemoryImage(qrCodeBytes)),
                  ),
                ),
                pw.SizedBox(height: 15),
                _buildTicketContent(ticketData),
                pw.SizedBox(height: 10),
                PrintUtils.buildSeparatorLine(),
                pw.SizedBox(height: 5),
                pw.Center(
                  child: pw.Text(
                    'Conserve este comprobante',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    'Verifique en la APP de TPG',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
              ],
            );
          },
        ),
      );

      if (saveToSpecificPath) {
        final pdfBytes = await pdf.save();
        final fileName = _buildFileName(ticketData);
        final file = await _savePdfBytes(pdfBytes, fileName);

        await LogService.instance.logRequest('PrintExpService.printTicket', {
          'action': 'exp_ticket_saved_successfully',
          'path': file.path,
          'file_name': fileName,
        });

        // Impresión automática
        if (autoPrint && Platform.isWindows) {
          final printResult = await PrintAutoService.printPdfSilently(file);
          await LogService.instance.logRequest('PrintExpService.printTicket', {
            'action': 'auto_print_result',
            'success': printResult.isSuccess,
            'message': printResult.message,
          });
          return printResult.isSuccess;
        }

        return true;
      } else {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdf.save(),
        );
        return true;
      }
    } catch (e, st) {
      await LogService.instance.logError('PrintExpService.printTicket', e, st);
      return false;
    }
  }

  // En la sección del método _buildQrPayload:
  /// 🔹 QR COMPLETO con TODOS los datos visibles en el ticket EXP
  static Map<String, dynamic> _buildQrPayload(TicketExpModel t) {
    final fmt = DateFormat('yyyy/MM/dd HH:mm');
    final nowFmt = fmt.format(DateTime.now());

    bool _has(dynamic v) {
      if (v == null) return false;
      if (v is String) return v.trim().isNotEmpty;
      return true;
    }

    void _put(Map<String, dynamic> m, String k, dynamic v) {
      if (_has(v)) m[k] = (v is String) ? v.trim() : v;
    }

    final payload = <String, dynamic>{};

    _put(payload, 'TITULO', 'EXPORTACION FULL');
    _put(
      payload,
      'ENTRADA',
      (t.entrada.trim().isNotEmpty) ? t.entrada.trim() : nowFmt,
    );

    _put(payload, 'TRANSACCION', t.atkId);
    _put(payload, 'PLACA', t.placa);
    _put(payload, 'CONTENEDOR', t.contenedor);

    _put(payload, 'EXPORTADOR', t.clienteExportador);
    _put(payload, 'PRODUCTO', t.producto);
    _put(payload, 'BOOKING', t.booking);
    _put(payload, 'NAVE', t.nave);
    _put(payload, 'TIPO CARGA', t.tipoCarga);

    _put(payload, 'PESO INGRESO', t.pesoIngreso);
    _put(payload, 'TARA', t.tara);

    _put(payload, 'SELLO 1', t.sello1);
    _put(payload, 'SELLO 2', t.sello2);
    _put(payload, 'SELLO 3', t.sello3);
    _put(payload, 'SELLO 4', t.sello4);

    _put(payload, 'CARGA IMO', t.cargaIMO);
    _put(payload, 'REFRIGERADO', t.refrigerado);

    _put(payload, 'CONDUCTOR', t.choferNombre);
    _put(payload, 'CEDULA', t.choferCedula);

    return payload;
  }

  /// Construye el contenido del ticket EXP
  static pw.Widget _buildTicketContent(TicketExpModel ticketData) {
    return pw.Column(
      children: [
        // Transacción y Placa
        PrintUtils.buildTwoColumnRow('TRANSACCIÓN', 'PLACA'),
        PrintUtils.buildTwoColumnRow(
          ticketData.atkId.toString(),
          ticketData.placa,
          isBold: true,
        ),
        pw.SizedBox(height: 7),

        // Contenedor
        PrintUtils.buildSingleColumnRow('CONTENEDOR'),
        PrintUtils.buildSingleColumnRow(ticketData.contenedor, isBold: true),
        pw.SizedBox(height: 7),

        pw.SizedBox(height: 7),

        // Producto y Tipo Carga
        PrintUtils.buildTwoColumnRow('BOOKING', 'TIPO CARGA'),
        PrintUtils.buildTwoColumnRow(
          ticketData.booking,
          ticketData.tipoCarga,
          isBold: true,
        ),
        pw.SizedBox(height: 7),

        // Pesos
        PrintUtils.buildTwoColumnRow('PESO INGRESO', 'TARA'),
        PrintUtils.buildTwoColumnRow(
          '${ticketData.pesoIngreso} Kg',
          '${ticketData.tara} Kg',
          isBold: true,
        ),
        pw.SizedBox(height: 7),

        // Características
        PrintUtils.buildTwoColumnRow('CARGA IMO', 'REFRIGERADO'),
        PrintUtils.buildTwoColumnRow(
          ticketData.cargaIMO,
          ticketData.refrigerado,
          isBold: true,
        ),
        pw.SizedBox(height: 7),

        // Entrada
        PrintUtils.buildSingleColumnRow('ENTRADA'),
        PrintUtils.buildSingleColumnRow(ticketData.entrada, isBold: true),
        pw.SizedBox(height: 7),

        // Chofer
        PrintUtils.buildSingleColumnRow('CONDUCTOR'),
        PrintUtils.buildSingleColumnRow(ticketData.choferNombre, isBold: true),
        PrintUtils.buildSingleColumnRow(
          'CI: ${ticketData.choferCedula}',
          isBold: true,
        ),
      ],
    );
  }

  /// Construye el nombre del archivo
  static String _buildFileName(TicketExpModel ticketData) {
    final fecha = DateFormat('dd_MM_yyyy').format(DateTime.now());
    final cedula =
        (ticketData.choferCedula.isEmpty
                ? 'SIN_CEDULA'
                : ticketData.choferCedula)
            .replaceAll(RegExp(r'[^\w\-]'), '_');
    return '${fecha}_EXP_${cedula}.pdf';
  }

  /// Guarda los bytes del PDF en el directorio específico
  static Future<File> _savePdfBytes(Uint8List bytes, String fileName) async {
    final base = await PrintUtils.getApplicationDocumentsDir();
    final dir = Directory(p.join(base.path, 'Tickets EXP'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
