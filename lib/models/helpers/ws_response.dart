// Author: Abraham Yance
// Desc: Respuesta estándar para llamadas simples del WS (error/mensaje/datos)
class WsResponse {
  bool error;
  String desError; 
  String data; 

  WsResponse({required this.error, required this.desError, required this.data});

  // atajos útiles
  factory WsResponse.ok(String data) =>
      WsResponse(error: false, desError: '', data: data);
  factory WsResponse.fail(String msg) =>
      WsResponse(error: true, desError: msg, data: '');

  @override
  String toString() =>
      'WsResponse(error: $error, desError: $desError, data: $data)';
}
