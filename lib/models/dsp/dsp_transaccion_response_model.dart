// lib/models/dsp/dsp_transaccion_response_model.dart
// Autor: Abraham Yance
// Fecha: 2025-11-12
// Descripción: Modelo de response para transacción DSP

class DspTransaccionResponseModel {
  final int errorCode;
  final String message;
  final DspTransaccionDataModel? data;

  DspTransaccionResponseModel({
    required this.errorCode,
    required this.message,
    this.data,
  });

  factory DspTransaccionResponseModel.fromJson(Map<String, dynamic> json) {
    return DspTransaccionResponseModel(
      errorCode: json['errorCode'] as int,
      message: json['message'] as String,
      data: json['data'] != null
          ? DspTransaccionDataModel.fromJson(
              json['data'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'errorCode': errorCode, 'message': message, 'data': data?.toJson()};
  }

  /// Operador [] para acceder a services directamente
  DspStepEnvelope? operator [](String key) => data?.services[key];
}

class DspTransaccionDataModel {
  final int? numero;
  final Map<String, DspStepEnvelope> services;
  final DspTransaccionMetadataModel? metadata;

  DspTransaccionDataModel({this.numero, required this.services, this.metadata});

  factory DspTransaccionDataModel.fromJson(Map<String, dynamic> json) {
    final servicesMap = <String, DspStepEnvelope>{};

    if (json['services'] != null) {
      final servicesJson = json['services'] as Map<String, dynamic>;
      servicesJson.forEach((key, value) {
        servicesMap[key] = DspStepEnvelope.fromJson(
          value as Map<String, dynamic>,
        );
      });
    }

    return DspTransaccionDataModel(
      numero: json['numero'] as int?,
      services: servicesMap,
      metadata: json['metadata'] != null
          ? DspTransaccionMetadataModel.fromJson(
              json['metadata'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final servicesJson = <String, dynamic>{};
    services.forEach((key, value) {
      servicesJson[key] = value.toJson();
    });

    return {
      'numero': numero,
      'services': servicesJson,
      if (metadata != null) 'metadata': metadata!.toJson(),
    };
  }
}

class DspTransaccionMetadataModel {
  final int elapsedMs;
  final List<String> failures;
  final int totalSteps;
  final int successfulSteps;

  DspTransaccionMetadataModel({
    required this.elapsedMs,
    required this.failures,
    required this.totalSteps,
    required this.successfulSteps,
  });

  factory DspTransaccionMetadataModel.fromJson(Map<String, dynamic> json) {
    final rawFailures = json['failures'];
    final failuresList = rawFailures is List
        ? rawFailures.map((e) => e.toString()).toList()
        : <String>[];

    return DspTransaccionMetadataModel(
      elapsedMs: (json['elapsedMs'] as num?)?.toInt() ?? 0,
      totalSteps: (json['totalSteps'] as num?)?.toInt() ?? 0,
      successfulSteps: (json['successfulSteps'] as num?)?.toInt() ?? 0,
      failures: failuresList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'elapsedMs': elapsedMs,
      'failures': failures,
      'totalSteps': totalSteps,
      'successfulSteps': successfulSteps,
    };
  }

  bool get hasFailures => failures.isNotEmpty;
}

class DspStepEnvelope {
  final int errorCode;
  final String message;
  final Map<String, dynamic>? data;
  final int? spErrorCode;
  final String? spMessage;
  final String? source;

  DspStepEnvelope({
    required this.errorCode,
    required this.message,
    this.data,
    this.spErrorCode,
    this.spMessage,
    this.source,
  });

  factory DspStepEnvelope.fromJson(Map<String, dynamic> json) {
    return DspStepEnvelope(
      errorCode: json['errorCode'] as int,
      message: json['message'] as String,
      data: json['data'] as Map<String, dynamic>?,
      spErrorCode: json['spErrorCode'] as int?,
      spMessage: json['spMessage'] as String?,
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'errorCode': errorCode,
      'message': message,
      'data': data,
      'spErrorCode': spErrorCode,
      'spMessage': spMessage,
      'source': source,
    };
  }

  /// Helper para verificar si el paso fue exitoso
  bool get isSuccess => errorCode == 0;

  /// Helper para obtener mensaje completo (spMessage si existe, sino message)
  String get fullMessage =>
      spMessage?.isNotEmpty == true ? spMessage! : message;
}