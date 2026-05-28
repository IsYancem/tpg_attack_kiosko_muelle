// lib/models/trl/trl_transaccion_response_model.dart
// Autor: Abraham Yance
// Fecha: 2025-12-05
// Descripción: Modelo de response para transacción TRL (Traslado)

class TrlTransaccionResponseModel {
  final int errorCode;
  final String message;
  final TrlTransaccionDataModel? data;

  TrlTransaccionResponseModel({
    required this.errorCode,
    required this.message,
    this.data,
  });

  factory TrlTransaccionResponseModel.fromJson(Map<String, dynamic> json) {
    return TrlTransaccionResponseModel(
      errorCode: json['errorCode'] as int,
      message: json['message'] as String,
      data: json['data'] != null
          ? TrlTransaccionDataModel.fromJson(
              json['data'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'errorCode': errorCode,
    'message': message,
    'data': data?.toJson(),
  };

  /// Operador [] para acceder a services directamente
  TrlStepEnvelope? operator [](String key) => data?.services[key];
}

class TrlTransaccionDataModel {
  final int? numero;
  final Map<String, TrlStepEnvelope> services;
  final List<TrlUiHint>? uiHints;

  TrlTransaccionDataModel({this.numero, required this.services, this.uiHints});

  factory TrlTransaccionDataModel.fromJson(Map<String, dynamic> json) {
    final servicesMap = <String, TrlStepEnvelope>{};

    if (json['services'] != null) {
      final servicesJson = json['services'] as Map<String, dynamic>;
      servicesJson.forEach((key, value) {
        servicesMap[key] = TrlStepEnvelope.fromJson(
          value as Map<String, dynamic>,
        );
      });
    }

    List<TrlUiHint>? hints;
    if (json['uiHints'] != null) {
      hints = (json['uiHints'] as List)
          .map((e) => TrlUiHint.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return TrlTransaccionDataModel(
      numero: json['numero'] as int?,
      services: servicesMap,
      uiHints: hints,
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
      if (uiHints != null) 'uiHints': uiHints!.map((h) => h.toJson()).toList(),
    };
  }
}

class TrlUiHint {
  final String key;
  final dynamic value;

  TrlUiHint({required this.key, required this.value});

  factory TrlUiHint.fromJson(Map<String, dynamic> json) {
    return TrlUiHint(key: json['key'] as String, value: json['value']);
  }

  Map<String, dynamic> toJson() => {'key': key, 'value': value};
}

class TrlStepEnvelope {
  final int errorCode;
  final String message;
  final dynamic _data;
  final int? spErrorCode;
  final String? spMessage;
  final String? source;

  TrlStepEnvelope({
    required this.errorCode,
    required this.message,
    dynamic data,
    this.spErrorCode,
    this.spMessage,
    this.source,
  }) : _data = data;

  factory TrlStepEnvelope.fromJson(Map<String, dynamic> json) {
    return TrlStepEnvelope(
      errorCode: json['errorCode'] as int,
      message: json['message'] as String,
      data: json['data'],
      spErrorCode: json['spErrorCode'] as int?,
      spMessage: json['spMessage'] as String?,
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'errorCode': errorCode,
    'message': message,
    'data': _data,
    'spErrorCode': spErrorCode,
    'spMessage': spMessage,
    'source': source,
  };

  /// Helper para obtener data como Map
  Map<String, dynamic>? get dataAsMap {
    if (_data is Map<String, dynamic>) {
      return _data;
    }
    return null;
  }

  /// Helper para obtener data como List
  List<dynamic>? get dataAsList {
    if (_data is List) {
      return _data;
    }
    return null;
  }

  /// Helper para verificar si el paso fue exitoso
  bool get isSuccess => errorCode == 0;

  /// Helper para obtener mensaje completo (spMessage si existe, sino message)
  String get fullMessage =>
      spMessage?.isNotEmpty == true ? spMessage! : message;
}

// ═══════════════════════════════════════════════════════════════════════════
// MODELOS DE DATOS ESPECÍFICOS PARA CADA SERVICIO TRL
// ═══════════════════════════════════════════════════════════════════════════

/// Datos de RIDT (atack..atk_cons_ridt)
class TrlRidtData {
  final String? msg;

  TrlRidtData({this.msg});

  factory TrlRidtData.fromJson(Map<String, dynamic> json) {
    return TrlRidtData(msg: json['msg'] as String?);
  }
}

/// Datos de TRL Cons CNT (disv..atk_trl_cons_datos)
/// Este es el servicio principal que trae los datos del traslado
class TrlConsCntData {
  final int? corOperacion;
  final String? areaDestino;
  final int? anoOperacion;
  final String? hora;
  final String? bl;
  final String? origen;
  final String? rutaTraslado;
  final String? salidaNum;
  final int? maeId;
  final String? zonaPrimariaOrigen;
  final String? fechaestTraslado;
  final String? destino;
  final String? desError;
  final String? notificarStm;
  final String? placa;
  final String? docTransporte;
  final int? peso;
  final String? zonaPrimariaDestino;
  final int? tara;
  final String? detalle;
  final String? rucEmpresaTransporte;
  final String? areaOrigen;
  final String? fecha;
  final String? nombreEmpresaTransporte;
  final int? codError;

  TrlConsCntData({
    this.corOperacion,
    this.areaDestino,
    this.anoOperacion,
    this.hora,
    this.bl,
    this.origen,
    this.rutaTraslado,
    this.salidaNum,
    this.maeId,
    this.zonaPrimariaOrigen,
    this.fechaestTraslado,
    this.destino,
    this.desError,
    this.notificarStm,
    this.placa,
    this.docTransporte,
    this.peso,
    this.zonaPrimariaDestino,
    this.tara,
    this.detalle,
    this.rucEmpresaTransporte,
    this.areaOrigen,
    this.fecha,
    this.nombreEmpresaTransporte,
    this.codError,
  });

  factory TrlConsCntData.fromJson(Map<String, dynamic> json) {
    return TrlConsCntData(
      corOperacion: (json['cor_operacion'] as num?)?.toInt(),
      areaDestino: json['areaDestino'] as String?,
      anoOperacion: (json['ano_operacion'] as num?)?.toInt(),
      hora: json['hora'] as String?,
      bl: json['bl'] as String?,
      origen: json['origen'] as String?,
      rutaTraslado: json['rutaTraslado'] as String?,
      salidaNum: json['salida_num'] as String?,
      maeId: (json['mae_id'] as num?)?.toInt(),
      zonaPrimariaOrigen: json['zonaPrimariaOrigen'] as String?,
      fechaestTraslado: json['fechaestTraslado'] as String?,
      destino: json['destino'] as String?,
      desError: json['desError'] as String?,
      notificarStm: json['notificar_stm'] as String?,
      placa: json['placa'] as String?,
      docTransporte: json['docTransporte'] as String?,
      peso: (json['peso'] as num?)?.toInt(),
      zonaPrimariaDestino: json['zonaPrimariaDestino'] as String?,
      tara: (json['tara'] as num?)?.toInt(),
      detalle: json['detalle'] as String?,
      rucEmpresaTransporte: json['rucEmpresaTransporte'] as String?,
      areaOrigen: json['areaOrigen'] as String?,
      fecha: json['fecha'] as String?,
      nombreEmpresaTransporte: json['nombreEmpresaTransporte'] as String?,
      codError: (json['codError'] as num?)?.toInt(),
    );
  }

  /// Getter para operación completa (año-correlativo)
  String get operacionCompleta {
    if (anoOperacion != null && corOperacion != null) {
      return '$anoOperacion-$corOperacion';
    }
    return '';
  }
}

/// Datos de Transacción EXP (base_INARPI..atk_transaccion_exp)
class TrlTransaccionExpData {
  final int? error;
  final String? descError;
  final int? numero;

  TrlTransaccionExpData({this.error, this.descError, this.numero});

  factory TrlTransaccionExpData.fromJson(Map<String, dynamic> json) {
    return TrlTransaccionExpData(
      error: (json['error'] as num?)?.toInt(),
      descError: json['desc_error'] as String?,
      numero: (json['numero'] as num?)?.toInt(),
    );
  }
}

/// Datos de Insert Traslado (disv..atk_insert_traslado_kiosk)
class TrlInsertTrasladoData {
  final String? desError;
  final int? codError;

  TrlInsertTrasladoData({this.desError, this.codError});

  factory TrlInsertTrasladoData.fromJson(Map<String, dynamic> json) {
    return TrlInsertTrasladoData(
      desError: json['des_error'] as String?,
      codError: (json['cod_error'] as num?)?.toInt(),
    );
  }
}

/// Datos de Set Lect Antena (atack..atk_set_lect_antena)
class TrlSetLectAntenaData {
  final int? codError;
  final String? desError;

  TrlSetLectAntenaData({this.codError, this.desError});

  factory TrlSetLectAntenaData.fromJson(Map<String, dynamic> json) {
    return TrlSetLectAntenaData(
      codError: (json['cod_error'] as num?)?.toInt(),
      desError: json['des_error'] as String?,
    );
  }
}

/// Datos de Act Hora Barrera (disv..atk_act_hora_barrera)
class TrlActHoraBarreraData {
  final int? error;

  TrlActHoraBarreraData({this.error});

  factory TrlActHoraBarreraData.fromJson(Map<String, dynamic> json) {
    return TrlActHoraBarreraData(error: (json['error'] as num?)?.toInt());
  }
}

/// Datos de Monitor ATK (tcp://...)
class TrlMonitorAtkData {
  final bool? sent;
  final String? error;
  final Map<String, dynamic>? payload;

  TrlMonitorAtkData({this.sent, this.error, this.payload});

  factory TrlMonitorAtkData.fromJson(Map<String, dynamic> json) {
    return TrlMonitorAtkData(
      sent: json['sent'] as bool?,
      error: json['error'] as String?,
      payload: json['payload'] as Map<String, dynamic>?,
    );
  }

  /// Getters para datos del payload
  String? get accion => payload?['accion'] as String?;
  String? get patio => payload?['patio'] as String?;
  String? get placa => payload?['placa'] as String?;
  int? get bascula => (payload?['bascula'] as num?)?.toInt();
  String? get transaccion => payload?['transaccion'] as String?;
  String? get tipoMov => payload?['tipo_mov'] as String?;
  String? get barrera => payload?['barrera'] as String?;
  String? get fechaBarrera => payload?['fecha_barrera'] as String?;
  int? get inOut => (payload?['in_out'] as num?)?.toInt();
  int? get vehicleAccessId => (payload?['vehicle_access_id'] as num?)?.toInt();
}
