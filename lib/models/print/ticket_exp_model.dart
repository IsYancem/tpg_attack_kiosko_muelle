// lib/models/print/ticket_exp_model.dart
// Autor: Abraham Yance
// Fecha: 2025-12-10
// Descripción: Modelo de datos para ticket de Exportación Full

class TicketExpModel {
  final int atkId;
  final String placa;
  final String contenedor;
  final String clienteExportador;
  final String producto;
  final String booking;
  final String nave;
  final String sello1;
  final String sello2;
  final String sello3;
  final String sello4;
  final String pesoIngreso;
  final String tara;
  final String tipoCarga;
  final String cargaIMO;
  final String refrigerado;
  final String entrada;
  final String choferNombre;
  final String choferCedula;

  TicketExpModel({
    required this.atkId,
    required this.placa,
    required this.contenedor,
    required this.clienteExportador,
    required this.producto,
    required this.booking,
    required this.nave,
    required this.sello1,
    required this.sello2,
    required this.sello3,
    required this.sello4,
    required this.pesoIngreso,
    required this.tara,
    required this.tipoCarga,
    required this.cargaIMO,
    required this.refrigerado,
    required this.entrada,
    required this.choferNombre,
    required this.choferCedula,
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
      'sello1': sello1,
      'sello2': sello2,
      'sello3': sello3,
      'sello4': sello4,
      'pesoIngreso': pesoIngreso,
      'tara': tara,
      'tipoCarga': tipoCarga,
      'cargaIMO': cargaIMO,
      'refrigerado': refrigerado,
      'entrada': entrada,
      'choferNombre': choferNombre,
      'choferCedula': choferCedula,
    };
  }
}

// lib/models/print/ticket_ruta_model.dart
class TicketRutaModel {
  final String placa;
  final String contenedor;
  final String ubicacion;
  final String bloque;
  final String bahia;
  final String entrada;
  final String danios;
  final String? mapaUrl;

  TicketRutaModel({
    required this.placa,
    required this.contenedor,
    required this.ubicacion,
    required this.bloque,
    required this.bahia,
    required this.entrada,
    required this.danios,
    this.mapaUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'placa': placa,
      'contenedor': contenedor,
      'ubicacion': ubicacion,
      'bloque': bloque,
      'bahia': bahia,
      'entrada': entrada,
      'danios': danios,
      'mapaUrl': mapaUrl,
    };
  }
}
