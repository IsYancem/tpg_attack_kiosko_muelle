import 'package:intl/intl.dart';

class TicketDspModel {
  final String turno;
  final String placa;
  final String? contenedor;
  final String dres;
  final String? ubicacion;
  final String bloque;
  final String programado;
  final String entrada;
  final String apellidos;
  final String nombres;
  final int atkId;
  final String choferIdentification;

  TicketDspModel({
    required this.turno,
    required this.placa,
    this.contenedor,
    required this.dres,
    this.ubicacion,
    required this.bloque,
    required this.programado,
    required this.entrada,
    required this.apellidos,
    required this.nombres,
    required this.atkId,
    required this.choferIdentification,
  });

  factory TicketDspModel.fromDspData({
    required String turno,
    required String placa,
    required String? contenedor,
    required int aniodres1,
    required int cordres1,
    required String? ubicacion,
    required String fechaProgramado,
    required String apellidos,
    required String nombres,
    required int atkId,
    required String choferIdentification,
  }) {
    // Construir DRES como en C#: (string)jTurno["aniodres1"] + "-" + (string)jTurno["cordres1"]
    final dres = '$aniodres1-$cordres1';

    // Obtener bloque como en C#: ((string)jTurno["ubicacion"]).Substring(3, 2)
    String bloque = '';
    if (ubicacion != null && ubicacion.length >= 5) {
      bloque = ubicacion.substring(3, 5);
    }

    // Fecha entrada como en C#: DateTime.Now.ToString("yyyy/MM/dd HH:mm")
    final entrada = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());

    return TicketDspModel(
      turno: turno,
      placa: placa,
      contenedor: contenedor ?? '',
      dres: dres,
      ubicacion: ubicacion ?? '',
      bloque: bloque,
      programado: fechaProgramado,
      entrada: entrada,
      apellidos: apellidos,
      nombres: nombres,
      atkId: atkId,
      choferIdentification: choferIdentification,
    );
  }

  Map<String, dynamic> toJson() => {
    'turno': turno,
    'placa': placa,
    'contenedor': contenedor,
    'dres': dres,
    'ubicacion': ubicacion,
    'bloque': bloque,
    'programado': programado,
    'entrada': entrada,
    'apellidos': apellidos,
    'nombres': nombres,
    'atk_id': atkId,
    'chofer_identification': choferIdentification,
  };
}
