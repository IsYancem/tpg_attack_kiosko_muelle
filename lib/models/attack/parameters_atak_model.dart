// lib/models/attack/parameters_atak_model.dart

class ParametersAtakModel {
  final Map<String, dynamic> raw;

  final double basculaPeso;
  final String autorizacionCcsv;
  final String autorizacionClave;
  final double tolerancia;
  final double tolerancia2;
  final int tiempoTimer;
  final int tiempoTimer2;
  final int timerPausaNoEncontro;
  final int timerTransacciones;
  final int timerSerialPort1;
  final int timerPedirAutoriz;
  final double toleranciaCsuelta;
  final int codCompFict;
  final int huella;
  final int aux;
  final double porcIgual;
  final double traslado;
  final int huellaMuelle;
  final int pesoAMano;
  final double porteoPeso;
  final double pesoBypass;
  final double pesoPromedio;
  final double toleranciaVacio;
  final double toleranciaCsueltaMax;
  final double toleranciaCsueltaMin;
  final double promedioPorteo;
  final double toleranciaPorteo;
  final double OCR_CONFIDENCE;

  const ParametersAtakModel({
    required this.raw,
    required this.basculaPeso,
    required this.autorizacionCcsv,
    required this.autorizacionClave,
    required this.tolerancia,
    required this.tolerancia2,
    required this.tiempoTimer,
    required this.tiempoTimer2,
    required this.timerPausaNoEncontro,
    required this.timerTransacciones,
    required this.timerSerialPort1,
    required this.timerPedirAutoriz,
    required this.toleranciaCsuelta,
    required this.codCompFict,
    required this.huella,
    required this.aux,
    required this.porcIgual,
    required this.traslado,
    required this.huellaMuelle,
    required this.pesoAMano,
    required this.porteoPeso,
    required this.pesoBypass,
    required this.pesoPromedio,
    required this.toleranciaVacio,
    required this.toleranciaCsueltaMax,
    required this.toleranciaCsueltaMin,
    required this.promedioPorteo,
    required this.toleranciaPorteo,
    required this.OCR_CONFIDENCE,
  });

  factory ParametersAtakModel.fromJson(Map<String, dynamic> json) {
    return ParametersAtakModel(
      raw: Map<String, dynamic>.from(json),
      basculaPeso: _double(json['BASCULA_PESO']),
      autorizacionCcsv: _string(json['AUTORIZACION_CCSV']),
      autorizacionClave: _string(json['AUTORIZACION_clave']),
      tolerancia: _double(json['tolerancia']),
      tolerancia2: _double(json['tolerancia2']),
      tiempoTimer: _int(json['tiempo_timer']),
      tiempoTimer2: _int(json['tiempo_timer2']),
      timerPausaNoEncontro: _int(json['timer2_pausa_noencontro']),
      timerTransacciones: _int(json['timer_TRANSACCIONES']),
      timerSerialPort1: _int(json['timer_serialPort1']),
      timerPedirAutoriz: _int(json['timer_pedir_autoriz']),
      toleranciaCsuelta: _double(json['tolerancia_csuelta']),
      codCompFict: _int(json['COD_COMP_FICT']),
      huella: _int(json['HUELLA']),
      aux: _int(json['AUX']),
      porcIgual: _double(json['PORC_IGUAL']),
      traslado: _double(json['TRASLADO']),
      huellaMuelle: _int(json['huella_muelle']),
      pesoAMano: _int(json['peso_a_mano']),
      porteoPeso: _double(json['PORTEOPESO']),
      pesoBypass: _double(json['peso_bypass']),
      pesoPromedio: _double(json['peso_promedio']),
      toleranciaVacio: _double(json['tolerancia_vacio']),
      toleranciaCsueltaMax: _double(json['tolerancia_cSueltaMax']),
      toleranciaCsueltaMin: _double(json['tolerancia_cSueltaMin']),
      promedioPorteo: _double(json['promedio_porteo']),
      toleranciaPorteo: _double(json['tolerancia_porteo']),
      OCR_CONFIDENCE: _double(json['OCR_CONFIDENCE']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...raw,
      'BASCULA_PESO': basculaPeso,
      'AUTORIZACION_CCSV': autorizacionCcsv,
      'AUTORIZACION_clave': autorizacionClave,
      'tolerancia': tolerancia,
      'tolerancia2': tolerancia2,
      'tiempo_timer': tiempoTimer,
      'tiempo_timer2': tiempoTimer2,
      'timer2_pausa_noencontro': timerPausaNoEncontro,
      'timer_TRANSACCIONES': timerTransacciones,
      'timer_serialPort1': timerSerialPort1,
      'timer_pedir_autoriz': timerPedirAutoriz,
      'tolerancia_csuelta': toleranciaCsuelta,
      'COD_COMP_FICT': codCompFict,
      'HUELLA': huella,
      'AUX': aux,
      'PORC_IGUAL': porcIgual,
      'TRASLADO': traslado,
      'huella_muelle': huellaMuelle,
      'peso_a_mano': pesoAMano,
      'PORTEOPESO': porteoPeso,
      'peso_bypass': pesoBypass,
      'peso_promedio': pesoPromedio,
      'tolerancia_vacio': toleranciaVacio,
      'tolerancia_cSueltaMax': toleranciaCsueltaMax,
      'tolerancia_cSueltaMin': toleranciaCsueltaMin,
      'promedio_porteo': promedioPorteo,
      'tolerancia_porteo': toleranciaPorteo,
      'OCR_CONFIDENCE': OCR_CONFIDENCE,
    };
  }

  dynamic get(String key) => raw[key];

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static int _int(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim()) ?? 0;
  }

  static double _double(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? 0;
  }
}