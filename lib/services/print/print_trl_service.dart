// lib/services/print/print_trl_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:tpg_attack_kiosko_muelle/models/print/ticket_trl_model.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_utils.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_auto_service.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'dart:io';

/// Servicio de impresión para tickets TRL (Traslado)
class PrintTrlService {
  // Agrega este método nuevo:
  /// 🔹 QR COMPLETO con TODOS los datos visibles en el ticket TRL
  static Map<String, dynamic> _buildQrPayload(TicketTrlModel t) {
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

    _put(payload, 'TITULO', 'TRASLADO DE CONTENEDOR(ES)');
    _put(
      payload,
      'ENTRADA',
      (t.entrada.trim().isNotEmpty) ? t.entrada.trim() : nowFmt,
    );

    _put(payload, 'TRANSACCION', t.atkId);
    _put(payload, 'NUM TRAN BASCULA', t.numTranBascula);
    _put(payload, 'PLACA', t.placa);
    _put(payload, 'GATE', t.gate);

    _put(payload, 'ORIGEN', t.origen);
    _put(payload, 'DESTINO', t.destino);
    _put(payload, 'PESO', t.peso);
    _put(payload, 'UNIDAD', 'KG');

    // Contenedor 1
    _put(payload, 'CONTENEDOR 1', t.contenedor1);
    if (t.anioOperacion1 != null && t.corOperacion1 != null) {
      _put(payload, 'OPERACION 1', '${t.anioOperacion1}-${t.corOperacion1}');
    }
    _put(payload, 'DETALLE 1', t.detalle1);

    // Contenedor 2 (solo si existe)
    if (t.hasCont2 && t.contenedor2 != null) {
      _put(payload, 'CONTENEDOR 2', t.contenedor2);
      if (t.anioOperacion2 != null && t.corOperacion2 != null) {
        _put(payload, 'OPERACION 2', '${t.anioOperacion2}-${t.corOperacion2}');
      }
      _put(payload, 'DETALLE 2', t.detalle2);
    }

    _put(payload, 'APELLIDOS', t.apellidos);
    _put(payload, 'NOMBRES', t.nombres);

    return payload;
  }

  /// Imprime un ticket TRL
  static Future<bool> printTicket({
    required TicketTrlModel ticketData,
    bool saveToSpecificPath = true,
    bool autoPrint = true,
  }) async {
    LogService.instance.logRequest('PrintTrlService.printTicket', {
      'action': 'creating_trl_ticket_pdf',
      'atk_id': ticketData.atkId,
      'placa': ticketData.placa,
      'cont2': ticketData.hasCont2,
      'num_tran_bascula': ticketData.numTranBascula,
      'save_to_specific_path': saveToSpecificPath,
      'auto_print': autoPrint,
    });

    try {
      final pdf = pw.Document();
      final logoBytes = await PrintUtils.loadLogoBytes();

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
                    'TRASLADO DE CONTENEDOR(ES)',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                PrintUtils.buildSeparatorLine(),
                pw.SizedBox(height: 10),

                // QR Code
                pw.Center(
                  child: pw.Container(
                    width: 150,
                    height: 150,
                    child: pw.Image(pw.MemoryImage(qrCodeBytes)),
                  ),
                ),

                pw.SizedBox(height: 15),

                // Contenido básico
                _buildBasicInfo(ticketData),
                pw.SizedBox(height: 10),

                // Chofer
                PrintUtils.buildSingleColumnRow('CHOFER'),
                PrintUtils.buildSingleColumnRow(
                  ticketData.apellidos,
                  isBold: true,
                ),
                PrintUtils.buildSingleColumnRow(
                  ticketData.nombres,
                  isBold: true,
                ),

                pw.SizedBox(height: 10),
                PrintUtils.buildSeparatorLine(),

                // Tabla contenedores
                _buildContainersTable(ticketData),

                pw.SizedBox(height: 10),
                PrintUtils.buildSeparatorLine(),
              ],
            );
          },
        ),
      );

      if (saveToSpecificPath) {
        final pdfBytes = await pdf.save();
        final fileName = _buildFileName(ticketData);
        final file = await _savePdfBytes(pdfBytes, fileName);

        LogService.instance.logRequest('PrintTrlService.printTicket', {
          'action': 'trl_ticket_saved_successfully',
          'path': file.path,
          'file_name': fileName,
        });

        // Impresión automática
        if (autoPrint && Platform.isWindows) {
          final printResult = await PrintAutoService.printPdfSilently(file);
          LogService.instance.logRequest('PrintTrlService.printTicket', {
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
      LogService.instance.logError('PrintTrlService.printTicket', e, st);
      return false;
    }
  }

  /// Construye la información básica del ticket TRL
  static pw.Widget _buildBasicInfo(TicketTrlModel ticketData) {
    return pw.Column(
      children: [
        PrintUtils.buildTwoColumnRow('PLACA', 'TRANSACCIÓN'),
        PrintUtils.buildTwoColumnRow(
          ticketData.placa,
          (ticketData.numTranBascula ?? 0).toString(),
          isBold: true,
        ),
        pw.SizedBox(height: 7),

        PrintUtils.buildTwoColumnRow('ENTRADA', 'PUERTA'),
        PrintUtils.buildTwoColumnRow(
          ticketData.entrada,
          (ticketData.gate ?? ''),
          isBold: true,
        ),
        pw.SizedBox(height: 7),

        PrintUtils.buildTwoColumnRow('ORIGEN', 'DESTINO'),
        PrintUtils.buildTwoColumnRow(
          ticketData.origen,
          ticketData.destino,
          isBold: true,
        ),
        pw.SizedBox(height: 7),

        PrintUtils.buildTwoColumnRow('PESO', 'ATK ID'),
        PrintUtils.buildTwoColumnRow(
          ticketData.peso,
          (ticketData.atkId ?? '').toString(),
          isBold: true,
        ),
      ],
    );
  }

  /// Construye la tabla de contenedores
  static pw.Widget _buildContainersTable(TicketTrlModel ticketData) {
    pw.Widget buildContainerRow(
      String contenedor,
      int? anio,
      int? cor,
      String? detalle,
    ) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 85,
              child: pw.Text(
                contenedor,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Container(
              width: 65,
              child: pw.Text(
                (anio != null && cor != null) ? '$anio-$cor' : '',
                style: pw.TextStyle(fontSize: 10),
              ),
            ),
            pw.Expanded(
              child: pw.Text(detalle ?? '', style: pw.TextStyle(fontSize: 10)),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Headers
        pw.Row(
          children: [
            pw.Container(
              width: 85,
              child: pw.Text('CONTENEDOR', style: pw.TextStyle(fontSize: 10)),
            ),
            pw.Container(
              width: 65,
              child: pw.Text('OPERACIÓN', style: pw.TextStyle(fontSize: 10)),
            ),
            pw.Expanded(
              child: pw.Text('DETALLE', style: pw.TextStyle(fontSize: 10)),
            ),
          ],
        ),
        pw.SizedBox(height: 5),

        // Contenedor 1
        buildContainerRow(
          ticketData.contenedor1,
          ticketData.anioOperacion1,
          ticketData.corOperacion1,
          ticketData.detalle1,
        ),

        // Contenedor 2 (opcional)
        if (ticketData.hasCont2)
          buildContainerRow(
            ticketData.contenedor2!,
            ticketData.anioOperacion2,
            ticketData.corOperacion2,
            ticketData.detalle2,
          ),
      ],
    );
  }

  /// Construye el nombre del archivo
  static String _buildFileName(TicketTrlModel ticketData) {
    final fecha = DateFormat('dd_MM_yyyy').format(DateTime.now());
    final placaSan = ticketData.placa.replaceAll(RegExp(r'[^\w\-]'), '_');
    final id = (ticketData.atkId?.toString() ?? 'SIN_ID');
    return '${fecha}_TRL_${placaSan}_$id.pdf';
  }

  /// Guarda los bytes del PDF en el directorio específico
  static Future<File> _savePdfBytes(Uint8List bytes, String fileName) async {
    final base = await PrintUtils.getApplicationDocumentsDir();
    final dir = Directory(p.join(base.path, 'Tickets TRL'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
