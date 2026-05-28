import 'package:intl/intl.dart';

class TicketDspCsModel {
  final String turno;
  final String placa;
  final String programado;
  final String entrada;
  final String apellidos;
  final String nombres;
  final int atkId;

  TicketDspCsModel({
    required this.turno,
    required this.placa,
    required this.programado,
    required this.entrada,
    required this.apellidos,
    required this.nombres,
    required this.atkId,
  });

  factory TicketDspCsModel.fromDspCsData({
    required String turno,
    required String placa,
    required String fechaProgramado,
    required String apellidos,
    required String nombres,
    required int atkId,
  }) {
    // Fecha entrada como en C#: DateTime.Now.ToString("yyyy/MM/dd HH:mm")
    final entrada = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());

    return TicketDspCsModel(
      turno: turno,
      placa: placa,
      programado: fechaProgramado,
      entrada: entrada,
      apellidos: apellidos,
      nombres: nombres,
      atkId: atkId,
    );
  }

  Map<String, dynamic> toJson() => {
    'turno': turno,
    'placa': placa,
    'programado': programado,
    'entrada': entrada,
    'apellidos': apellidos,
    'nombres': nombres,
    'atk_id': atkId,
  };
}
