// lib/services/print/print_dsp_cs_service.dart
// Autor: Abraham Yance
// Fecha: 2025-12-04
// Descripción: Servicio de impresión para tickets DSP-CS (Carga Suelta)

import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:tpg_attack_kiosko_muelle/models/dspcs/dspcs_transaccion_response_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/print/ticket_dspCS_model.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_utils.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_auto_service.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

/// Servicio de impresión para tickets DSP-CS (Carga Suelta)
class PrintDspCsService {
  /// Imprime un ticket DSP-CS
  static Future<bool> printTicket({
    required TicketDspCsModel ticketData,
    List<DspCsDresConsItem>? dresData,
    bool saveToSpecificPath = true,
    bool autoPrint = true,
  }) async {
    await LogService.instance.logRequest('PrintDspCsService.printTicket', {
      'action': 'creating_dsp_cs_ticket_pdf',
      'turno': ticketData.turno,
      'placa': ticketData.placa,
      'dres_items': dresData?.length ?? 0,
      'save_to_specific_path': saveToSpecificPath,
      'auto_print': autoPrint,
    });

    try {
      final pdf = pw.Document();
      final logoBytes = await PrintUtils.loadLogoBytes();
      // Reemplaza la creación del QR payload con:
      // 🔹 QR COMPLETO con TODOS los datos visibles en el ticket DSP-CS
      final qrPayloadMap = _buildQrPayloadCompleto(ticketData, dresData);
      final qrPayload = jsonEncode(qrPayloadMap);

      final qrCodeBytes = await PrintUtils.generateQrCode(qrPayload);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                PrintUtils.buildHeader(logoBytes),
                pw.SizedBox(height: 10),
                PrintUtils.buildSeparatorLine(),
                pw.Center(
                  child: pw.Text(
                    'DESPACHO CARGA SUELTA',
                    style: pw.TextStyle(
                      fontSize: 11,
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
                _buildBasicInfo(ticketData),
                pw.SizedBox(height: 10),
                _buildDresTable(dresData),
                pw.SizedBox(height: 10),
                PrintUtils.buildSeparatorLine(),
              ],
            );
          },
        ),
      );

      if (saveToSpecificPath) {
        final bytes = await pdf.save();
        final fileName = _buildFileName(ticketData);
        final file = await _savePdfBytes(bytes, fileName);

        await LogService.instance.logRequest('PrintDspCsService.printTicket', {
          'action': 'dsp_cs_ticket_saved_successfully',
          'path': file.path,
          'file_name': fileName,
        });

        // Impresión automática
        if (autoPrint && Platform.isWindows) {
          final printResult = await PrintAutoService.printPdfSilently(file);
          await LogService.instance
              .logRequest('PrintDspCsService.printTicket', {
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
      await LogService.instance.logError(
        'PrintDspCsService.printTicket',
        e,
        st,
      );
      return false;
    }
  }

  static Map<String, dynamic> _buildQrPayloadCompleto(
    TicketDspCsModel t,
    List<DspCsDresConsItem>? dres,
  ) {
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

    // Header
    _put(payload, 'TITULO', 'DESPACHO CARGA SUELTA');
    _put(payload, 'ENTRADA', t.entrada.isNotEmpty ? t.entrada : nowFmt);

    // Identificación
    _put(payload, 'TRANSACCION', t.atkId);
    _put(payload, 'TURNO', t.turno);
    _put(payload, 'PLACA', t.placa);

    // Operación
    _put(payload, 'PROGRAMADO', t.programado);

    // Conductor
    _put(payload, 'APELLIDOS', t.apellidos);
    _put(payload, 'NOMBRES', t.nombres);

    // DRES (SOLO RESUMEN PARA NO REVENTAR EL QR)
    final items = dres ?? const [];
    _put(payload, 'DRES ITEMS', items.length);

    if (items.isNotEmpty) {
      int totalBultos = 0;
      num totalPeso = 0;
      for (final x in items) {
        totalBultos += (x.canBulto);
        totalPeso += (x.pesBulto);
      }
      _put(payload, 'TOTAL BULTOS', totalBultos);
      _put(payload, 'TOTAL PESO', totalPeso);
      _put(payload, 'UNIDAD', 'KG');

      // (Opcional) 1 string compacto con 1-3 filas (sin listas)
      final top = items
          .take(3)
          .map((x) {
            final d = (x.dresCompleto).trim();
            final tarja = (x.tarja).trim();
            final b = (x.canBulto);
            final p = (x.pesBulto);
            return '$d/$tarja:$b-$p';
          })
          .join('|');
      _put(payload, 'DRES TOP', top);
    }

    return payload;
  }

  /// Construye la información básica del ticket
  static pw.Widget _buildBasicInfo(TicketDspCsModel ticketData) {
    return pw.Column(
      children: [
        PrintUtils.buildTwoColumnRow('TURNO', 'PLACA'),
        PrintUtils.buildTwoColumnRow(
          ticketData.turno,
          ticketData.placa,
          isBold: true,
        ),
        pw.SizedBox(height: 7),
        PrintUtils.buildTwoColumnRow('PROGRAMADO', 'ENTRADA'),
        PrintUtils.buildTwoColumnRow(
          ticketData.programado,
          ticketData.entrada,
          isBold: true,
        ),
        pw.SizedBox(height: 7),
        PrintUtils.buildSingleColumnRow('CHOFER'),
        PrintUtils.buildSingleColumnRow(ticketData.apellidos, isBold: true),
        PrintUtils.buildSingleColumnRow(ticketData.nombres, isBold: true),
        pw.SizedBox(height: 7),
      ],
    );
  }

  /// Construye la tabla de DRES
  static pw.Widget _buildDresTable(List<DspCsDresConsItem>? dresData) {
    return pw.Column(
      children: [
        // Encabezados
        pw.Row(
          children: [
            pw.Container(
              width: 60,
              child: pw.Text('DRES', style: pw.TextStyle(fontSize: 10)),
            ),
            pw.Container(
              width: 65,
              child: pw.Text('TARJA', style: pw.TextStyle(fontSize: 10)),
            ),
            pw.Container(
              width: 65,
              child: pw.Text(
                'BULTOS',
                style: pw.TextStyle(fontSize: 10),
                textAlign: pw.TextAlign.right,
              ),
            ),
            pw.Container(
              width: 70,
              child: pw.Text(
                'PESO',
                style: pw.TextStyle(fontSize: 10),
                textAlign: pw.TextAlign.right,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 5),

        // Datos DRES
        if (dresData != null && dresData.isNotEmpty)
          ...dresData.map(
            (dres) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                children: [
                  pw.Container(
                    width: 60,
                    child: pw.Text(
                      dres.dresCompleto,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Container(
                    width: 65,
                    child: pw.Text(
                      dres.tarja,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  pw.Container(
                    width: 65,
                    child: pw.Text(
                      '${dres.canBulto}',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                  pw.Container(
                    width: 70,
                    child: pw.Text(
                      '${dres.pesBulto}KG',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          pw.Container(
            width: double.infinity,
            child: pw.Text(
              'Sin datos DRES disponibles',
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
              textAlign: pw.TextAlign.center,
            ),
          ),
      ],
    );
  }

  /// Construye el nombre del archivo
  static String _buildFileName(TicketDspCsModel ticketData) {
    final fecha = DateFormat('dd_MM_yyyy').format(DateTime.now());
    return '${fecha}_DSP-CS_${ticketData.atkId}.pdf';
  }

  /// Guarda los bytes del PDF en el directorio específico
  static Future<File> _savePdfBytes(Uint8List bytes, String fileName) async {
    final base = await PrintUtils.getApplicationDocumentsDir();
    final dir = Directory(p.join(base.path, 'Tickets DSP CS'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
