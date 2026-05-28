// lib/models/trl/trl_transaccion_request_model.dart
// Autor: Abraham Yance
// Fecha: 2025-12-05
// Descripción: Modelo de request para transacción TRL (Traslado)
// 100% alineado con TrlTransaccionRequestDto (NestJS)

class TrlTransaccionRequestModel {
  final String placa;
  final String? cedula;
  final String? contenedor1;
  final String? contenedor2;
  final double peso;
  final int gate;
  final String? letra;
  final String? patio;
  final String? patioStr;
  final int atkId;
  final String now;
  final String usuario;
  final String kioskServer;
  final String kioskPort;

  TrlTransaccionRequestModel({
    required this.placa,
    required this.cedula,
    required this.contenedor1,
    required this.contenedor2,
    required this.peso,
    required this.gate,
    required this.letra,
    required this.patio,
    required this.patioStr,
    required this.atkId,
    required this.now,
    required this.usuario,
    required this.kioskServer,
    required this.kioskPort,
  });

  Map<String, dynamic> toJson() {
    // Normalizamos strings vacíos a null donde tiene sentido
    String? _normStr(String? v) =>
        (v != null && v.trim().isNotEmpty) ? v : null;

    return {
      'placa': placa,
      if (_normStr(cedula) != null) 'cedula': _normStr(cedula),
      if (_normStr(contenedor1) != null) 'contenedor1': _normStr(contenedor1),
      if (_normStr(contenedor2) != null) 'contenedor2': _normStr(contenedor2),

      'peso': peso,
      'gate': gate,

      if (_normStr(letra) != null) 'letra': _normStr(letra),
      if (_normStr(patio) != null) 'patio': _normStr(patio),
      if (_normStr(patioStr) != null) 'patioStr': _normStr(patioStr),

      // 👇 IMPORTANTE: este es el que tu Nest espera
      // Mi atk_id es mi vehicle_access_id
      'atk_id': atkId,

      'now': now,
      'usuario': usuario,
      'kioskServer': kioskServer,
      'kioskPort': kioskPort, // puede ir como number, Nest lo castea igual
    };
  }
}
