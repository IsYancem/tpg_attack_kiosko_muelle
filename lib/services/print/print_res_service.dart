// lib/services/print/print_res_service.dart
// Autor: Abraham Yance
// Fecha: 2025-12-29
// Servicio de impresión para tickets RES

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;

import 'package:tpg_attack_kiosko_muelle/models/print/ticket_res_model.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_utils.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_auto_service.dart';

class PrintResService {
  static Future<bool> printTicket({
    required TicketResModel ticketData,
    bool saveToSpecificPath = true,
    bool autoPrint = true,
  }) async {
    await LogService.instance.logRequest('PrintResService.printTicket', {
      'action': 'creating_res_ticket_pdf',
      'atkId': ticketData.atkId,
      'placa': ticketData.placa,
      'save_to_specific_path': saveToSpecificPath,
      'auto_print': autoPrint,
    });

    try {
      final pdf = pw.Document();
      final logoBytes = await PrintUtils.loadLogoBytes();

      // ✅ QR Payload (mismo patrón: json completo + tipo)
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
                    'SERVICIO RES',
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
                    width: 120,
                    height: 120,
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

        await LogService.instance.logRequest('PrintResService.printTicket', {
          'action': 'res_ticket_saved_successfully',
          'path': file.path,
          'file_name': fileName,
        });

        if (autoPrint && Platform.isWindows) {
          final printResult = await PrintAutoService.printPdfSilently(file);
          await LogService.instance.logRequest('PrintResService.printTicket', {
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
      await LogService.instance.logError('PrintResService.printTicket', e, st);
      return false;
    }
  }

  static Map<String, dynamic> _buildQrPayload(TicketResModel t) {
    return {
      'tipo': 'RES',
      'ticket': t.toJson(),
      'fecha_hora_impresion': DateTime.now().toIso8601String(),
    };
  }

  static pw.Widget _buildTicketContent(TicketResModel t) {
    pw.Widget kv(String k, String? v, {bool bold = false}) {
      final val = (v == null || v.trim().isEmpty) ? '-' : v.trim();
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              flex: 45,
              child: pw.Text(k, style: const pw.TextStyle(fontSize: 8)),
            ),
            pw.Expanded(
              flex: 55,
              child: pw.Text(
                val,
                textAlign: pw.TextAlign.right,
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget sectionTitle(String txt) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
      child: pw.Text(
        txt,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    );

    String kg(String? n) => '${(n == null || n.isEmpty) ? '0' : n} Kg';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        sectionTitle('DATOS DE TRANSACCIÓN'),
        kv(
          'N° COMPROBANTE',
          (t.numeroComprobante ?? t.atkId).toString(),
          bold: true,
        ),
        kv('PLACA', t.placa, bold: true),
        if (t.contenedor != null && t.contenedor!.isNotEmpty)
          kv('CONTENEDOR', t.contenedor, bold: true),
        kv('ESTADO', t.estado),

        sectionTitle('FECHAS'),
        kv('INGRESO', t.fechaHoraIng, bold: true),
        kv('SALIDA', t.fechaHoraSal, bold: true),
        kv('EMISIÓN', t.fechaEmisionDocumento),

        sectionTitle('PESOS'),
        kv('PESO INGRESO', kg(t.pesoIng), bold: true),
        kv('PESO SALIDA', kg(t.pesoSal), bold: true),
        kv('TARA CONTENEDOR', kg(t.taraContenedor), bold: true),
        PrintUtils.buildSeparatorLine(),
        kv('PESO NETO', kg(t.pesoNeto), bold: true),
        kv('PESO NETO + TARA', kg(t.pesoNetoMasTara), bold: true),

        sectionTitle('CARGA'),
        kv('PRODUCTO', t.producto, bold: true),
        kv('TIPO CARGA', t.tipoCarga, bold: true),

        sectionTitle('USUARIOS'),
        kv('USUARIO INICIAL', t.usuario, bold: true),
        kv('USUARIO FINAL', t.usuarioFinal, bold: true),
        kv('USUARIO SISTEMA', t.nombreUsuario, bold: true),

        sectionTitle('CONDUCTOR'),
        kv('NOMBRE', t.choferNombre, bold: true),
        kv('CÉDULA', t.choferCedula, bold: true),

        if (t.observaciones != null && t.observaciones!.trim().isNotEmpty) ...[
          sectionTitle('OBSERVACIONES'),
          pw.Text(
            t.observaciones!.trim(),
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ],
    );
  }

  static String _buildFileName(TicketResModel t) {
    final fecha = DateFormat('dd_MM_yyyy').format(DateTime.now());
    final placaSafe = (t.placa.isEmpty ? 'SIN_PLACA' : t.placa).replaceAll(
      RegExp(r'[^\w\-]'),
      '_',
    );
    final num = (t.numeroComprobante ?? t.atkId).toString();
    return '${fecha}_RES_${placaSafe}_$num.pdf';
  }

  static Future<File> _savePdfBytes(Uint8List bytes, String fileName) async {
    final base = await PrintUtils.getApplicationDocumentsDir();
    final dir = Directory(p.join(base.path, 'Tickets RES'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
