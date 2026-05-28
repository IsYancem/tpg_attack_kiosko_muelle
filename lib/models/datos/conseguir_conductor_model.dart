// lib/models/datos/conseguir_conductor_model.dart

typedef JsonMap = Map<String, dynamic>;

class ConseguirConductorRequest {
  final String? placa;

  const ConseguirConductorRequest({
    required this.placa,
  });

  JsonMap toJson() => {
        'placa': placa?.trim().toUpperCase(),
      };
}

class ConseguirConductorResponse {
  final String? placa;
  final ConseguirConductorRow? conductor;
  final ConseguirConductorServices? services;

  const ConseguirConductorResponse({
    required this.placa,
    required this.conductor,
    required this.services,
  });

  factory ConseguirConductorResponse.fromJson(JsonMap json) {
    return ConseguirConductorResponse(
      placa: json['placa']?.toString(),
      conductor: json['conductor'] is JsonMap
          ? ConseguirConductorRow.fromJson(
              Map<String, dynamic>.from(json['conductor'] as JsonMap),
            )
          : null,
      services: json['services'] is JsonMap
          ? ConseguirConductorServices.fromJson(
              Map<String, dynamic>.from(json['services'] as JsonMap),
            )
          : null,
    );
  }

  JsonMap toJson() => {
        'placa': placa,
        'conductor': conductor?.toJson(),
        'services': services?.toJson(),
      };
}

class ConseguirConductorRow {
  final int codError;
  final String desError;
  final double? numTran;
  final String? numPlaca;
  final String? chofer;
  final String? fechaIng;
  final String? estado;
  final String? tipoTran;
  final String? codtipo;
  final String? codContenedor;
  final double? tara;
  final double? pesoing;
  final double? pesosal;

  const ConseguirConductorRow({
    required this.codError,
    required this.desError,
    required this.numTran,
    required this.numPlaca,
    required this.chofer,
    required this.fechaIng,
    required this.estado,
    required this.tipoTran,
    required this.codtipo,
    required this.codContenedor,
    required this.tara,
    required this.pesoing,
    required this.pesosal,
  });

  factory ConseguirConductorRow.fromJson(JsonMap json) {
    return ConseguirConductorRow(
      codError: _toInt(json['cod_error'] ?? json['codError']) ?? 1,
      desError: json['des_error']?.toString() ??
          json['desError']?.toString() ??
          '',
      numTran: _toDouble(json['numTran']),
      numPlaca: json['numPlaca']?.toString(),
      chofer: json['chofer']?.toString().trim(),
      fechaIng: json['fechaIng']?.toString(),
      estado: json['Estado']?.toString() ?? json['estado']?.toString(),
      tipoTran: json['tipoTran']?.toString(),
      codtipo: json['codtipo']?.toString(),
      codContenedor: json['codContenedor']?.toString(),
      tara: _toDouble(json['tara']),
      pesoing: _toDouble(json['pesoing']),
      pesosal: _toDouble(json['pesosal']),
    );
  }

  bool get isOk => codError == 0;

  bool get hasChofer => chofer != null && chofer!.trim().isNotEmpty;

  JsonMap toJson() => {
        'cod_error': codError,
        'des_error': desError,
        'numTran': numTran,
        'numPlaca': numPlaca,
        'chofer': chofer,
        'fechaIng': fechaIng,
        'Estado': estado,
        'tipoTran': tipoTran,
        'codtipo': codtipo,
        'codContenedor': codContenedor,
        'tara': tara,
        'pesoing': pesoing,
        'pesosal': pesosal,
      };

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }
}

class ConseguirConductorServices {
  final ConseguirConductorStep? atkGetUltimoChoferPorPlaca;

  const ConseguirConductorServices({
    required this.atkGetUltimoChoferPorPlaca,
  });

  factory ConseguirConductorServices.fromJson(JsonMap json) {
    return ConseguirConductorServices(
      atkGetUltimoChoferPorPlaca:
          json['atkGetUltimoChoferPorPlaca'] is JsonMap
              ? ConseguirConductorStep.fromJson(
                  Map<String, dynamic>.from(
                    json['atkGetUltimoChoferPorPlaca'] as JsonMap,
                  ),
                )
              : null,
    );
  }

  JsonMap toJson() => {
        'atkGetUltimoChoferPorPlaca':
            atkGetUltimoChoferPorPlaca?.toJson(),
      };
}

class ConseguirConductorStep {
  final int errorCode;
  final String message;
  final ConseguirConductorRow? data;

  const ConseguirConductorStep({
    required this.errorCode,
    required this.message,
    required this.data,
  });

  factory ConseguirConductorStep.fromJson(JsonMap json) {
    return ConseguirConductorStep(
      errorCode: ConseguirConductorRow._toInt(json['errorCode']) ?? 1,
      message: json['message']?.toString() ?? '',
      data: json['data'] is JsonMap
          ? ConseguirConductorRow.fromJson(
              Map<String, dynamic>.from(json['data'] as JsonMap),
            )
          : null,
    );
  }

  JsonMap toJson() => {
        'errorCode': errorCode,
        'message': message,
        'data': data?.toJson(),
      };
}