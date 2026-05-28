// lib/services/print/print_utils.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path/path.dart' as p;

// 👇 Nuevo import: pretty_qr_code (reemplaza a qr_flutter)
import 'package:pretty_qr_code/pretty_qr_code.dart';

/// Utilidades compartidas para la generación de tickets
class PrintUtils {
  /// Genera un código QR a partir de datos usando pretty_qr_code
  /// - Usa QrCode.fromData (package:qr re-exportado por pretty_qr_code)
  /// - Exporta como PNG en bytes
  /// - Incrusta el logo assets/images/tpg_logo.png en el centro del QR
  static Future<Uint8List> generateQrCode(String data) async {
    // 1) Construir QR de datos
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.L,
    );

    // 2) Crear imagen QR base
    final qrImage = QrImage(qrCode);

    // 3) Exportar como bytes PNG con decoración:
    //    - logo incrustado en el centro (PrettyQrDecorationImage.embedded)
    final byteData = await qrImage.toImageAsBytes(
      size: 800, // tamaño en px del PNG
      format: ui.ImageByteFormat.png,
      // decoration: const PrettyQrDecoration(
      //   image: PrettyQrDecorationImage(
      //     image: AssetImage('assets/images/tpg_logo.png'),
      //     position: PrettyQrDecorationImagePosition.embedded,
      //   ),
      // ),
      decoration: const PrettyQrDecoration(
        background: ui.Color(0xFFFFFFFF),
        // quiet zone / margen blanco alrededor del QR
        // (si tu versión usa "quietZone", usa esta)
        // quietZone: PrettyQrModulesQuietZone(10),
      ),
    );

    if (byteData == null) {
      throw Exception('Failed to generate QR code bytes');
    }

    // 👈 Convertir ByteData -> Uint8List (lo que espera el caller)
    return byteData.buffer.asUint8List();
  }

  /// Construye el encabezado del ticket
  static pw.Widget buildHeader(Uint8List logoBytes) {
    final now = DateTime.now();
    final fechaFormato = DateFormat('yyyy/MM/dd HH:mm').format(now);

    return pw.Row(
      children: [
        pw.Container(
          width: 50,
          height: 50,
          child: pw.Image(pw.MemoryImage(logoBytes)),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'TERMINAL PORTUARIO',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'DE GUAYAQUIL',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                fechaFormato,
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Construye una línea separadora
  static pw.Widget buildSeparatorLine() {
    return pw.Container(
      width: double.infinity,
      height: 1,
      color: PdfColors.black,
      margin: const pw.EdgeInsets.symmetric(vertical: 5),
    );
  }

  /// Construye una fila con dos columnas
  static pw.Widget buildTwoColumnRow(
    String left,
    String right, {
    bool isBold = false,
  }) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            left,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            right,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  /// Construye una fila de una sola columna
  static pw.Widget buildSingleColumnRow(String text, {bool isBold = false}) {
    return pw.Container(
      width: double.infinity,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  /// Carga los bytes del logo desde assets
  static Future<Uint8List> loadLogoBytes() async {
    final ByteData logoData = await rootBundle.load(
      'assets/images/tpg_logo.png',
    );
    return logoData.buffer.asUint8List();
  }

  /// Formatea la fecha actual
  static String formatCurrentDate() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/'
        '${now.month.toString().padLeft(2, '0')}/'
        '${now.year} '
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';
  }

  /// Obtiene el directorio de documentos de la aplicación
  static Future<Directory> getApplicationDocumentsDir() async {
    return await getApplicationDocumentsDirectory();
  }

  /// Guarda bytes en un archivo
  static Future<File> saveBytesToFile(
    Uint8List bytes,
    String directoryPath,
    String fileName,
  ) async {
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Sanitiza un nombre de archivo
  static String sanitizeFileName(String input) {
    return input.replaceAll(RegExp(r'[^\w\-\.]'), '_');
  }
}
