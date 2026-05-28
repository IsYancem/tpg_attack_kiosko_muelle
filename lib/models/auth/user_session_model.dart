// lib/models/auth/user_session_model.dart
// Author: Tu nombre
// Date: 2025-09-25
// Desc: Modelo para gestionar la sesión de usuario y UUID de barrera

class UserSessionModel {
  String? userUuid;
  DateTime? loginTime;
  bool isLoggedIn;

  UserSessionModel({this.userUuid, this.loginTime, this.isLoggedIn = false});

  void setUserUuid(String uuid) {
    userUuid = uuid;
    loginTime = DateTime.now();
    isLoggedIn = true; // Marcar como logged in incluso si uuid es cadena vacía
  }

  void clearSession() {
    userUuid = null;
    loginTime = null;
    isLoggedIn = false;
  }

  // ← NUEVO: Getter para verificar si tiene UUID válido (no vacío)
  bool get hasValidUuid => userUuid != null && userUuid!.isNotEmpty;

  // ← NUEVO: Getter para verificar si está en modo test
  bool get isTestMode => isLoggedIn && (userUuid == null || userUuid!.isEmpty);

  Map<String, dynamic> toJson() {
    return {
      'user_uuid': userUuid,
      'login_time': loginTime?.toIso8601String(),
      'is_logged_in': isLoggedIn,
      'has_valid_uuid': hasValidUuid,
      'is_test_mode': isTestMode,
    };
  }

  factory UserSessionModel.fromJson(Map<String, dynamic> json) {
    return UserSessionModel(
      userUuid: json['user_uuid'] as String?,
      loginTime: json['login_time'] != null
          ? DateTime.tryParse(json['login_time'] as String)
          : null,
      isLoggedIn: json['is_logged_in'] as bool? ?? false,
    );
  }
}
