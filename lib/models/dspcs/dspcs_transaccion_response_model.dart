// lib/models/dspcs/dspcs_transaccion_response_model.dart
// Autor: Abraham Yance
// Fecha: 2025-12-04
// Descripción: Modelo de response para transacción DSP-CS (Despacho Carga Suelta)

class DspCsTransaccionResponseModel {
  final int errorCode;
  final String message;
  final DspCsTransaccionDataModel? data;

  DspCsTransaccionResponseModel({
    required this.errorCode,
    required this.message,
    this.data,
  });

  factory DspCsTransaccionResponseModel.fromJson(Map<String, dynamic> json) {
    return DspCsTransaccionResponseModel(
      errorCode: json['errorCode'] as int,
      message: json['message'] as String,
      data: json['data'] != null
          ? DspCsTransaccionDataModel.fromJson(
              json['data'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {'errorCode': errorCode, 'message': message, 'data': data?.toJson()};
  }

  /// Operador [] para acceder a services directamente
  DspCsStepEnvelope? operator [](String key) => data?.services[key];
}

class DspCsTransaccionDataModel {
  final int? numero;
  final Map<String, DspCsStepEnvelope> services;
  final int? elapsedMs;

  DspCsTransaccionDataModel({
    this.numero,
    required this.services,
    this.elapsedMs,
  });

  factory DspCsTransaccionDataModel.fromJson(Map<String, dynamic> json) {
    final servicesMap = <String, DspCsStepEnvelope>{};

    if (json['services'] != null) {
      final servicesJson = json['services'] as Map<String, dynamic>;
      servicesJson.forEach((key, value) {
        servicesMap[key] = DspCsStepEnvelope.fromJson(
          value as Map<String, dynamic>,
        );
      });
    }

    return DspCsTransaccionDataModel(
      numero: json['numero'] as int?,
      services: servicesMap,
      elapsedMs: json['elapsedMs'] as int?,
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
      if (elapsedMs != null) 'elapsedMs': elapsedMs,
    };
  }
}

class DspCsStepEnvelope {
  final int errorCode;
  final String message;
  final dynamic data; // Puede ser Map o List dependiendo del servicio
  final int? spErrorCode;
  final String? spMessage;
  final String? source;
  final dynamic rawResponse;

  DspCsStepEnvelope({
    required this.errorCode,
    required this.message,
    this.data,
    this.spErrorCode,
    this.spMessage,
    this.source,
    this.rawResponse,
  });

  factory DspCsStepEnvelope.fromJson(Map<String, dynamic> json) {
    return DspCsStepEnvelope(
      errorCode: json['errorCode'] as int,
      message: json['message'] as String,
      data: json['data'],
      spErrorCode: json['spErrorCode'] as int?,
      spMessage: json['spMessage'] as String?,
      source: json['source'] as String?,
      rawResponse: json['rawResponse'],
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
      'rawResponse': rawResponse,
    };
  }

  /// Helper para verificar si el paso fue exitoso
  bool get isSuccess => errorCode == 0;

  /// Helper para obtener mensaje completo (spMessage si existe, sino message)
  String get fullMessage =>
      spMessage?.isNotEmpty == true ? spMessage! : message;

  /// Helper para obtener data como Map (si aplica)
  Map<String, dynamic>? get dataAsMap =>
      data is Map<String, dynamic> ? data as Map<String, dynamic> : null;

  /// Helper para obtener data como List (para dres_cons)
  List<dynamic>? get dataAsList => data is List ? data as List<dynamic> : null;
}

/// Modelo específico para los datos del ponchado DSP-CS
class DspCsPonchadoData {
  final int? codChofer;
  final String? importador;
  final String? cargaSuelta;
  final int? patio;
  final int? aniodres1;
  final int? cordres1;
  final int? aniodres2;
  final int? cordres2;
  final int? turno;
  final double? pesoBultos;
  final int? totalBultos;
  final int? numregAtk;
  final int? cargaNoPesable;
  final String? fechaProgramado;

  DspCsPonchadoData({
    this.codChofer,
    this.importador,
    this.cargaSuelta,
    this.patio,
    this.aniodres1,
    this.cordres1,
    this.aniodres2,
    this.cordres2,
    this.turno,
    this.pesoBultos,
    this.totalBultos,
    this.numregAtk,
    this.cargaNoPesable,
    this.fechaProgramado,
  });

  factory DspCsPonchadoData.fromJson(Map<String, dynamic> json) {
    return DspCsPonchadoData(
      codChofer: (json['cod_chofer'] as num?)?.toInt(),
      importador: json['importador'] as String?,
      cargaSuelta: json['carga_suelta'] as String?,
      patio: (json['patio'] as num?)?.toInt(),
      aniodres1: (json['aniodres1'] as num?)?.toInt(),
      cordres1: (json['cordres1'] as num?)?.toInt(),
      aniodres2: (json['aniodres2'] as num?)?.toInt(),
      cordres2: (json['cordres2'] as num?)?.toInt(),
      turno: (json['turno'] as num?)?.toInt(),
      pesoBultos: (json['peso_bultos'] as num?)?.toDouble(),
      totalBultos: (json['total_bultos'] as num?)?.toInt(),
      numregAtk: (json['numreg_atk'] as num?)?.toInt(),
      cargaNoPesable: (json['carga_no_pesable'] as num?)?.toInt(),
      fechaProgramado: json['fecha_programado'] as String?,
    );
  }
}

/// Modelo específico para los datos de dres_cons (lista de DRES)
class DspCsDresConsItem {
  final int? anodres;
  final int? cordres;
  final String? numTarja;
  final int? canbulto;
  final double? pesbulto;

  DspCsDresConsItem({
    this.anodres,
    this.cordres,
    this.numTarja,
    this.canbulto,
    this.pesbulto,
  });

  factory DspCsDresConsItem.fromJson(Map<String, dynamic> json) {
    return DspCsDresConsItem(
      anodres: (json['anodres'] as num?)?.toInt(),
      cordres: (json['cordres'] as num?)?.toInt(),
      numTarja: json['num_tarja']?.toString().trim(),
      canbulto: (json['canbulto'] as num?)?.toInt(),
      pesbulto: (json['pesbulto'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'anodres': anodres,
      'cordres': cordres,
      'num_tarja': numTarja,
      'canbulto': canbulto,
      'pesbulto': pesbulto,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ✅ GETTERS PARA IMPRESIÓN Y UI
  // ═══════════════════════════════════════════════════════════════════════════

  /// Concatenar año y correlativo como "{anodres}{cordres}"
  String get dresCompleto => '${anodres ?? ''}${cordres ?? ''}';

  /// Getters con valores por defecto para evitar nulls en la UI/impresión
  int get anoDres => anodres ?? 0;
  int get corDres => cordres ?? 0;
  String get tarja => numTarja ?? '';
  int get canBulto => canbulto ?? 0;
  double get pesBulto => pesbulto ?? 0.0;
}

/// Modelo específico para validar_peso
class DspCsValidarPesoData {
  final double? peso;
  final bool? valid;

  DspCsValidarPesoData({this.peso, this.valid});

  factory DspCsValidarPesoData.fromJson(Map<String, dynamic> json) {
    return DspCsValidarPesoData(
      peso: (json['peso'] as num?)?.toDouble(),
      valid: json['valid'] as bool?,
    );
  }
}

/// Modelo específico para transaccion_exp
class DspCsTransaccionExpData {
  final int? error;
  final String? descError;
  final int? numero;

  DspCsTransaccionExpData({this.error, this.descError, this.numero});

  factory DspCsTransaccionExpData.fromJson(Map<String, dynamic> json) {
    return DspCsTransaccionExpData(
      error: (json['error'] as num?)?.toInt(),
      descError: json['desc_error'] as String?,
      numero: (json['numero'] as num?)?.toInt(),
    );
  }
}

/// Modelo específico para vehicle_access_insertar
class DspCsVehicleAccessInsertarData {
  final int? errores;
  final String? descError;

  DspCsVehicleAccessInsertarData({this.errores, this.descError});

  factory DspCsVehicleAccessInsertarData.fromJson(Map<String, dynamic> json) {
    return DspCsVehicleAccessInsertarData(
      errores: (json['errores'] as num?)?.toInt(),
      descError: json['desc_error'] as String?,
    );
  }
}

/// Modelo específico para monitor_atk
class DspCsMonitorAtkData {
  final bool? sent;
  final Map<String, dynamic>? payload;

  DspCsMonitorAtkData({this.sent, this.payload});

  factory DspCsMonitorAtkData.fromJson(Map<String, dynamic> json) {
    return DspCsMonitorAtkData(
      sent: json['sent'] as bool?,
      payload: json['payload'] as Map<String, dynamic>?,
    );
  }
}
