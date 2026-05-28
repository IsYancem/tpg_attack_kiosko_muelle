// lib/models/print/ticket_res_model.dart
// Autor: Abraham Yance
// Fecha: 2025-12-30
// Modelo de ticket RES (basado en comprobante C# GeneraComprobanteRES)

import 'package:intl/intl.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';

class TicketResModel {
  // Identificadores
  final int atkId; // vehicle_access_id (fallback)
  final int? numeroComprobante; // numTran (C#)
  final String placa;
  final String? contenedor;

  // Chofer
  final String choferNombre;
  final String choferCedula;

  // Fechas
  final String? fechaHoraIng;
  final String? fechaHoraSal;
  final String? fechaEmisionDocumento;

  // Pesos
  final String? pesoIng;
  final String? pesoSal;
  final String? taraContenedor;
  final String? pesoNeto; // (pesosal - pesoing - tara)
  final String? pesoNetoMasTara; // (pesosal - pesoing)

  // Carga / producto
  final String? producto;
  final String? tipoCarga;
  final String? estado;

  // Usuarios
  final String? usuario; // usuario inicial (bascula ingreso)
  final String? usuarioFinal; // usuario final (bascula salida)
  final String? nombreUsuario; // usuario logueado (C_sp_varios.usuario_nombre)

  // Otros
  final String? observaciones;

  TicketResModel({
    required this.atkId,
    required this.placa,
    required this.choferNombre,
    required this.choferCedula,
    this.numeroComprobante,
    this.contenedor,
    this.fechaHoraIng,
    this.fechaHoraSal,
    this.fechaEmisionDocumento,
    this.pesoIng,
    this.pesoSal,
    this.taraContenedor,
    this.pesoNeto,
    this.pesoNetoMasTara,
    this.producto,
    this.tipoCarga,
    this.estado,
    this.usuario,
    this.usuarioFinal,
    this.nombreUsuario,
    this.observaciones,
  });

  Map<String, dynamic> toJson() => {
    'atkId': atkId,
    'numeroComprobante': numeroComprobante,
    'placa': placa,
    'contenedor': contenedor,
    'choferNombre': choferNombre,
    'choferCedula': choferCedula,
    'fechaHoraIng': fechaHoraIng,
    'fechaHoraSal': fechaHoraSal,
    'fechaEmisionDocumento': fechaEmisionDocumento,
    'pesoIng': pesoIng,
    'pesoSal': pesoSal,
    'taraContenedor': taraContenedor,
    'pesoNeto': pesoNeto,
    'pesoNetoMasTara': pesoNetoMasTara,
    'producto': producto,
    'tipoCarga': tipoCarga,
    'estado': estado,
    'usuario': usuario,
    'usuarioFinal': usuarioFinal,
    'nombreUsuario': nombreUsuario,
    'observaciones': observaciones,
  };

  // lib/models/print/ticket_res_model.dart

  factory TicketResModel.fromManager(AtkTransactionManager m) {
    // helpers
    String? s(dynamic v) {
      final out = v?.toString().trim();
      return (out == null || out.isEmpty) ? null : out;
    }

    int? i(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString().trim());
    }

    double? d(dynamic v) {
      if (v == null) return null;
      if (v is double) return v;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString().trim());
    }

    String fmtNum(double? n) {
      if (n == null) return '0';
      final f = NumberFormat('###0', 'es_EC');
      return f.format(n);
    }

    // ✅ PRIORIDAD 1: Leer desde RES_printable (datos completos del backend)
    final printableRaw = m.data['RES_printable'];
    final printable = printableRaw is Map
        ? printableRaw.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    // ✅ Si hay printable, usarlo; si no, usar campos del manager
    if (printable.isNotEmpty) {
      final pesoIngN = d(printable['peso_ingreso']);
      final pesoSalN = d(printable['peso_salida']);
      final taraN = d(printable['tara_contenedor']);
      final pesoNetoN = d(printable['peso_neto']);
      final pesoNetoMasTaraN = d(printable['peso_neto_mas_tara']);

      return TicketResModel(
        atkId: i(m.get('atkId')) ?? 0,
        numeroComprobante: i(printable['numero_comprobante']),
        placa: s(printable['placa']) ?? '',
        contenedor: s(printable['contenedor']),
        choferNombre: s(m.get('driverName')) ?? '',
        choferCedula: s(printable['chofer']) ?? '',

        fechaHoraIng: s(printable['fecha_hora_ing']),
        fechaHoraSal: s(printable['fecha_hora_sal']),
        fechaEmisionDocumento:
            s(printable['fecha_emision_documento']) ??
            DateTime.now().toString(),

        pesoIng: fmtNum(pesoIngN),
        pesoSal: fmtNum(pesoSalN),
        taraContenedor: fmtNum(taraN),
        pesoNeto: fmtNum(pesoNetoN),
        pesoNetoMasTara: fmtNum(pesoNetoMasTaraN),

        producto: s(printable['producto']),
        tipoCarga: s(printable['tipo_carga']),
        estado: null,

        usuario: s(printable['usuario_inicial']),
        usuarioFinal: s(printable['usuario_final']),
        nombreUsuario: s(printable['nombre_usuario']) ?? 'KIOSK',
        observaciones: s(m.get('vehiculoObservaciones')),
      );
    }

    // ✅ Fallback: si no hay printable, usar campos del manager
    final atkId = i(m.get('atkId')) ?? 0;
    final placa = s(m.get('vehiculoPlaca')) ?? '';
    final contenedor = s(m.get('contenedor'));
    final choferNombre = s(m.get('driverName')) ?? '';
    final choferCedula = s(m.get('driverCedula')) ?? '';
    final numeroComprobante = i(m.get('numTrans'));

    final pesoIngN = d(m.get('pesoIngreso'));
    final pesoSalN = d(m.get('pesoSalida'));
    final taraN = d(m.get('pesoTara'));

    final pesoNetoCalc = (pesoSalN ?? 0) - (pesoIngN ?? 0) - (taraN ?? 0);
    final pesoNetoMasTaraCalc = (pesoSalN ?? 0) - (pesoIngN ?? 0);

    return TicketResModel(
      atkId: atkId,
      numeroComprobante: numeroComprobante,
      placa: placa,
      contenedor: contenedor,
      choferNombre: choferNombre,
      choferCedula: choferCedula,

      fechaHoraIng: null,
      fechaHoraSal: null,
      fechaEmisionDocumento: DateTime.now().toString(),

      pesoIng: fmtNum(pesoIngN),
      pesoSal: fmtNum(pesoSalN),
      taraContenedor: fmtNum(taraN),
      pesoNeto: fmtNum(pesoNetoCalc),
      pesoNetoMasTara: fmtNum(pesoNetoMasTaraCalc),

      producto: s(m.get('vehiculoProducto')),
      tipoCarga: s(m.get('vehiculoTipoCarga')),
      estado: null,

      usuario: null,
      usuarioFinal: null,
      nombreUsuario: 'KIOSK',
      observaciones: s(m.get('vehiculoObservaciones')),
    );
  }
}
