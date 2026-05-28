// lib/models/exp_muelle/exp_muelle_models.dart
// Autor: Abraham Yance
// Modelos para el flujo EXP MUELLE:
//   POST kiosk/api/exp-muelle/inicializar
//   POST kiosk/api/exp-muelle/validar-contenedor
//   POST kiosk/api/exp-muelle/guardar
//   POST kiosk/api/exp-muelle/terminar

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS COMPARTIDOS
// ─────────────────────────────────────────────────────────────────────────────

class _H {
  static int? toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? toDbl(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String? toStr(dynamic v) =>
      v == null ? null : v.toString().trim().isEmpty ? null : v.toString().trim();

  static List<String> toStrList(dynamic v) {
    if (v is List) return v.whereType<String>().toList();
    return [];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP ENVELOPE GENÉRICO
// ─────────────────────────────────────────────────────────────────────────────

class ExpMuelleStepEnvelope {
  final int errorCode;
  final String message;
  final Map<String, dynamic>? data;

  const ExpMuelleStepEnvelope({
    required this.errorCode,
    required this.message,
    this.data,
  });

  bool get isOk => errorCode == 0;

  factory ExpMuelleStepEnvelope.fromJson(Map<String, dynamic> json) {
    return ExpMuelleStepEnvelope(
      errorCode: _H.toInt(json['errorCode']) ?? 1,
      message: _H.toStr(json['message']) ?? '',
      data: json['data'] as Map<String, dynamic>?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INICIALIZAR
// ─────────────────────────────────────────────────────────────────────────────

class ExpMuelleInicializarRequest {
  final String placa;
  final String cedula;
  final String? nombreConductor;
  final int vehicleAccessId;
  final int tpg;
  final String? garitaLetra;
  final int? garitaNumero;
  final int doorNumber;
  final String? fechaBarrera;
  final String tipoMov;
  final String? contenedor;
  final String? buqueDisv;
  final String? bookingDisv;
  final String? clienteDisv;
  final String? productoDisv;
  final String? tipoCarga;
  final String? cargaIMO;
  final String? refrigeradoDisv;
  final int? pesoCenso;
  final String? fotoConductor;
  final String? usuarioNombre;
  final String? emailJefe;
  final String? ip;

  const ExpMuelleInicializarRequest({
    required this.placa,
    required this.cedula,
    this.nombreConductor,
    required this.vehicleAccessId,
    required this.tpg,
    this.garitaLetra,
    this.garitaNumero,
    required this.doorNumber,
    this.fechaBarrera,
    this.tipoMov = 'EXP',
    this.contenedor,
    this.buqueDisv,
    this.bookingDisv,
    this.clienteDisv,
    this.productoDisv,
    this.tipoCarga,
    this.cargaIMO,
    this.refrigeradoDisv,
    this.pesoCenso,
    this.fotoConductor,
    this.usuarioNombre,
    this.emailJefe,
    this.ip,
  });

  Map<String, dynamic> toJson() => {
        'placa': placa,
        'cedula': cedula,
        if (nombreConductor != null) 'nombreConductor': nombreConductor,
        'vehicleAccessId': vehicleAccessId,
        'tpg': tpg,
        if (garitaLetra != null) 'garitaLetra': garitaLetra,
        if (garitaNumero != null) 'garitaNumero': garitaNumero,
        'doorNumber': doorNumber,
        if (fechaBarrera != null) 'fechaBarrera': fechaBarrera,
        'tipoMov': tipoMov,
        if (contenedor != null) 'contenedor': contenedor,
        if (buqueDisv != null) 'buqueDisv': buqueDisv,
        if (bookingDisv != null) 'bookingDisv': bookingDisv,
        if (clienteDisv != null) 'clienteDisv': clienteDisv,
        if (productoDisv != null) 'productoDisv': productoDisv,
        if (tipoCarga != null) 'tipoCarga': tipoCarga,
        if (cargaIMO != null) 'cargaIMO': cargaIMO,
        if (refrigeradoDisv != null) 'refrigeradoDisv': refrigeradoDisv,
        if (pesoCenso != null) 'pesoCenso': pesoCenso,
        if (fotoConductor != null) 'fotoConductor': fotoConductor,
        if (usuarioNombre != null) 'usuarioNombre': usuarioNombre,
        if (emailJefe != null) 'emailJefe': emailJefe,
        if (ip != null) 'ip': ip,
      };
}

class ExpMuelleInicializarDisv {
  final String? cliente;
  final String? producto;
  final String? tipoCarga;
  final String? cargaIMO;
  final String? refrigerado;
  final String? booking;
  final String? buque;

  const ExpMuelleInicializarDisv({
    this.cliente,
    this.producto,
    this.tipoCarga,
    this.cargaIMO,
    this.refrigerado,
    this.booking,
    this.buque,
  });

  factory ExpMuelleInicializarDisv.fromJson(Map<String, dynamic> json) {
    return ExpMuelleInicializarDisv(
      cliente: _H.toStr(json['cliente']),
      producto: _H.toStr(json['producto']),
      tipoCarga: _H.toStr(json['tipoCarga']),
      cargaIMO: _H.toStr(json['cargaIMO']),
      refrigerado: _H.toStr(json['refrigerado']),
      booking: _H.toStr(json['booking']),
      buque: _H.toStr(json['buque']),
    );
  }

  Map<String, dynamic> toJson() => {
        'cliente': cliente,
        'producto': producto,
        'tipoCarga': tipoCarga,
        'cargaIMO': cargaIMO,
        'refrigerado': refrigerado,
        'booking': booking,
        'buque': buque,
      };
}

class ExpMuelleInicializarData {
  final int? numtrans;
  final String? estado;
  final double? tara;
  final String? pesoIngreso;
  final String? contenedor;
  final List<String> sellos;
  final ExpMuelleInicializarDisv? disv;
  final bool panelSalidaVisible;

  const ExpMuelleInicializarData({
    this.numtrans,
    this.estado,
    this.tara,
    this.pesoIngreso,
    this.contenedor,
    this.sellos = const [],
    this.disv,
    this.panelSalidaVisible = false,
  });

  /// true si es transacción de SALIDA (tara > 0)
  bool get isSalida => (tara ?? 0) > 0;

  /// true si es transacción de ENTRADA
  bool get isEntrada => !isSalida;

  factory ExpMuelleInicializarData.fromJson(Map<String, dynamic> json) {
    final rawSellos = json['sellos'] as List? ?? [];
    final sellos = rawSellos
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return ExpMuelleInicializarData(
      numtrans: _H.toInt(json['numtrans']),
      estado: _H.toStr(json['estado']),
      tara: _H.toDbl(json['tara']),
      pesoIngreso: _H.toStr(json['pesoIngreso']),
      contenedor: _H.toStr(json['contenedor']),
      sellos: sellos,
      disv: json['disv'] != null
          ? ExpMuelleInicializarDisv.fromJson(
              json['disv'] as Map<String, dynamic>)
          : null,
      panelSalidaVisible: json['panelSalidaVisible'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'numtrans': numtrans,
        'estado': estado,
        'tara': tara,
        'pesoIngreso': pesoIngreso,
        'contenedor': contenedor,
        'sellos': sellos,
        'disv': disv?.toJson(),
        'panelSalidaVisible': panelSalidaVisible,
      };
}

class ExpMuelleInicializarResponse {
  final int errorCode;
  final String message;
  final ExpMuelleInicializarData? data;

  const ExpMuelleInicializarResponse({
    required this.errorCode,
    required this.message,
    this.data,
  });

  bool get isOk => errorCode == 0;

  factory ExpMuelleInicializarResponse.fromJson(Map<String, dynamic> json) {
    return ExpMuelleInicializarResponse(
      errorCode: _H.toInt(json['errorCode']) ?? 1,
      message: _H.toStr(json['message']) ?? '',
      data: json['data'] != null
          ? ExpMuelleInicializarData.fromJson(
              json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VALIDAR CONTENEDOR
// ─────────────────────────────────────────────────────────────────────────────

class ExpMuelleValidarContenedorRequest {
  final String contenedor;
  final String? placa;
  final String? cedula;
  final int? vehicleAccessId;

  const ExpMuelleValidarContenedorRequest({
    required this.contenedor,
    this.placa,
    this.cedula,
    this.vehicleAccessId,
  });

  Map<String, dynamic> toJson() => {
        'contenedor': contenedor,
        if (placa != null) 'placa': placa,
        if (cedula != null) 'cedula': cedula,
        if (vehicleAccessId != null) 'vehicleAccessId': vehicleAccessId,
      };
}

class ExpMuelleValidarContenedorData {
  final bool esValido;
  final String? contenedorValidado;
  final String? mensajeError;

  const ExpMuelleValidarContenedorData({
    required this.esValido,
    this.contenedorValidado,
    this.mensajeError,
  });

  factory ExpMuelleValidarContenedorData.fromJson(Map<String, dynamic> json) {
    return ExpMuelleValidarContenedorData(
      esValido: json['esValido'] as bool? ?? false,
      contenedorValidado: _H.toStr(json['contenedorValidado']),
      mensajeError: _H.toStr(json['mensajeError']),
    );
  }
}

class ExpMuelleValidarContenedorResponse {
  final int errorCode;
  final String message;
  final ExpMuelleValidarContenedorData? data;

  const ExpMuelleValidarContenedorResponse({
    required this.errorCode,
    required this.message,
    this.data,
  });

  bool get isOk => errorCode == 0 && (data?.esValido ?? false);

  factory ExpMuelleValidarContenedorResponse.fromJson(
      Map<String, dynamic> json) {
    return ExpMuelleValidarContenedorResponse(
      errorCode: _H.toInt(json['errorCode']) ?? 1,
      message: _H.toStr(json['message']) ?? '',
      data: json['data'] != null
          ? ExpMuelleValidarContenedorData.fromJson(
              json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GUARDAR
// ─────────────────────────────────────────────────────────────────────────────

class ExpMuelleGuardarRequest {
  final String placa;
  final String cedula;
  final String? nombreConductor;
  final int vehicleAccessId;
  final int tpg;
  final String? garitaLetra;
  final int? garitaNumero;
  final int doorNumber;
  final String? fechaBarrera;
  final String tipoMov;
  final String contenedor;
  final String? contenedorDisv;
  final String? booking;
  final double tara;
  final double pesoIngreso;
  final double? pesoSalida;
  final String? sello1;
  final String? sello2;
  final String? sello3;
  final String? sello4;
  final String? sello5;
  final String tipoTran;
  final int? numTrans;
  final String? deviceId;
  final String inOut;
  final int estadoVal;
  final String? huellaJefe;
  final int garitaOut;
  final String? observaciones;
  final double pesoBulto;
  final String? ip;
  final int? idTraslados;
  final double? pesoContenedor;
  final int? aniodisv;
  final int? numdisv;

  const ExpMuelleGuardarRequest({
    required this.placa,
    required this.cedula,
    this.nombreConductor,
    required this.vehicleAccessId,
    required this.tpg,
    this.garitaLetra,
    this.garitaNumero,
    required this.doorNumber,
    this.fechaBarrera,
    this.tipoMov = 'EXP',
    required this.contenedor,
    this.contenedorDisv,
    this.booking,
    required this.tara,
    required this.pesoIngreso,
    this.pesoSalida,
    this.sello1,
    this.sello2,
    this.sello3,
    this.sello4,
    this.sello5,
    this.tipoTran = 'I',
    this.numTrans,
    this.deviceId,
    this.inOut = 'I',
    this.estadoVal = 1,
    this.huellaJefe,
    this.garitaOut = 2,
    this.observaciones,
    this.pesoBulto = 0,
    this.ip,
    this.idTraslados,
    this.pesoContenedor,
    this.aniodisv,
    this.numdisv,
  });

  Map<String, dynamic> toJson() => {
        'placa': placa,
        'cedula': cedula,
        if (nombreConductor != null) 'nombreConductor': nombreConductor,
        'vehicleAccessId': vehicleAccessId,
        'tpg': tpg,
        if (garitaLetra != null) 'garitaLetra': garitaLetra,
        if (garitaNumero != null) 'garitaNumero': garitaNumero,
        'doorNumber': doorNumber,
        if (fechaBarrera != null) 'fechaBarrera': fechaBarrera,
        'tipoMov': tipoMov,
        'contenedor': contenedor,
        if (contenedorDisv != null) 'contenedorDisv': contenedorDisv,
        if (booking != null) 'booking': booking,
        'tara': tara,
        'pesoIngreso': pesoIngreso,
        'pesoSalida': pesoSalida,
        if (sello1 != null) 'sello1': sello1,
        if (sello2 != null) 'sello2': sello2,
        if (sello3 != null) 'sello3': sello3,
        if (sello4 != null) 'sello4': sello4,
        if (sello5 != null) 'sello5': sello5,
        'tipoTran': tipoTran,
        'codProducto': 'P01',
        'codTipoCarga': 'T01',
        'codBuque': 'B01',
        if (numTrans != null) 'numTrans': numTrans,
        if (deviceId != null) 'deviceId': deviceId,
        'inOut': inOut,
        'procesoCompleto': 'N',
        'estadoVal': estadoVal,
        if (huellaJefe != null) 'huellaJefe': huellaJefe,
        'garitaOut': garitaOut,
        if (observaciones != null) 'observaciones': observaciones,
        'pesoBulto': pesoBulto,
        if (ip != null) 'ip': ip,
        if (idTraslados != null) 'idTraslados': idTraslados,
        if (pesoContenedor != null) 'pesoContenedor': pesoContenedor,
        if (aniodisv != null) 'aniodisv': aniodisv,
        if (numdisv != null) 'numdisv': numdisv,
      };
}

class ExpMuelleGuardarData {
  final int? numero;
  final bool contenedorValidadoDisv;
  final bool enListaNegra;
  final Map<String, dynamic>? listaNegra;

  const ExpMuelleGuardarData({
    this.numero,
    this.contenedorValidadoDisv = false,
    this.enListaNegra = false,
    this.listaNegra,
  });

  factory ExpMuelleGuardarData.fromJson(Map<String, dynamic> json) {
    return ExpMuelleGuardarData(
      numero: _H.toInt(json['numero']),
      contenedorValidadoDisv: json['contenedorValidadoDisv'] as bool? ?? false,
      enListaNegra: json['enListaNegra'] as bool? ?? false,
      listaNegra: json['listaNegra'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'numero': numero,
        'contenedorValidadoDisv': contenedorValidadoDisv,
        'enListaNegra': enListaNegra,
        'listaNegra': listaNegra,
      };
}

class ExpMuelleGuardarResponse {
  final int errorCode;
  final String message;
  final ExpMuelleGuardarData? data;

  const ExpMuelleGuardarResponse({
    required this.errorCode,
    required this.message,
    this.data,
  });

  bool get isOk => errorCode == 0;

  factory ExpMuelleGuardarResponse.fromJson(Map<String, dynamic> json) {
    return ExpMuelleGuardarResponse(
      errorCode: _H.toInt(json['errorCode']) ?? 1,
      message: _H.toStr(json['message']) ?? '',
      data: json['data'] != null
          ? ExpMuelleGuardarData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TERMINAR
// ─────────────────────────────────────────────────────────────────────────────

class ExpMuelleTerminarRequest {
  final String placa;
  final int? vehicleAccessId;
  final bool btnGuardarEnabled;
  final bool? btnCancelarEnabled;
  final int ver;
  final int imprimir;
  final double? pesoSalida;
  final double? pesoIngreso;
  final double? tara;
  final String? contenedor;
  final String? booking;
  final String? cedula;
  final String? nombreConductor;
  final String? cargaIMO;
  final String? garitaLetra;
  final int? garitaNumero;
  final String? usuarioNombre;
  final String? emailJefe;
  final String? ip;
  final int? tpg;
  final int doorNumber;
  final String? tipoMov;
  final String? fechaBarrera;
  final String? bodegueroUser;

  const ExpMuelleTerminarRequest({
    required this.placa,
    this.vehicleAccessId,
    this.btnGuardarEnabled = false,
    this.btnCancelarEnabled = true,
    this.ver = 0,
    this.imprimir = 1,
    this.pesoSalida,
    this.pesoIngreso,
    this.tara,
    this.contenedor,
    this.booking,
    this.cedula,
    this.nombreConductor,
    this.cargaIMO,
    this.garitaLetra,
    this.garitaNumero,
    this.usuarioNombre,
    this.emailJefe,
    this.ip,
    this.tpg,
    this.doorNumber = 1,
    this.tipoMov = 'EXP',
    this.fechaBarrera,
    this.bodegueroUser,
  });

  Map<String, dynamic> toJson() => {
        'placa': placa,
        if (vehicleAccessId != null) 'vehicleAccessId': vehicleAccessId,
        'btnGuardarEnabled': btnGuardarEnabled,
        if (btnCancelarEnabled != null) 'btnCancelarEnabled': btnCancelarEnabled,
        'ver': ver,
        'imprimir': imprimir,
        'pesoSalida': pesoSalida,
        if (pesoIngreso != null) 'pesoIngreso': pesoIngreso,
        if (tara != null) 'tara': tara,
        if (contenedor != null) 'contenedor': contenedor,
        if (booking != null) 'booking': booking,
        if (cedula != null) 'cedula': cedula,
        if (nombreConductor != null) 'nombreConductor': nombreConductor,
        if (cargaIMO != null) 'cargaIMO': cargaIMO,
        if (garitaLetra != null) 'garitaLetra': garitaLetra,
        if (garitaNumero != null) 'garitaNumero': garitaNumero,
        if (usuarioNombre != null) 'usuarioNombre': usuarioNombre,
        if (emailJefe != null) 'emailJefe': emailJefe,
        if (ip != null) 'ip': ip,
        if (tpg != null) 'tpg': tpg,
        'doorNumber': doorNumber,
        if (tipoMov != null) 'tipoMov': tipoMov,
        if (fechaBarrera != null) 'fechaBarrera': fechaBarrera,
        if (bodegueroUser != null) 'bodegueroUser': bodegueroUser,
      };
}

class ExpMuelleTerminarData {
  final String? estado;

  const ExpMuelleTerminarData({this.estado});

  /// true si la transacción terminó con éxito (autorizada para salida o proyección)
  bool get isAutorizado =>
      estado == 'AUTORIZADO_SALIDA' || estado == 'AUTORIZADO_PROYECCION';

  /// true si el vehículo fue bloqueado por peso excedido
  bool get isBloqueado => estado == 'BLOQUEADO';

  factory ExpMuelleTerminarData.fromJson(Map<String, dynamic> json) {
    return ExpMuelleTerminarData(
      estado: _H.toStr(json['estado']),
    );
  }

  Map<String, dynamic> toJson() => {'estado': estado};
}

class ExpMuelleTerminarResponse {
  final int errorCode;
  final String message;
  final ExpMuelleTerminarData? data;

  const ExpMuelleTerminarResponse({
    required this.errorCode,
    required this.message,
    this.data,
  });

  bool get isOk => errorCode == 0;

  factory ExpMuelleTerminarResponse.fromJson(Map<String, dynamic> json) {
    return ExpMuelleTerminarResponse(
      errorCode: _H.toInt(json['errorCode']) ?? 1,
      message: _H.toStr(json['message']) ?? '',
      data: json['data'] != null
          ? ExpMuelleTerminarData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
    );
  }
}