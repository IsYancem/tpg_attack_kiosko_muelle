// lib/utils/helpers.dart
import 'dart:async';
import 'dart:convert';

class Helpers {
  static Map<String, dynamic> createWsResponse({
    bool error = true,
    String desError = "No se pudo procesar la solicitud",
    String data = "",
  }) {
    return {'error': error, 'desError': desError, 'data': data};
  }

  static String decrypt(String text) {
    try {
      if (text.isEmpty) return '';

      final decrypted = text
          .replaceAll('@', '9')
          .replaceAll('|', '6')
          .replaceAll('#', '2')
          .replaceAll('(', '4')
          .replaceAll(')', '8')
          .replaceAll('%', '1')
          .replaceAll('&', '3')
          .replaceAll('>', '5');

      final bytes = base64Decode(decrypted);
      final result = utf8.decode(bytes);

      return result;
    } catch (e) {
      return '';
    }
  }

  static String encrypt(String text) {
    try {
      if (text.isEmpty) return '';

      // Codificar a Base64
      final bytes = utf8.encode(text);
      final base64Text = base64Encode(bytes);

      // Realizar reemplazos específicos (de la misma manera que en .NET)
      final encrypted = base64Text
          .replaceAll('9', '@')
          .replaceAll('6', '|')
          .replaceAll('2', '#')
          .replaceAll('4', '(')
          .replaceAll('8', ')')
          .replaceAll('1', '%')
          .replaceAll('3', '&')
          .replaceAll('5', '>');

      return encrypted;
    } catch (e) {
      return '';
    }
  }

  /// Validar y convertir string a int
  static int validaInt(String data) {
    try {
      if (data.isEmpty) return 0;

      String cleanData = data.replaceAll(RegExp(r'[^\d-]'), '');
      int result = int.tryParse(cleanData) ?? 0;
      return result;
    } catch (e) {
      return 0;
    }
  }
}

class ContenedorInfo {
  final int codError;
  final String desError;
  final int anoOperacion;
  final int corOperacion;
  final String codSigla;
  final int codNumero;
  final String codDigito;
  final String ruta;
  final String ubicacion;

  ContenedorInfo({
    required this.codError,
    required this.desError,
    required this.anoOperacion,
    required this.corOperacion,
    required this.codSigla,
    required this.codNumero,
    required this.codDigito,
    required this.ruta,
    required this.ubicacion,
  });

  /// Crear desde JSON
  factory ContenedorInfo.fromJson(Map<String, dynamic> json) {
    return ContenedorInfo(
      codError: Helpers.validaInt(json['codError']?.toString() ?? '0'),
      desError: json['desError']?.toString() ?? '',
      anoOperacion: Helpers.validaInt(json['ano_operacion']?.toString() ?? '0'),
      corOperacion: Helpers.validaInt(json['cor_operacion']?.toString() ?? '0'),
      codSigla: json['cod_sigla']?.toString() ?? '',
      codNumero: Helpers.validaInt(json['cod_numero']?.toString() ?? '0'),
      codDigito: json['cod_digito']?.toString() ?? '',
      ruta: json['ruta']?.toString() ?? '',
      ubicacion: json['ubicacion']?.toString() ?? '',
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'codError': codError,
      'desError': desError,
      'ano_operacion': anoOperacion,
      'cor_operacion': corOperacion,
      'cod_sigla': codSigla,
      'cod_numero': codNumero,
      'cod_digito': codDigito,
      'ruta': ruta,
      'ubicacion': ubicacion,
    };
  }

  /// Verificar si hay error
  bool get hasError => codError != 0;

  @override
  String toString() {
    return 'ContenedorInfo(codError: $codError, desError: $desError, '
        'operacion: $anoOperacion-$corOperacion, '
        'contenedor: $codSigla$codNumero$codDigito)';
  }
}

Timer schedulePeriodicHealthCheck({
  required Future<bool> Function() check,
  required void Function(bool isUp) onStatus,
  required void Function(String msg) onLog,
  Duration interval = const Duration(seconds: 10),
  String source = 'HEALTH',
}) {
  () async {
    final ok = await check();
    onStatus(ok);
    onLog('✅ $source está ${ok ? "UP" : "DOWN"}');
  }();

  return Timer.periodic(interval, (_) async {
    try {
      final ok = await check();
      onStatus(ok);
      onLog('✅ $source está ${ok ? "UP" : "DOWN"}');
    } catch (e) {
      onStatus(false);
      onLog('✅ $source error: $e');
    }
  });
}
