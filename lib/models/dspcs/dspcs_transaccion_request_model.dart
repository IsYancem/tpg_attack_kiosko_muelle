// lib/models/dspcs/dspcs_transaccion_request_model.dart
// Autor: Abraham Yance
// Fecha: 2025-12-04
// Descripción: Modelo de request para transacción DSP-CS (Despacho Carga Suelta)

class DspCsTransaccionRequestModel {
  final String rucTpg;
  final String placa;
  final int vehicleAccessId;
  final String codchofer;
  final String numregAtk;
  final double peso;
  final int gate;
  final String? cedulaChofer;
  final String now;
  final String? patio;
  final String? monitorHost;
  final int? monitorPort;

  DspCsTransaccionRequestModel({
    required this.rucTpg,
    required this.placa,
    required this.vehicleAccessId,
    required this.codchofer,
    required this.numregAtk,
    required this.peso,
    required this.gate,
    this.cedulaChofer,
    required this.now,
    this.patio,
    this.monitorHost,
    this.monitorPort,
  });

  Map<String, dynamic> toJson() => {
    'ruc_tpg': rucTpg,
    'placa': placa,
    'vehicle_access_id': vehicleAccessId,
    'codchofer': codchofer,
    'numreg_atk': numregAtk,
    'peso': peso,
    'gate': gate,
    'cedula_chofer': cedulaChofer,
    'now': now,
    'patio': patio,
    'monitorHost': monitorHost,
    'monitorPort': monitorPort,
  };
}
