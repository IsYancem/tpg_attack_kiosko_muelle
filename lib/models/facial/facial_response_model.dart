// Autor: Abraham Yance
// Fecha: 2025-11-09
// Modelo de respuesta estándar del servicio facial.

class StepEnvelope {
  final int errorCode;
  final String message;
  final int? spErrorCode;
  final String? spMessage;
  final Map<String, dynamic>? data;

  StepEnvelope({
    required this.errorCode,
    required this.message,
    this.spErrorCode,
    this.spMessage,
    this.data,
  });

  factory StepEnvelope.fromJson(Map<String, dynamic> json) {
    return StepEnvelope(
      errorCode: json['errorCode'] ?? 1,
      message: json['message'] ?? '',
      spErrorCode: json['spErrorCode'],
      spMessage: json['spMessage'],
      data: json['data'] != null
          ? Map<String, dynamic>.from(json['data'])
          : null,
    );
  }

  bool get isOk => errorCode == 0;
}

class FacialResponseModel {
  final int errorCode;
  final String message;
  final Map<String, StepEnvelope> services;

  FacialResponseModel({
    required this.errorCode,
    required this.message,
    required this.services,
  });

  factory FacialResponseModel.fromJson(Map<String, dynamic> json) {
    final Map<String, StepEnvelope> map = {};
    if (json['data']?['services'] != null) {
      (json['data']['services'] as Map<String, dynamic>).forEach((k, v) {
        map[k] = StepEnvelope.fromJson(Map<String, dynamic>.from(v));
      });
    }
    return FacialResponseModel(
      errorCode: json['errorCode'] ?? 1,
      message: json['message'] ?? '',
      services: map,
    );
  }

  StepEnvelope? operator [](String key) => services[key];
}
