// lib/models/confirm/confirm_response_model.dart
// Autor: Abraham Yance
// Fecha: 2025-11-10 (ACTUALIZADO para soportar EXP)
// Modelo de respuesta estándar del servicio Confirm (DSP / TRL / EXP)

class StepEnvelope {
  final int errorCode;
  final String message;
  final int? spErrorCode;
  final String? spMessage;
  final dynamic data; // ✅ Cambiado a dynamic para soportar Map O List

  StepEnvelope({
    required this.errorCode,
    required this.message,
    this.spErrorCode,
    this.spMessage,
    this.data,
  });

  factory StepEnvelope.fromJson(Map<String, dynamic> json) {
    dynamic parsedData;

    if (json['data'] != null) {
      final rawData = json['data'];

      // ✅ Manejar tanto Map como List
      if (rawData is Map) {
        parsedData = Map<String, dynamic>.from(rawData);
      } else if (rawData is List) {
        parsedData = List<dynamic>.from(rawData);
      } else {
        parsedData = rawData; // otros tipos (string, int, etc.)
      }
    }

    return StepEnvelope(
      errorCode: json['errorCode'] ?? 1,
      message: json['message'] ?? '',
      spErrorCode: json['spErrorCode'],
      spMessage: json['spMessage'],
      data: parsedData,
    );
  }

  bool get isOk => errorCode == 0;

  // ✅ Helpers para acceder a data de forma segura
  Map<String, dynamic>? get dataAsMap =>
      data is Map ? data as Map<String, dynamic> : null;
  List<dynamic>? get dataAsList => data is List ? data as List<dynamic> : null;
}

class ConfirmResponseModel {
  final int errorCode;
  final String message;
  final int? numero;
  final Map<String, StepEnvelope> services;

  ConfirmResponseModel({
    required this.errorCode,
    required this.message,
    required this.services,
    this.numero,
  });

  factory ConfirmResponseModel.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    final numero = data['numero'];
    final Map<String, StepEnvelope> map = {};

    if (data['services'] != null) {
      (data['services'] as Map<String, dynamic>).forEach((k, v) {
        map[k] = StepEnvelope.fromJson(Map<String, dynamic>.from(v));
      });
    }

    return ConfirmResponseModel(
      errorCode: json['errorCode'] ?? 1,
      message: json['message'] ?? '',
      numero: numero is num ? numero.toInt() : null,
      services: map,
    );
  }

  StepEnvelope? operator [](String key) => services[key];
}
