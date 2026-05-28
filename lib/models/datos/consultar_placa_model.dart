// Autor: Abraham Yance
// Fecha: 2025-11-14
// Propósito: Modelos para el servicio POST /muelle/api/datos/consultar-placa

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

class ConsultarPlacaRequest {
  final int? garitaNumero;
  final String? garitaLetra;
  final int? tpg;
  final String? usuarioNombre;
  final String? placa;
  final int? permisoMuelle;

  ConsultarPlacaRequest({
    this.garitaNumero,
    this.garitaLetra,
    this.tpg,
    this.usuarioNombre,
    this.placa,
    this.permisoMuelle,
  });

  Map<String, dynamic> toJson() => {
    'garitaNumero': garitaNumero,
    'garitaLetra': garitaLetra,
    'tpg': tpg,
    'usuarioNombre': usuarioNombre,
    'placa': placa,
    'permisoMuelle': permisoMuelle,
  };
}

class ConsultarPlacaMovimiento {
  final int movid;
  final String? transaccion;
  final int? choferId;
  final String? conductorRuc;
  final String? tipoMov;
  final String? cargaSuelta;
  final int? anioMovId;
  final String? placa;
  final int? id;
  final int? mensaje;
  final int? autorizado;

  final Map<String, dynamic>? raw;

  ConsultarPlacaMovimiento({
    required this.movid,
    this.transaccion,
    this.choferId,
    this.conductorRuc,
    this.tipoMov,
    this.cargaSuelta,
    this.anioMovId,
    this.placa,
    this.id,
    this.mensaje,
    this.autorizado,
    this.raw, // ✅
  });

  factory ConsultarPlacaMovimiento.fromJson(Map<String, dynamic> j) =>
      ConsultarPlacaMovimiento(
        movid: _toInt(j['movid']) ?? 0,
        transaccion: j['transaccion']?.toString(),
        choferId: _toInt(j['chofer_id']),
        conductorRuc: j['conductor_ruc']?.toString(),
        tipoMov: j['tipo_mov']?.toString(),
        cargaSuelta: j['carga_suelta']?.toString(),
        anioMovId: _toInt(j['anio_mov_id']),
        placa: j['placa']?.toString(),
        id: _toInt(j['id']),
        mensaje: _toInt(j['mensaje']),
        autorizado: _toInt(j['autorizado']),

        raw: (j['raw'] is Map)
            ? (j['raw'] as Map).cast<String, dynamic>()
            : null,
      );

  Map<String, dynamic> toJson() => {
    'movid': movid,
    'transaccion': transaccion,
    'chofer_id': choferId,
    'conductor_ruc': conductorRuc,
    'tipo_mov': tipoMov,
    'carga_suelta': cargaSuelta,
    'anio_mov_id': anioMovId,
    'placa': placa,
    'id': id,
    'mensaje': mensaje,
    'autorizado': autorizado,
    'raw': raw, // ✅
  };

  Map<String, dynamic> get rawOrSelf => raw ?? toJson();
}

class ConsultarPlacaRow {
  final String? placa;
  final int? doorNumber;
  final String? fechaBarrera;
  final String? brand;
  final String? model;
  final String? color;
  final double? companyId;
  final String? basculaModo;
  final List<ConsultarPlacaMovimiento> movements;
  final Map<String, dynamic>? monitor;
  final Map<String, dynamic>? uiHints;

  final Map<String, dynamic>? services;

  ConsultarPlacaRow({
    this.placa,
    this.doorNumber,
    this.fechaBarrera,
    this.brand,
    this.model,
    this.color,
    this.companyId,
    this.basculaModo,
    required this.movements,
    this.monitor,
    this.uiHints,

    this.services,
  });

  factory ConsultarPlacaRow.fromJson(Map<String, dynamic> j) =>
      ConsultarPlacaRow(
        placa: j['placa']?.toString(),
        doorNumber: _toInt(j['door_number']),
        fechaBarrera: j['fechaBarrera']?.toString(),
        brand: j['brand']?.toString(),
        model: j['model']?.toString(),
        color: j['color']?.toString(),
        companyId: _toDouble(j['companyid']),
        basculaModo: j['basculaModo']?.toString(),
        movements: (j['movements'] as List? ?? [])
            .whereType<Map>()
            .map(
              (e) => ConsultarPlacaMovimiento.fromJson(
                (e).cast<String, dynamic>(),
              ),
            )
            .toList(),
        monitor: (j['monitor'] as Map?)?.cast<String, dynamic>(),
        uiHints: (j['uiHints'] as Map?)?.cast<String, dynamic>(),

        services: (j['services'] as Map?)?.cast<String, dynamic>(),
      );

  Map<String, dynamic> toJson() => {
    'placa': placa,
    'door_number': doorNumber,
    'fechaBarrera': fechaBarrera,
    'brand': brand,
    'model': model,
    'color': color,
    'companyid': companyId,
    'basculaModo': basculaModo,
    'movements': movements.map((e) => e.toJson()).toList(),
    'monitor': monitor,
    'uiHints': uiHints,

    'services': services,
  };
}
