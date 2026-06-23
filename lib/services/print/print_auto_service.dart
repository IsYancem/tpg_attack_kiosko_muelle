// lib/services/print/print_auto_service.dart
import 'dart:io';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/print_result.dart';

/// Servicio de impresión automática usando SumatraPDF
class PrintAutoService {
  /// ⚠️ IMPORTANTE: Ajusta esta ruta según la instalación de SumatraPDF
  static const String _sumatraPath =
      r'C:\Program Files\SumatraPDF\SumatraPDF.exe';

  /// Imprime un PDF de forma silenciosa usando SumatraPDF
  static Future<PrintResult> printPdfSilently(File pdfFile) async {
    if (!Platform.isWindows) {
      return PrintResult.error(
        'Impresión automática solo disponible en Windows',
      );
    }

    // 1. Verificar que SumatraPDF existe
    if (!await File(_sumatraPath).exists()) {
      LogService.instance.logWarning(
        'PrintAutoService.printPdfSilently',
        {'warning': 'sumatra_not_found', 'expected_path': _sumatraPath},
      );

      return PrintResult.error(
        'SumatraPDF no encontrado en: $_sumatraPath. '
        'Verifica que esté instalado correctamente.',
      );
    }

    // 2. Verificar que el archivo PDF existe
    if (!await pdfFile.exists()) {
      return PrintResult.error('Archivo PDF no encontrado: ${pdfFile.path}');
    }

    // 3. Ejecutar impresión silenciosa
    try {
      final result = await Process.run(_sumatraPath, [
        '-print-to-default', // Imprime a la impresora predeterminada
        '-silent', // Sin mostrar ventana
        pdfFile.path,
      ]);

      if (result.exitCode == 0) {
        await LogService.instance
            .logRequest('PrintAutoService.printPdfSilently', {
              'action': 'print_success',
              'file': pdfFile.path,
              'exit_code': result.exitCode,
            });

        return PrintResult.success(
          'Documento enviado a la impresora predeterminada',
        );
      } else {
        await LogService.instance
            .logWarning('PrintAutoService.printPdfSilently', {
              'warning': 'print_command_failed',
              'exit_code': result.exitCode,
              'stderr': result.stderr,
            });

        return PrintResult.error(
          'Error al imprimir (código ${result.exitCode}): ${result.stderr}',
        );
      }
    } catch (e, st) {
      LogService.instance.logError(
        'PrintAutoService.printPdfSilently',
        e,
        st,
      );

      return PrintResult.error('Excepción al ejecutar SumatraPDF: $e');
    }
  }

  /// Verifica si SumatraPDF está instalado
  static Future<bool> isSumatraInstalled() async {
    if (!Platform.isWindows) return false;
    return await File(_sumatraPath).exists();
  }

  /// Obtiene la ruta de instalación de SumatraPDF
  static String get sumatraPath => _sumatraPath;
}
