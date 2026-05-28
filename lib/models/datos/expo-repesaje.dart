// lib/models/datos/expo_repesaje_model.dart
// Modelo para POST /kiosk/api/datos-muelle/expo-repesaje

// ---------------------------------------------------------------------------
// REQUEST
// ---------------------------------------------------------------------------
class ExpoRepesajeRequest {
  final String contenedor;

  const ExpoRepesajeRequest({required this.contenedor});

  Map<String, dynamic> toJson() => {'contenedor': contenedor};
}

// ---------------------------------------------------------------------------
// SOLICITUD UPDATE DISV
// ---------------------------------------------------------------------------
class SolicitudUpdateDisvDto {
  final int codError;
  final String msgError;

  final int? id;
  final String? uid;
  final int? disv;
  final String? contenedor;
  final String? tipoOperacion;
  final String? fechaRegistro;
  final String? usuarioRegistra;
  final String? fechaProcesa;
  final String? usuarioProcesa;
  final int? nuevoDisv;
  final String? nuevoContenedor;
  final int? estado;
  final String? facturarA;
  final String? fechaNotificacion;
  final String? codigoAutorizacion;

  const SolicitudUpdateDisvDto({
    required this.codError,
    required this.msgError,
    this.id,
    this.uid,
    this.disv,
    this.contenedor,
    this.tipoOperacion,
    this.fechaRegistro,
    this.usuarioRegistra,
    this.fechaProcesa,
    this.usuarioProcesa,
    this.nuevoDisv,
    this.nuevoContenedor,
    this.estado,
    this.facturarA,
    this.fechaNotificacion,
    this.codigoAutorizacion,
  });

  bool get isOk => codError == 0;

  factory SolicitudUpdateDisvDto.fromJson(Map<String, dynamic> json) {
    return SolicitudUpdateDisvDto(
      codError: _parseInt(json['cod_error']) ?? 1,
      msgError: json['msg_error']?.toString() ?? 'Sin mensaje',
      id: _parseInt(json['id']),
      uid: json['uid']?.toString(),
      disv: _parseInt(json['disv']),
      contenedor: json['contenedor']?.toString(),
      tipoOperacion: json['tipo_operacion']?.toString(),
      fechaRegistro: json['fecha_registro']?.toString(),
      usuarioRegistra: json['usuario_registra']?.toString(),
      fechaProcesa: json['fecha_procesa']?.toString(),
      usuarioProcesa: json['usuario_procesa']?.toString(),
      nuevoDisv: _parseInt(json['nuevo_disv']),
      nuevoContenedor: json['nuevo_contenedor']?.toString(),
      estado: _parseInt(json['estado']),
      facturarA: json['facturar_a']?.toString(),
      fechaNotificacion: json['fecha_notificacion']?.toString(),
      codigoAutorizacion: json['codigo_autorizacion']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'cod_error': codError,
        'msg_error': msgError,
        if (id != null) 'id': id,
        if (uid != null) 'uid': uid,
        if (disv != null) 'disv': disv,
        if (contenedor != null) 'contenedor': contenedor,
        if (tipoOperacion != null) 'tipo_operacion': tipoOperacion,
        if (fechaRegistro != null) 'fecha_registro': fechaRegistro,
        if (usuarioRegistra != null) 'usuario_registra': usuarioRegistra,
        if (fechaProcesa != null) 'fecha_procesa': fechaProcesa,
        if (usuarioProcesa != null) 'usuario_procesa': usuarioProcesa,
        if (nuevoDisv != null) 'nuevo_disv': nuevoDisv,
        if (nuevoContenedor != null) 'nuevo_contenedor': nuevoContenedor,
        if (estado != null) 'estado': estado,
        if (facturarA != null) 'facturar_a': facturarA,
        if (fechaNotificacion != null) 'fecha_notificacion': fechaNotificacion,
        if (codigoAutorizacion != null)
          'codigo_autorizacion': codigoAutorizacion,
      };

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}

// ---------------------------------------------------------------------------
// STEP ENVELOPE (para el campo services)
// ---------------------------------------------------------------------------
class ExpoRepesajeStepEnvelope {
  final int errorCode;
  final String message;
  final SolicitudUpdateDisvDto? data;

  const ExpoRepesajeStepEnvelope({
    required this.errorCode,
    required this.message,
    this.data,
  });

  bool get isOk => errorCode == 0;

  factory ExpoRepesajeStepEnvelope.fromJson(Map<String, dynamic> json) {
    return ExpoRepesajeStepEnvelope(
      errorCode: (json['errorCode'] as num?)?.toInt() ?? 1,
      message: json['message']?.toString() ?? '',
      data: json['data'] != null
          ? SolicitudUpdateDisvDto.fromJson(
              json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// DATA
// ---------------------------------------------------------------------------
class ExpoRepesajeData {
  final String? contenedor;
  final SolicitudUpdateDisvDto? solicitudUpdateDisv;
  final ExpoRepesajeStepEnvelope? atkConsSolicitudUpdateDisvP;

  const ExpoRepesajeData({
    this.contenedor,
    this.solicitudUpdateDisv,
    this.atkConsSolicitudUpdateDisvP,
  });

  factory ExpoRepesajeData.fromJson(Map<String, dynamic> json) {
    final services = json['services'] as Map<String, dynamic>?;

    return ExpoRepesajeData(
      contenedor: json['contenedor']?.toString(),
      solicitudUpdateDisv: json['solicitudUpdateDisv'] != null
          ? SolicitudUpdateDisvDto.fromJson(
              json['solicitudUpdateDisv'] as Map<String, dynamic>)
          : null,
      atkConsSolicitudUpdateDisvP:
          services?['atkConsSolicitudUpdateDisvP'] != null
              ? ExpoRepesajeStepEnvelope.fromJson(
                  services!['atkConsSolicitudUpdateDisvP']
                      as Map<String, dynamic>)
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'contenedor': contenedor,
        'solicitudUpdateDisv': solicitudUpdateDisv?.toJson(),
        'services': {
          if (atkConsSolicitudUpdateDisvP != null)
            'atkConsSolicitudUpdateDisvP': {
              'errorCode': atkConsSolicitudUpdateDisvP!.errorCode,
              'message': atkConsSolicitudUpdateDisvP!.message,
              'data': atkConsSolicitudUpdateDisvP!.data?.toJson(),
            },
        },
      };

  /// true ? tiene solicitud activa pendiente de procesar (estado 0 o 1).
  bool get hasActiveSolicitud {
    final s = solicitudUpdateDisv;
    if (s == null || !s.isOk) return false;
    final estado = s.estado ?? -1;
    return estado == 0 || estado == 1;
  }

  /// Tipo de operación normalizado en mayúsculas. Ej: "P", "EXP", etc.
  String get tipoOperacion =>
      solicitudUpdateDisv?.tipoOperacion?.trim().toUpperCase() ?? '';
}

// ---------------------------------------------------------------------------
// RESPONSE (ApiEnvelope raíz)
// Nota: se mapea al ApiEnvelope<ExpoRepesajeData> genérico del BaseApiService.
// ---------------------------------------------------------------------------
class ExpoRepesajeResponse {
  final int errorCode;
  final String message;
  final ExpoRepesajeData? data;

  const ExpoRepesajeResponse({
    required this.errorCode,
    required this.message,
    this.data,
  });

  bool get isOk => errorCode == 0;

  factory ExpoRepesajeResponse.fromJson(Map<String, dynamic> json) {
    return ExpoRepesajeResponse(
      errorCode: (json['errorCode'] as num?)?.toInt() ?? 1,
      message: json['message']?.toString() ?? '',
      data: json['data'] != null
          ? ExpoRepesajeData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}