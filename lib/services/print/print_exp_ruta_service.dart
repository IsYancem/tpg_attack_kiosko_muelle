// lib/services/print/print_exp_ruta_service.dart
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

class PrintExpRutaService {
  /// Imprime un ticket EXP combinado con datos de RUTA
  static Future<bool> printTicketCombinado({
    required TicketExpModel ticketData,
    required String ubicacion,
    String? bloque,
    String? bahia,
    String? danios,
    String? mapaUrl,
    Uint8List? mapaImageBytes,
    bool saveToSpecificPath = true,
    bool autoPrint = true,
  }) async {
    await LogService.instance
        .logRequest('PrintExpRutaService.printTicketCombinado', {
          'action': 'creating_combined_ticket_pdf',
          'atkId': ticketData.atkId,
          'placa': ticketData.placa,
          'contenedor': ticketData.contenedor,
          'ubicacion': ubicacion,
          'save_to_specific_path': saveToSpecificPath,
          'auto_print': autoPrint,
        });

    try {
      final pdf = pw.Document();
      final logoBytes = await PrintUtils.loadLogoBytes();

      // 🔹 QR Payload con TODOS los datos del ticket
      final qrPayloadMap = _buildQrPayloadCompleto(
        ticketData,
        ubicacion,
        bloque,
        bahia,
        danios,
        mapaUrl,
      );
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
                      'EXPORTACIÓN FULL',
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
                  _buildTicketContentCombinado(
                    ticketData,
                    ubicacion,
                    bloque,
                    bahia,
                    danios,
                  ),
                  pw.SizedBox(height: 6),
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
        final fileName = _buildFileNameCombinado(ticketData);
        final file = await _savePdfBytes(pdfBytes, fileName);

        await LogService.instance
            .logRequest('PrintExpRutaService.printTicketCombinado', {
              'action': 'combined_ticket_saved_successfully',
              'path': file.path,
              'file_name': fileName,
            });

        if (autoPrint && Platform.isWindows) {
          final printResult = await PrintAutoService.printPdfSilently(file);
          await LogService.instance
              .logRequest('PrintExpRutaService.printTicketCombinado', {
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
      LogService.instance.logError(
        'PrintExpRutaService.printTicketCombinado',
        e,
        st,
      );
      return false;
    }
  }

  /// 🔹 QR COMPLETO con TODOS los datos visibles en el ticket
  static Map<String, dynamic> _buildQrPayloadCompleto(
    TicketExpModel t,
    String ubicacion,
    String? bloque,
    String? bahia,
    String? danios,
    String? mapaUrl,
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

    // Sellos (solo si vienen)
    _put(payload, 'SELLO 1', t.sello1);
    _put(payload, 'SELLO 2', t.sello2);
    _put(payload, 'SELLO 3', t.sello3);
    _put(payload, 'SELLO 4', t.sello4);

    _put(payload, 'CARGA IMO', t.cargaIMO);
    _put(payload, 'REFRIGERADO', t.refrigerado);

    _put(payload, 'UBICACION', ubicacion);
    _put(payload, 'BLOQUE', bloque);
    _put(payload, 'BAHIA', bahia);
    _put(payload, 'DANIOS', danios);

    _put(payload, 'MAPA', mapaUrl);

    _put(payload, 'CONDUCTOR', t.choferNombre);
    _put(payload, 'CEDULA', t.choferCedula);

    return payload;
  }

  // El resto del código se mantiene igual...
  /// Construye el contenido del ticket combinado (versión compacta)
  static pw.Widget _buildTicketContentCombinado(
    TicketExpModel ticketData,
    String ubicacion,
    String? bloque,
    String? bahia,
    String? danios,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Sección EXP
          pw.Center(
            child: pw.Text(
              'DATOS DE EXPORTACIÓN',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 3),

          // Transacción y Placa - Versión compacta
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('TRANSACCIÓN', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    ticketData.atkId.toString(),
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

          // Contenedor
          pw.Text('CONTENEDOR', style: pw.TextStyle(fontSize: 8)),
          pw.Text(
            ticketData.contenedor,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),

          // Booking y tipo de carga
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('BOOKING', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    ticketData.booking,
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
                  pw.Text('TIPO CARGA', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    ticketData.tipoCarga,
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

          // Pesos
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('PESO INGRESO', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    '${ticketData.pesoIngreso} Kg',
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
                  pw.Text('TARA', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    '${ticketData.tara} Kg',
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

          // Sección RUTA
          pw.SizedBox(height: 6),
          PrintUtils.buildSeparatorLine(),
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(
              'UBICACIÓN ASIGNADA',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 3),

          // Ubicación
          pw.Text('UBICACIÓN', style: pw.TextStyle(fontSize: 8)),
          pw.Text(
            ubicacion,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),

          // Bloque (si existe)
          if (bloque != null && bloque.isNotEmpty) ...[
            pw.Text('BLOQUE', style: pw.TextStyle(fontSize: 8)),
            pw.Text(
              bloque,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 3),
          ],

          // Bahía (si existe)
          if (bahia != null && bahia.isNotEmpty) ...[
            pw.Text('BAHÍA', style: pw.TextStyle(fontSize: 8)),
            pw.Text(
              bahia,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 3),
          ],

          // Daños observados (si existen)
          if (danios != null && danios.isNotEmpty) ...[
            pw.Text('DAÑOS OBSERVADOS', style: pw.TextStyle(fontSize: 8)),
            pw.Text(
              danios,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              maxLines: 2,
              overflow: pw.TextOverflow.clip,
            ),
            pw.SizedBox(height: 3),
          ],

          // Características
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CARGA IMO', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    ticketData.cargaIMO,
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
                  pw.Text('REFRIGERADO', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(
                    ticketData.refrigerado,
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

          // Entrada
          pw.Text('ENTRADA', style: pw.TextStyle(fontSize: 8)),
          pw.Text(
            ticketData.entrada,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),

          // Chofer
          pw.Text('CONDUCTOR', style: pw.TextStyle(fontSize: 8)),
          pw.Text(
            ticketData.choferNombre,
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'CI: ${ticketData.choferCedula}',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Construye el nombre del archivo
  static String _buildFileNameCombinado(TicketExpModel ticketData) {
    final fecha = DateFormat('dd_MM_yyyy').format(DateTime.now());
    final cedula =
        (ticketData.choferCedula.isEmpty
                ? 'SIN_CEDULA'
                : ticketData.choferCedula)
            .replaceAll(RegExp(r'[^\w\-]'), '_');
    return '${fecha}_EXP_UBICACION_${cedula}.pdf';
  }

  /// Guarda los bytes del PDF en el directorio específico
  static Future<File> _savePdfBytes(Uint8List bytes, String fileName) async {
    final base = await PrintUtils.getApplicationDocumentsDir();
    final dir = Directory(p.join(base.path, 'Tickets EXP Ubicación'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
