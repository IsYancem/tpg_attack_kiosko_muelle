// lib/models/auth/keycloak_token_model.dart
//
// Respuesta del endpoint de token de Keycloak (OpenID Connect).
// Grant type: password (Resource Owner Password Credentials).

class KeycloakTokenResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final String? idToken;
  final int expiresIn;
  final int refreshExpiresIn;
  final String? scope;
  final String? sessionState;

  const KeycloakTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.refreshExpiresIn,
    this.idToken,
    this.scope,
    this.sessionState,
  });

  factory KeycloakTokenResponse.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v.trim()) ?? 0;
      return 0;
    }

    return KeycloakTokenResponse(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'Bearer',
      idToken: json['id_token']?.toString(),
      expiresIn: toInt(json['expires_in']),
      refreshExpiresIn: toInt(json['refresh_expires_in']),
      scope: json['scope']?.toString(),
      sessionState: json['session_state']?.toString(),
    );
  }

  bool get isValid => accessToken.isNotEmpty && refreshToken.isNotEmpty;
}