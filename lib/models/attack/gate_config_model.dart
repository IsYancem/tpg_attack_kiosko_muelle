// Autor: Abraham Yance
// Fecha: 2025-11-20
// Modelo para mapear gateRes del login unificado (con hasta 16 movimientos dinámicos)

class GateConfigModel {
  final List<String> movimientos; // mov1 a mov16
  final String apiKey;
  final String name;
  final int side;
  final String serverApp;
  final String serverPlc;
  final String keyPlc;
  final int statePlc;

  /// Nuevo: ubicación lógica del gate para headers de WS
  final String gateLocation;

  GateConfigModel({
    required this.movimientos,
    required this.apiKey,
    required this.name,
    required this.side,
    required this.serverApp,
    required this.serverPlc,
    required this.keyPlc,
    required this.statePlc,
    required this.gateLocation,
  });

  factory GateConfigModel.fromJson(Map<String, dynamic> json) {
    final movimientos = <String>[];
    for (int i = 1; i <= 16; i++) {
      final key = 'mov$i';
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        movimientos.add(value.toString().trim());
      }
    }

    final rawLocation =
        json['gate_location'] ?? json['gateLocation'] ?? json['location'];

    return GateConfigModel(
      movimientos: movimientos,
      apiKey: (json['api_key'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      side: json['side'] ?? 0,
      serverApp: (json['server_app'] ?? '').toString(),
      serverPlc: (json['server_plc'] ?? '').toString(),
      keyPlc: (json['key_plc'] ?? '').toString(),
      statePlc: json['state_plc'] ?? 0,
      gateLocation: rawLocation == null ? '' : rawLocation.toString(),
    );
  }
}
