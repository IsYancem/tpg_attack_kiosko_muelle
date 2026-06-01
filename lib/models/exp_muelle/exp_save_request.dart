// lib/models/exp_save_request.dart
class ExpSaveRequestDto {
  String placa;
  String cedula;
  String? nombreConductor;
  int vehicleAccessId;
  int tpg;
  String? garitaLetra;
  int? garitaNumero;
  int doorNumber;
  String? fechaBarrera;
  String? tipoMov;
  String contenedor;
  String? contenedorDisv;
  String? booking;
  double tara;
  double pesoIngreso;
  double? pesoSalida;
  String? sello1;
  String? sello2;
  String? sello3;
  String? sello4;
  String? tipoTran;
  String? codProducto;
  String? codTipoCarga;
  String? codBuque;
  int? numTrans;
  String? procesoCompleto;
  int? estadoVal;

  ExpSaveRequestDto({
    required this.placa,
    required this.cedula,
    this.nombreConductor,
    required this.vehicleAccessId,
    required this.tpg,
    this.garitaLetra,
    this.garitaNumero,
    required this.doorNumber,
    this.fechaBarrera,
    this.tipoMov,
    required this.contenedor,
    this.contenedorDisv,
    this.booking,
    required this.tara,
    required this.pesoIngreso,
    this.pesoSalida,
    this.sello1,
    this.sello2,
    this.sello3,
    this.sello4,
    this.tipoTran,
    this.codProducto,
    this.codTipoCarga,
    this.codBuque,
    this.numTrans,
    this.procesoCompleto,
    this.estadoVal,
  });

  Map<String, dynamic> toJson() => {
        'placa': placa,
        'cedula': cedula,
        'nombreConductor': nombreConductor,
        'vehicleAccessId': vehicleAccessId,
        'tpg': tpg,
        'garitaLetra': garitaLetra,
        'garitaNumero': garitaNumero,
        'doorNumber': doorNumber,
        'fechaBarrera': fechaBarrera,
        'tipoMov': tipoMov,
        'contenedor': contenedor,
        'contenedorDisv': contenedorDisv,
        'booking': booking,
        'tara': tara,
        'pesoIngreso': pesoIngreso,
        'pesoSalida': pesoSalida,
        'sello1': sello1,
        'sello2': sello2,
        'sello3': sello3,
        'sello4': sello4,
        'tipoTran': tipoTran,
        'codProducto': codProducto,
        'codTipoCarga': codTipoCarga,
        'codBuque': codBuque,
        'numTrans': numTrans,
        'procesoCompleto': procesoCompleto,
        'estadoVal': estadoVal,
      };
}