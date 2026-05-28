// lib/models/print/ticket_exm_model.dart
// Autor: Abraham Yance
// Fecha: 2025-12-28
// Descripción: Modelo de datos para ticket de Exportación Vacíos (EXM)

class TicketExmModel {
  final int atkId;
  final String placa;
  final String contenedor;
  final String clienteExportador;
  final String producto;
  final String booking;
  final String nave;
  // ? SIN SELLOS (contenedores vacíos)
  final String pesoIngreso;
  final String tara;
  final String tipoCarga;
  final String cargaIMO;
  final String refrigerado;
  final String entrada;
  final String choferNombre;
  final String choferCedula;
  // ? CAMPOS ESPECÍFICOS EXM
  final String? docTransporte; // documento de transporte DISV
  final String? observaciones;
  // Campos para ubicación (si aplica)
  final String? ubicacion;
  final String? bloque;
  final String? bahia;
  final String? danios;
  final String? mapaUrl;

  TicketExmModel({
    required this.atkId,
    required this.placa,
    required this.contenedor,
    required this.clienteExportador,
    required this.producto,
    required this.booking,
    required this.nave,
    required this.pesoIngreso,
    required this.tara,
    required this.tipoCarga,
    required this.cargaIMO,
    required this.refrigerado,
    required this.entrada,
    required this.choferNombre,
    required this.choferCedula,
    this.docTransporte,
    this.observaciones,
    this.ubicacion,
    this.bloque,
    this.bahia,
    this.danios,
    this.mapaUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'atkId': atkId,
      'placa': placa,
      'contenedor': contenedor,
      'clienteExportador': clienteExportador,
      'producto': producto,
      'booking': booking,
      'nave': nave,
      'pesoIngreso': pesoIngreso,
      'tara': tara,
      'tipoCarga': tipoCarga,
      'cargaIMO': cargaIMO,
      'refrigerado': refrigerado,
      'entrada': entrada,
      'choferNombre': choferNombre,
      'choferCedula': choferCedula,
      'docTransporte': docTransporte,
      'observaciones': observaciones,
      'ubicacion': ubicacion,
      'bloque': bloque,
      'bahia': bahia,
      'danios': danios,
      'mapaUrl': mapaUrl,
    };
  }

  factory TicketExmModel.fromJson(Map<String, dynamic> json) {
    return TicketExmModel(
      atkId: json['atkId'] as int,
      placa: json['placa'] as String,
      contenedor: json['contenedor'] as String,
      clienteExportador: json['clienteExportador'] as String,
      producto: json['producto'] as String,
      booking: json['booking'] as String,
      nave: json['nave'] as String,
      pesoIngreso: json['pesoIngreso'] as String,
      tara: json['tara'] as String,
      tipoCarga: json['tipoCarga'] as String,
      cargaIMO: json['cargaIMO'] as String,
      refrigerado: json['refrigerado'] as String,
      entrada: json['entrada'] as String,
      choferNombre: json['choferNombre'] as String,
      choferCedula: json['choferCedula'] as String,
      docTransporte: json['docTransporte'] as String?,
      observaciones: json['observaciones'] as String?,
      ubicacion: json['ubicacion'] as String?,
      bloque: json['bloque'] as String?,
      bahia: json['bahia'] as String?,
      danios: json['danios'] as String?,
      mapaUrl: json['mapaUrl'] as String?,
    );
  }
}
