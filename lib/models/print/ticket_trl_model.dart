// lib/models/print/ticket_trl_model.dart
// Autor: Abraham Yance
// Fecha: 2025-12-05
// Descripción: Modelo para ticket de impresión TRL (Traslado)

class TicketTrlModel {
  final int? atkId;
  final String placa;
  final String entrada;
  final String origen;
  final String destino;
  final String peso;
  final String? gate;
  final int? numTranBascula;

  // Contenedor 1
  final String contenedor1;
  final int? anioOperacion1;
  final int? corOperacion1;
  final String? detalle1;

  // Contenedor 2 (opcional)
  final String? contenedor2;
  final int? anioOperacion2;
  final int? corOperacion2;
  final String? detalle2;

  // Chofer
  final String apellidos;
  final String nombres;

  TicketTrlModel({
    this.atkId,
    required this.placa,
    required this.entrada,
    required this.origen,
    required this.destino,
    required this.peso,
    this.gate,
    this.numTranBascula,
    required this.contenedor1,
    this.anioOperacion1,
    this.corOperacion1,
    this.detalle1,
    this.contenedor2,
    this.anioOperacion2,
    this.corOperacion2,
    this.detalle2,
    required this.apellidos,
    required this.nombres,
  });

  /// Indica si hay un segundo contenedor
  bool get hasCont2 => contenedor2 != null && contenedor2!.isNotEmpty;

  /// Operación completa contenedor 1
  String get operacion1 {
    if (anioOperacion1 != null && corOperacion1 != null) {
      return '$anioOperacion1-$corOperacion1';
    }
    return '';
  }

  /// Operación completa contenedor 2
  String get operacion2 {
    if (anioOperacion2 != null && corOperacion2 != null) {
      return '$anioOperacion2-$corOperacion2';
    }
    return '';
  }

  /// Nombre completo del chofer
  String get choferNombreCompleto => '$apellidos $nombres'.trim();

  Map<String, dynamic> toJson() => {
    'tipo': 'TRL',
    'atk_id': atkId,
    'placa': placa,
    'entrada': entrada,
    'origen': origen,
    'destino': destino,
    'peso': peso,
    'gate': gate,
    'num_tran_bascula': numTranBascula,
    'contenedor1': contenedor1,
    'anio_operacion1': anioOperacion1,
    'cor_operacion1': corOperacion1,
    'detalle1': detalle1,
    'contenedor2': contenedor2,
    'anio_operacion2': anioOperacion2,
    'cor_operacion2': corOperacion2,
    'detalle2': detalle2,
    'apellidos': apellidos,
    'nombres': nombres,
  };

  factory TicketTrlModel.fromJson(Map<String, dynamic> json) {
    return TicketTrlModel(
      atkId: json['atk_id'] as int?,
      placa: json['placa'] as String? ?? '',
      entrada: json['entrada'] as String? ?? '',
      origen: json['origen'] as String? ?? '',
      destino: json['destino'] as String? ?? '',
      peso: json['peso'] as String? ?? '',
      gate: json['gate'] as String?,
      numTranBascula: json['num_tran_bascula'] as int?,
      contenedor1: json['contenedor1'] as String? ?? '',
      anioOperacion1: json['anio_operacion1'] as int?,
      corOperacion1: json['cor_operacion1'] as int?,
      detalle1: json['detalle1'] as String?,
      contenedor2: json['contenedor2'] as String?,
      anioOperacion2: json['anio_operacion2'] as int?,
      corOperacion2: json['cor_operacion2'] as int?,
      detalle2: json['detalle2'] as String?,
      apellidos: json['apellidos'] as String? ?? '',
      nombres: json['nombres'] as String? ?? '',
    );
  }
}
