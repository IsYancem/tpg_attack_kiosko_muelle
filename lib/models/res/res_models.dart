// lib/models/res/res_models.dart
// Autor: Abraham Yance
// Fecha: 2025-12-29
// Modelos: RES (init/guardar/terminar/cancelar/imprimir)

typedef JsonMap = Map<String, dynamic>;

T? _as<T>(dynamic v) => v is T ? v : null;

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim());
  return null;
}

/// Envelope estándar backend NestJS { errorCode, message, data }
class ApiEnvelope<T> {
  final int errorCode;
  final String message;
  final T? data;

  const ApiEnvelope({
    required this.errorCode,
    required this.message,
    this.data,
  });

  bool get isOk => errorCode == 0;

  static ApiEnvelope<T> fromJson<T>(
    JsonMap json,
    T Function(JsonMap) parseData,
  ) {
    return ApiEnvelope<T>(
      errorCode: _toInt(json['errorCode']) ?? 1,
      message: (json['message'] ?? '').toString(),
      data: json['data'] is Map<String, dynamic>
          ? parseData(json['data'] as JsonMap)
          : null,
    );
  }
}

/// StepEnvelope backend { errorCode, message, data }
class StepEnvelope {
  final int errorCode;
  final String message;
  final dynamic data;

  const StepEnvelope({
    required this.errorCode,
    required this.message,
    this.data,
  });

  bool get isOk => errorCode == 0;

  factory StepEnvelope.fromJson(JsonMap json) => StepEnvelope(
    errorCode: _toInt(json['errorCode']) ?? 1,
    message: (json['message'] ?? '').toString(),
    data: json['data'],
  );

  JsonMap toJson() => {
    'errorCode': errorCode,
    'message': message,
    'data': data,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Common Context (frontend) - espejo de ResCommonContextDto (backend)
// ─────────────────────────────────────────────────────────────────────────────

class ResCommonContext {
  String? placa;
  int? vehicleAccessId;
  int? doorNumber; // 1 entrando, 2 saliendo
  String? garitaLetra;
  String? garitaNumero;
  String? tpg; 

  String? ruc;
  String? nombres;
  String? fotoBase64;
  String? tipoMov;
  String? fechaBarreraRaw;
  String? usuarioNombre;
  String? bodegueroUser;
  String? emailJefe;

  bool? confirm;

  ResCommonContext();

  JsonMap toJson() => {
    'placa': placa,
    'vehicle_access_id': vehicleAccessId,
    'door_number': doorNumber,
    'garita_letra': garitaLetra,
    'garita_numero': garitaNumero,
    'TPG': tpg,
    'ruc': ruc,
    'nombres': nombres,
    'foto_base64': fotoBase64,
    'TIPOMOV': tipoMov,
    'fecha_barrera_raw': fechaBarreraRaw,
    'usuario_nombre': usuarioNombre,
    'bodegueroUser': bodegueroUser,
    'email_jefe': emailJefe,
    'confirm': confirm,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// INIT
// ─────────────────────────────────────────────────────────────────────────────

class ResInitRequest extends ResCommonContext {}

class ResInitData {
  final int? numTrans;
  final Map<String, StepEnvelope> services;

  ResInitData({required this.numTrans, required this.services});

  factory ResInitData.fromJson(JsonMap json) {
    final sv = <String, StepEnvelope>{};
    final rawSv = json['services'];
    if (rawSv is Map<String, dynamic>) {
      rawSv.forEach((k, v) {
        if (v is Map<String, dynamic>) sv[k] = StepEnvelope.fromJson(v);
      });
    }
    return ResInitData(
      numTrans: _toInt(json['num_trans'] ?? json['numTrans']),
      services: sv,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GUARDAR
// ─────────────────────────────────────────────────────────────────────────────

class ResGuardarRequest extends ResCommonContext {
  double? pesoIng;
  double? pesoSal;

  String? observacion;
  String? tipoTran;

  String? codProducto1;
  String? codTipoCarga;
  String? codBuque;

  String? estadoUp;
  int? numTrans;

  @override
  JsonMap toJson() {
    final base = super.toJson();
    base.addAll({
      'peso_ing': pesoIng,
      'peso_sal': pesoSal,
      'observacion': observacion,
      'tipoTran': tipoTran,
      'cod_producto1': codProducto1,
      'codTipoCarga': codTipoCarga,
      'codBuque': codBuque,
      'estado_up': estadoUp,
      'num_trans': numTrans,
    });
    return base;
  }
}

class ResGuardarData {
  final int? numTrans;
  final String? inOut; // 'I' | 'O'
  final int? doorOutTarget;
  final Map<String, StepEnvelope> services;
  final Map<String, dynamic>? actions;

  ResGuardarData({
    required this.numTrans,
    required this.inOut,
    required this.doorOutTarget,
    required this.services,
    required this.actions,
  });

  factory ResGuardarData.fromJson(JsonMap json) {
    final sv = <String, StepEnvelope>{};
    final rawSv = json['services'];
    if (rawSv is Map<String, dynamic>) {
      rawSv.forEach((k, v) {
        if (v is Map<String, dynamic>) sv[k] = StepEnvelope.fromJson(v);
      });
    }

    return ResGuardarData(
      numTrans: _toInt(json['num_trans']),
      inOut: _as<String>(json['IN_OUT'] ?? json['in_out']),
      doorOutTarget: _toInt(json['door_out_target']),
      services: sv,
      actions: json['actions'] is Map<String, dynamic>
          ? (json['actions'] as Map<String, dynamic>)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TERMINAR
// ─────────────────────────────────────────────────────────────────────────────

class ResTerminarRequest extends ResCommonContext {
  int? numTrans;

  @override
  JsonMap toJson() {
    final base = super.toJson();
    base['num_trans'] = numTrans;
    return base;
  }
}

class ResTerminarData {
  final String? inOut;
  final int? doorOutTarget;
  final Map<String, StepEnvelope> services;

  ResTerminarData({
    required this.inOut,
    required this.doorOutTarget,
    required this.services,
  });

  factory ResTerminarData.fromJson(JsonMap json) {
    final sv = <String, StepEnvelope>{};
    final rawSv = json['services'];
    if (rawSv is Map<String, dynamic>) {
      rawSv.forEach((k, v) {
        if (v is Map<String, dynamic>) sv[k] = StepEnvelope.fromJson(v);
      });
    }

    return ResTerminarData(
      inOut: _as<String>(json['IN_OUT'] ?? json['in_out']),
      doorOutTarget: _toInt(json['door_out_target']),
      services: sv,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CANCELAR
// ─────────────────────────────────────────────────────────────────────────────

class ResCancelarRequest extends ResCommonContext {
  int? numTrans;
  String? kioskServer;
  int? kioskPort;

  @override
  JsonMap toJson() {
    final base = super.toJson();
    base.addAll({
      'num_trans': numTrans,
      'kioskServer': kioskServer,
      'kioskPort': kioskPort,
    });
    return base;
  }
}

class ResCancelarData {
  final Map<String, StepEnvelope> services;

  ResCancelarData({required this.services});

  factory ResCancelarData.fromJson(JsonMap json) {
    final sv = <String, StepEnvelope>{};
    final rawSv = json['services'];
    if (rawSv is Map<String, dynamic>) {
      rawSv.forEach((k, v) {
        if (v is Map<String, dynamic>) sv[k] = StepEnvelope.fromJson(v);
      });
    }
    return ResCancelarData(services: sv);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMPRIMIR
// ─────────────────────────────────────────────────────────────────────────────

class ResImprimirRequest extends ResCommonContext {
  String? tipo; // ← AGREGAR ESTE CAMPO
  int? numTrans;
  double? pesoIng;
  double? pesoSal;

  @override
  JsonMap toJson() {
    final base = super.toJson();
    base.addAll({
      'tipo': tipo,
      'num_trans': numTrans,
      'peso_ing': pesoIng,
      'peso_sal': pesoSal,
    });
    return base;
  }
}

class ResPrintable {
  final String tipo; // 'R'
  final String transaccion; // 'SRES'
  final String? placa;
  final int? numTrans;
  final double? pesoIng;
  final double? pesoSal;
  final int? vehicleAccessId;

  ResPrintable({
    required this.tipo,
    required this.transaccion,
    required this.placa,
    required this.numTrans,
    required this.pesoIng,
    required this.pesoSal,
    required this.vehicleAccessId,
  });

  factory ResPrintable.fromJson(JsonMap json) => ResPrintable(
    tipo: (json['tipo'] ?? 'R').toString(),
    transaccion: (json['transaccion'] ?? 'SRES').toString(),
    placa: _as<String>(json['placa']),
    numTrans: _toInt(json['num_trans']),
    pesoIng: _toDouble(json['peso_ing']),
    pesoSal: _toDouble(json['peso_sal']),
    vehicleAccessId: _toInt(json['vehicle_access_id']),
  );

  JsonMap toJson() => {
    'tipo': tipo,
    'transaccion': transaccion,
    'placa': placa,
    'num_trans': numTrans,
    'peso_ing': pesoIng,
    'peso_sal': pesoSal,
    'vehicle_access_id': vehicleAccessId,
  };
}

class ResImprimirData {
  final ResPrintable? printable;
  final Map<String, StepEnvelope> services;

  ResImprimirData({required this.printable, required this.services});

  factory ResImprimirData.fromJson(JsonMap json) {
    final sv = <String, StepEnvelope>{};
    final rawSv = json['services'];
    if (rawSv is Map<String, dynamic>) {
      rawSv.forEach((k, v) {
        if (v is Map<String, dynamic>) sv[k] = StepEnvelope.fromJson(v);
      });
    }

    final pr = json['printable'];
    return ResImprimirData(
      printable: pr is Map<String, dynamic> ? ResPrintable.fromJson(pr) : null,
      services: sv,
    );
  }
}
