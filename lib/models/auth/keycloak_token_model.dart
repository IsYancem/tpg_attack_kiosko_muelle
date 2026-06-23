// lib/models/auth/keycloak_token_model.dart

import 'dart:convert';

class KeycloakTokenResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final String idToken;
  final String sessionState;
  final int expiresIn;
  final int refreshExpiresIn;

  final Map<String, dynamic> claims;
  final List<String> realmAccessGroups;

  final String name;
  final String identificationId;
  final String preferredUsername;
  final String email;
  final String ruc;
  final String userType;
  final String givenName;

  KeycloakTokenResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.idToken,
    required this.sessionState,
    required this.expiresIn,
    required this.refreshExpiresIn,
    required this.claims,
    required this.realmAccessGroups,
    required this.name,
    required this.identificationId,
    required this.preferredUsername,
    required this.email,
    required this.ruc,
    required this.userType,
    required this.givenName,
  });

  static String _str(dynamic v) => v?.toString().trim() ?? '';

  static Map<String, dynamic> _decodeJwtPayload(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length < 2) return {};

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decodedBytes = base64Url.decode(normalized);
      final decodedText = utf8.decode(decodedBytes);
      final decodedJson = jsonDecode(decodedText);

      if (decodedJson is Map<String, dynamic>) {
        return decodedJson;
      }

      if (decodedJson is Map) {
        return Map<String, dynamic>.from(decodedJson);
      }

      return {};
    } catch (_) {
      return {};
    }
  }

  static List<String> _readGroups(Map<String, dynamic> claims) {
    final raw = claims['realm_access_groups'];

    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return const [];
  }

  static String _normGroup(String value) =>
      value.trim().replaceAll(RegExp(r'/+$'), '').toLowerCase();

  bool hasRealmGroup(String requiredGroup) {
    final expected = _normGroup(requiredGroup);

    return realmAccessGroups.any((group) {
      return _normGroup(group) == expected;
    });
  }

  bool get hasOcrMuelleGroup => hasRealmGroup('/TPG/Ocr Muelle');

  factory KeycloakTokenResponse.fromJson(Map<String, dynamic> json) {
    final accessToken = _str(json['access_token']);
    final idToken = _str(json['id_token']);

    var claims = _decodeJwtPayload(accessToken);

    // Fallback por si Keycloak mueve claims custom al id_token.
    if (claims.isEmpty && idToken.isNotEmpty) {
      claims = _decodeJwtPayload(idToken);
    }

    final groups = _readGroups(claims);

    return KeycloakTokenResponse(
      accessToken: accessToken,
      refreshToken: _str(json['refresh_token']),
      tokenType: _str(json['token_type']),
      idToken: idToken,
      sessionState: _str(json['session_state']),
      expiresIn: int.tryParse(json['expires_in']?.toString() ?? '0') ?? 0,
      refreshExpiresIn:
          int.tryParse(json['refresh_expires_in']?.toString() ?? '0') ?? 0,
      claims: claims,
      realmAccessGroups: groups,
      name: _str(claims['name']),
      identificationId: _str(claims['identification_id']),
      preferredUsername: _str(claims['preferred_username']),
      email: _str(claims['email']),
      ruc: _str(claims['ruc']),
      userType: _str(claims['user_type']),
      givenName: _str(claims['given_name']),
    );
  }
}