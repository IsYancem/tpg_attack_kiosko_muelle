class InsertaTareaRadarRequest {
  final String wsUsuario;
  final String wsClave;
  final String codProceso;
  final String codMovimiento;
  final String codPuerto;
  final String anoOperacion;
  final String corOperacion;
  final String codSigla;
  final String codNumero;
  final String codDigito;
  final String patente;
  final String rucUsuario;
  final String numTurno;
  final String fechaTurno;
  final String terminalFin;
  final String areaFin;
  final String bayFin;
  final String rowFin;
  final String tierFin;

  InsertaTareaRadarRequest({
    required this.wsUsuario,
    required this.wsClave,
    required this.codProceso,
    required this.codMovimiento,
    required this.codPuerto,
    required this.anoOperacion,
    required this.corOperacion,
    required this.codSigla,
    required this.codNumero,
    required this.codDigito,
    required this.patente,
    required this.rucUsuario,
    required this.numTurno,
    required this.fechaTurno,
    required this.terminalFin,
    required this.areaFin,
    required this.bayFin,
    required this.rowFin,
    required this.tierFin,
  });

  String toSoapXml() {
    return '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <InsertaTareaRadar xmlns="http://tempuri.org/">
      <p_ws_ususario>$wsUsuario</p_ws_ususario>
      <p_ws_pass>$wsClave</p_ws_pass>
      <p_codProceso>$codProceso</p_codProceso>
      <p_codMovimiento>$codMovimiento</p_codMovimiento>
      <p_codPuerto>$codPuerto</p_codPuerto>
      <p_anoOperacion>$anoOperacion</p_anoOperacion>
      <p_corOperacion>$corOperacion</p_corOperacion>
      <p_codSigla>$codSigla</p_codSigla>
      <p_codNumero>$codNumero</p_codNumero>
      <p_codDigito>$codDigito</p_codDigito>
      <p_patente>$patente</p_patente>
      <p_rutUsuario>$rucUsuario</p_rutUsuario>
      <p_numTurno>$numTurno</p_numTurno>
      <p_fechaTurno>$fechaTurno</p_fechaTurno>
      <p_Terminal_fin>$terminalFin</p_Terminal_fin>
      <p_Area_fin>$areaFin</p_Area_fin>
      <p_bay_fin>$bayFin</p_bay_fin>
      <p_row_fin>$rowFin</p_row_fin>
      <p_tier_fin>$tierFin</p_tier_fin>
    </InsertaTareaRadar>
  </soap:Body>
</soap:Envelope>''';
  }
}

class InsertaTareaRadarResponse {
  final String estado;
  final String mensaje;
  final String datosJson;

  InsertaTareaRadarResponse({
    required this.estado,
    required this.mensaje,
    required this.datosJson,
  });

  factory InsertaTareaRadarResponse.fromXml(String xmlResponse) {
    // Parser básico para XML SOAP - requiere implementación específica
    // Por ahora retorno valores por defecto
    return InsertaTareaRadarResponse(
      estado: 'OK',
      mensaje: 'Procesado',
      datosJson: '',
    );
  }

  bool get isSuccess => estado == 'OK';
}
