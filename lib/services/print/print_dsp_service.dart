// lib/services/print/print_dsp_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:tpg_attack_kiosko_muelle/models/print/ticket_dsp_model.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_utils.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_auto_service.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

/// Servicio de impresión para tickets DSP
class PrintDspService {
  /// Imprime un ticket DSP
  static Future<bool> printTicket({
    required TicketDspModel ticketData,
    Uint8List? mapaImageBytes,
    bool saveToSpecificPath = true,
    bool autoPrint = true,
  }) async {
    await LogService.instance.logRequest('PrintDspService.printTicket', {
      'action': 'creating_dsp_ticket_pdf',
      'turno': ticketData.turno,
      'placa': ticketData.placa,
      'save_to_specific_path': saveToSpecificPath,
      'auto_print': autoPrint,
      'has_mapa': mapaImageBytes != null,
    });

    try {
      final pdf = pw.Document();
      final logoBytes = await PrintUtils.loadLogoBytes();

      final qrPayloadMap = _buildQrPayload(ticketData);
      final qrPayload = jsonEncode(qrPayloadMap);
      final qrCodeBytes = await PrintUtils.generateQrCode(qrPayload);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80.copyWith(
            marginLeft: 0,
            marginRight: 0,
            marginTop: 0,
            marginBottom: 0,
          ),
          build: (_) {
            return pw.Container(
              width: 240,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  PrintUtils.buildHeader(logoBytes),
                  pw.SizedBox(height: 6),
                  PrintUtils.buildSeparatorLine(),
                  pw.Center(
                    child: pw.Text(
                      'DESPACHO CONTENEDOR FULL',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                  PrintUtils.buildSeparatorLine(),
                  pw.SizedBox(height: 6),
                  pw.Center(
                    child: pw.Container(
                      width: 150,
                      height: 150,
                      child: pw.Image(pw.MemoryImage(qrCodeBytes)),
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  _buildTicketContent(ticketData),
                  pw.SizedBox(height: 6),

                  // ✅ MAPA con mismo formato que EXP
                  if (mapaImageBytes != null) ...[
                    PrintUtils.buildSeparatorLine(),
                    pw.SizedBox(height: 6),
                    pw.Center(
                      child: pw.Text(
                        'MAPA DE UBICACIÓN',
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Center(
                      child: pw.Container(
                        width: 280,
                        height: 420,
                        child: pw.Image(pw.MemoryImage(mapaImageBytes)),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                  ],

                  // ✅ FOOTER con mensaje de conservación
                  PrintUtils.buildSeparatorLine(),
                  pw.SizedBox(height: 3),
                  pw.Center(
                    child: pw.Text(
                      'Conserve este comprobante',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.Center(
                    child: pw.Text(
                      'Verifique en la APP de TPG',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      if (saveToSpecificPath) {
        final pdfBytes = await pdf.save();
        final fileName = _buildFileName(ticketData);
        final file = await _savePdfBytes(pdfBytes, fileName);

        await LogService.instance.logRequest('PrintDspService.printTicket', {
          'action': 'dsp_ticket_saved_successfully',
          'path': file.path,
          'file_name': fileName,
        });

        if (autoPrint && Platform.isWindows) {
          final printResult = await PrintAutoService.printPdfSilently(file);
          await LogService.instance.logRequest('PrintDspService.printTicket', {
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
      await LogService.instance.logError('PrintDspService.printTicket', e, st);
      return false;
    }
  }

  /// ✅ QR COMPLETO (PLANO) con TODOS los datos visibles en el ticket DSP FULL
  static Map<String, dynamic> _buildQrPayload(TicketDspModel t) {
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
    _put(payload, 'TITULO', 'DESPACHO FULL');

    // Usa la entrada del ticket si viene; si no, ahora
    final entrada = (t.entrada.trim().isNotEmpty) ? t.entrada.trim() : nowFmt;
    _put(payload, 'ENTRADA', entrada);

    // Identificación
    _put(payload, 'TRANSACCION', t.atkId);
    _put(payload, 'TURNO', t.turno);
    _put(payload, 'PLACA', t.placa);
    _put(payload, 'CONTENEDOR', t.contenedor);
    _put(payload, 'DRES', t.dres);

    // Ubicación
    _put(payload, 'UBICACION', t.ubicacion);
    _put(payload, 'BLOQUE', t.bloque);

    // Programación
    _put(payload, 'PROGRAMADO', t.programado);

    // Conductor
    _put(payload, 'APELLIDOS', t.apellidos);
    _put(payload, 'NOMBRES', t.nombres);
    _put(payload, 'CONDUCTOR', '${t.nombres} ${t.apellidos}');
    _put(payload, 'CEDULA', t.choferIdentification);

    return payload;
  }

  /// Construye el contenido del ticket DSP (versión compacta)
  static pw.Widget _buildTicketContent(TicketDspModel ticketData) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Turno y Placa
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('TURNO', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    ticketData.turno,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('PLACA', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    ticketData.placa,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 3),

          // Contenedor y DRES
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CONTENEDOR', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    ticketData.contenedor ?? '',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('DRES', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    ticketData.dres,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 3),

          // Ubicación y Bloque
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('UBICACIÓN', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    ticketData.ubicacion ?? '',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('BLOQUE', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    ticketData.bloque,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 3),

          // Programado y Entrada
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('PROGRAMADO', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    ticketData.programado,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('ENTRADA', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    ticketData.entrada,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 3),

          // Chofer
          pw.Text('CHOFER', style: pw.TextStyle(fontSize: 8)),
          if (ticketData.apellidos.isNotEmpty)
            pw.Text(
              ticketData.apellidos,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
          pw.Text(
            ticketData.nombres,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          if (ticketData.choferIdentification.isNotEmpty)
            pw.Text(
              'CI: ${ticketData.choferIdentification}',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
        ],
      ),
    );
  }

  /// Construye el nombre del archivo
  static String _buildFileName(TicketDspModel ticketData) {
    final fecha = DateFormat('dd_MM_yyyy').format(DateTime.now());
    final ident =
        (ticketData.choferIdentification.isEmpty
                ? 'SIN_CEDULA'
                : ticketData.choferIdentification)
            .replaceAll(RegExp(r'[^\w\-]'), '_');
    return '${fecha}_DSP_${ident}.pdf';
  }

  /// Guarda los bytes del PDF en el directorio específico
  static Future<File> _savePdfBytes(Uint8List bytes, String fileName) async {
    final base = await PrintUtils.getApplicationDocumentsDir();
    final dir = Directory(p.join(base.path, 'Tickets DSP'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
