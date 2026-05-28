class ConsultarTransaccionRequest {
  final int? garitaNumero;
  final String? garitaLetra;
  final int? tpg;
  final String? usuarioNombre;
  final String? permisoMuelle;

  final String placa;
  final int doorNumber;
  final String? fecha_barrera;

  final String? brand;
  final String? model;
  final String? color;
  final double? companyId;

  ConsultarTransaccionRequest({
    required this.placa,
    required this.doorNumber,
    this.garitaNumero,
    this.garitaLetra,
    this.tpg,
    this.usuarioNombre,
    this.permisoMuelle,
    this.fecha_barrera,
    this.brand,
    this.model,
    this.color,
    this.companyId,
  });

  Map<String, dynamic> toJson() => {
    'garitaNumero': garitaNumero,
    'garitaLetra': garitaLetra,
    'tpg': tpg,
    'usuarioNombre': usuarioNombre,
    'permisoMuelle': permisoMuelle,

    'placa': placa,
    'door_number': doorNumber,
    'fecha_barrera': fecha_barrera,

    'brand': brand,
    'model': model,
    'color': color,
    'companyid': companyId,
  };
}