// Autor: Abraham Yance
// Fecha: 2025-11-09
// Modelo de solicitud al servicio facial del backend NestJS.

class FacialRequestModel {
  final String identification;
  final String numPlaca;
  final String estado;
  final String? kioskServer;
  final int? kioskPort;

  FacialRequestModel({
    required this.identification,
    required this.numPlaca,
    this.estado = 'P',
    this.kioskServer,
    this.kioskPort,
  });

  Map<String, dynamic> toJson() => {
    'identification': identification,
    'numPlaca': numPlaca,
    'ESTADO': estado,
    if (kioskServer != null) 'kioskServer': kioskServer,
    if (kioskPort != null) 'kioskPort': kioskPort,
  };
}
