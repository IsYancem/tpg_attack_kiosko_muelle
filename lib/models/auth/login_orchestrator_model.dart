// Autor: Abraham Yance
// Fecha: 2025-11-11
// Modelo de respuesta para el endpoint /kiosk/api/login/auth
// Estructura: { errorCode, message, data.services.{ldapUser,middlewareLogin,kioskConfig} }

class LoginOrchestratorResponse {
  final int errorCode;
  final String message;
  final LoginOrchestratorData data;

  LoginOrchestratorResponse({
    required this.errorCode,
    required this.message,
    required this.data,
  });

  factory LoginOrchestratorResponse.fromJson(Map<String, dynamic> json) {
    return LoginOrchestratorResponse(
      errorCode: json['errorCode'] ?? 1,
      message: json['message'] ?? '',
      data: LoginOrchestratorData.fromJson(json['data'] ?? {}),
    );
  }
}

class LoginOrchestratorData {
  final Map<String, StepEnvelope> services;

  LoginOrchestratorData({required this.services});

  factory LoginOrchestratorData.fromJson(Map<String, dynamic> json) {
    final servicesMap = <String, StepEnvelope>{};
    final raw = json['services'] ?? {};

    if (raw is Map<String, dynamic>) {
      raw.forEach((key, val) {
        servicesMap[key] = StepEnvelope.fromJson(
          val is Map<String, dynamic> ? val : null,
        );
      });
    }

    return LoginOrchestratorData(services: servicesMap);
  }

  StepEnvelope? get ldapUser => services['ldapUser'];
  StepEnvelope? get middlewareLogin => services['middlewareLogin'];
  StepEnvelope? get kioskConfig => services['kioskConfig'];
  StepEnvelope? get gateRes => services['kioskGate'];
  StepEnvelope? get parametersAtak => services['parametersAtak'];
  StepEnvelope? get kioskSessionLogIns => services['kioskSessionLogIns'];
}

class StepEnvelope {
  final int errorCode;
  final String message;
  final int? spErrorCode;
  final String? spMessage;
  final dynamic data;

  StepEnvelope({
    required this.errorCode,
    required this.message,
    this.spErrorCode,
    this.spMessage,
    this.data,
  });

  factory StepEnvelope.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return StepEnvelope(errorCode: 1, message: 'Sin datos');
    }
    return StepEnvelope(
      errorCode: json['errorCode'] ?? 1,
      message: json['message'] ?? '',
      spErrorCode: json['spErrorCode'],
      spMessage: json['spMessage'],
      data: json['data'],
    );
  }
}
