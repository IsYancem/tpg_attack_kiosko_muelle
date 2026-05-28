class DspTransaccionRequestModel {
  final String ruc_tpg;
  final String placa;
  final int vehicleAccessId;
  final String codchofer;
  final String numregAtk;
  final double peso;
  final int gate;
  final String? deviceId;
  final String codEmpresa;
  final String codEmpresaF;
  final String? cedulaChofer;
  final int numt;
  final String now;
  final String? patio;
  final String? monitorHost;
  final int? monitorPort;

  // opcionales válidos según backend
  final String? codProducto;
  final String? codBuque;
  final int? bascula;
  final int? doorNumber;
  final int? doorOut;

  DspTransaccionRequestModel({
    required this.ruc_tpg,
    required this.placa,
    required this.vehicleAccessId,
    required this.codchofer,
    required this.numregAtk,
    required this.peso,
    required this.gate,
    required this.deviceId,
    required this.codEmpresa,
    required this.codEmpresaF,
    required this.cedulaChofer,
    required this.numt,
    required this.now,
    required this.patio,
    this.codProducto,
    this.codBuque,
    this.bascula,
    this.doorNumber,
    this.doorOut,
    this.monitorHost,
    this.monitorPort,
  });

  Map<String, dynamic> toJson() => {
    'ruc_tpg': ruc_tpg,
    'placa': placa,
    'vehicle_access_id': vehicleAccessId,
    'codchofer': codchofer,
    'numreg_atk': numregAtk,
    'peso': peso,
    'gate': gate,
    'device_id': deviceId,
    'codEmpresa': codEmpresa,
    'codEmpresaF': codEmpresaF,
    'cedula_chofer': cedulaChofer,
    'NUMT': numt,
    'now': now,
    'patio': patio,
    'monitorHost': monitorHost,
    'monitorPort': monitorPort,

    // 👉 OPCIONALES PERMITIDOS POR EL BACKEND
    if (codProducto != null) 'codProducto': codProducto,
    if (codBuque != null) 'codBuque': codBuque,
    if (bascula != null) 'bascula': bascula,
    if (doorNumber != null) 'door_number': doorNumber,
    if (doorOut != null) 'door_out': doorOut,
  };
}
