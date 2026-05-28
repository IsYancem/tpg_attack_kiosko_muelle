// lib/models/psc/psc_models.dart

typedef JsonMap = Map<String, dynamic>;

class PscApiEnvelope<T> {
  final int errorCode;
  final String message;
  final T? data;
  final JsonMap raw;

  const PscApiEnvelope({
    required this.errorCode,
    required this.message,
    required this.data,
    required this.raw,
  });

  bool get isOk => errorCode == 0;

  factory PscApiEnvelope.fromJson(
    JsonMap json,
    T Function(JsonMap data) mapper,
  ) {
    final rawData = json['data'];

    return PscApiEnvelope<T>(
      errorCode: int.tryParse(json['errorCode']?.toString() ?? '1') ?? 1,
      message: json['message']?.toString() ?? '',
      data: rawData is JsonMap ? mapper(rawData) : null,
      raw: json,
    );
  }
}

class PscNavegarData {
  final bool okToNavigate;
  final String? placaUsada;
  final double? peso;
  final String? ruc;
  final double? porteoPesoLimite;
  final List<String> warnings;
  final List<JsonMap> controls;
  final JsonMap services;

  const PscNavegarData({
    required this.okToNavigate,
    required this.placaUsada,
    required this.peso,
    required this.ruc,
    required this.porteoPesoLimite,
    required this.warnings,
    required this.controls,
    required this.services,
  });

  factory PscNavegarData.fromJson(JsonMap json) {
    return PscNavegarData(
      okToNavigate: json['okToNavigate'] == true,
      placaUsada: json['placaUsada']?.toString(),
      peso: double.tryParse(json['peso']?.toString() ?? ''),
      ruc: json['ruc']?.toString(),
      porteoPesoLimite:
          double.tryParse(json['porteoPesoLimite']?.toString() ?? ''),
      warnings: (json['warnings'] is List)
          ? (json['warnings'] as List).map((e) => e.toString()).toList()
          : const [],
      controls: (json['controls'] is List)
          ? (json['controls'] as List)
              .whereType<JsonMap>()
              .map(JsonMap.from)
              .toList()
          : const [],
      services: json['services'] is JsonMap
          ? JsonMap.from(json['services'] as JsonMap)
          : <String, dynamic>{},
    );
  }
}

class PscInicializarData {
  final bool okToNavigate;
  final String? placa;
  final double? pesoIngreso;
  final String? nombreConductor;
  final String? tipoLicencia;
  final String? expiracionLicencia;
  final String? cedula;
  final int? tpgOrigen;
  final int? tpgDestino;
  final List<JsonMap> uiHints;
  final List<JsonMap> controls;
  final JsonMap services;

  const PscInicializarData({
    required this.okToNavigate,
    required this.placa,
    required this.pesoIngreso,
    required this.nombreConductor,
    required this.tipoLicencia,
    required this.expiracionLicencia,
    required this.cedula,
    required this.tpgOrigen,
    required this.tpgDestino,
    required this.uiHints,
    required this.controls,
    required this.services,
  });

  factory PscInicializarData.fromJson(JsonMap json) {
    return PscInicializarData(
      okToNavigate: json['okToNavigate'] == true,
      placa: json['placa']?.toString(),
      pesoIngreso: double.tryParse(json['pesoIngreso']?.toString() ?? ''),
      nombreConductor: json['nombreConductor']?.toString(),
      tipoLicencia: json['tipoLicencia']?.toString(),
      expiracionLicencia: json['expiracionLicencia']?.toString(),
      cedula: json['cedula']?.toString(),
      tpgOrigen: int.tryParse(json['tpgOrigen']?.toString() ?? ''),
      tpgDestino: int.tryParse(json['tpgDestino']?.toString() ?? ''),
      uiHints: (json['uiHints'] is List)
          ? (json['uiHints'] as List)
              .whereType<JsonMap>()
              .map(JsonMap.from)
              .toList()
          : const [],
      controls: (json['controls'] is List)
          ? (json['controls'] as List)
              .whereType<JsonMap>()
              .map(JsonMap.from)
              .toList()
          : const [],
      services: json['services'] is JsonMap
          ? JsonMap.from(json['services'] as JsonMap)
          : <String, dynamic>{},
    );
  }
}

class PscGuardarData {
  final bool ok;
  final int? numero;
  final String? resultado;
  final List<JsonMap> controls;
  final JsonMap services;

  const PscGuardarData({
    required this.ok,
    required this.numero,
    required this.resultado,
    required this.controls,
    required this.services,
  });

  factory PscGuardarData.fromJson(JsonMap json) {
    return PscGuardarData(
      ok: json['ok'] == true,
      numero: int.tryParse(json['numero']?.toString() ?? ''),
      resultado: json['resultado']?.toString(),
      controls: (json['controls'] is List)
          ? (json['controls'] as List)
              .whereType<JsonMap>()
              .map(JsonMap.from)
              .toList()
          : const [],
      services: json['services'] is JsonMap
          ? JsonMap.from(json['services'] as JsonMap)
          : <String, dynamic>{},
    );
  }
}

class PscTerminarData {
  final bool okToNavigate;
  final JsonMap uiHints;
  final List<JsonMap> controls;
  final JsonMap services;

  const PscTerminarData({
    required this.okToNavigate,
    required this.uiHints,
    required this.controls,
    required this.services,
  });

  factory PscTerminarData.fromJson(JsonMap json) {
    return PscTerminarData(
      okToNavigate: json['okToNavigate'] == true,
      uiHints: json['uiHints'] is JsonMap
          ? JsonMap.from(json['uiHints'] as JsonMap)
          : <String, dynamic>{},
      controls: (json['controls'] is List)
          ? (json['controls'] as List)
              .whereType<JsonMap>()
              .map(JsonMap.from)
              .toList()
          : const [],
      services: json['services'] is JsonMap
          ? JsonMap.from(json['services'] as JsonMap)
          : <String, dynamic>{},
    );
  }
}