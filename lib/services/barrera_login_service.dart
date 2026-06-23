// Author: Tu nombre
// Date: 2025-09-25
// Desc: Servicio para autenticación con barrera (equivalente al connect de C#)
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';

class BarreraLoginResponse {
  final bool error;
  final String message;
  final String? userUuid;

  const BarreraLoginResponse({
    required this.error,
    required this.message,
    this.userUuid,
  });

  factory BarreraLoginResponse.success(String userUuid) {
    return BarreraLoginResponse(
      error: false,
      message: 'Login exitoso',
      userUuid: userUuid,
    );
  }

  factory BarreraLoginResponse.failure(String message) {
    return BarreraLoginResponse(error: true, message: message, userUuid: null);
  }
}

class BarreraLoginService {
  static final _http = LogService.instance.httpClient;

  /// Conecta con el servicio de barrera (equivalente al connect de C#)
  static Future<BarreraLoginResponse> connect() async {
    LogService.instance.logRequest('BarreraLoginService.connect', {
      'action': 'starting_barrera_login',
    });

    try {
      // Obtener configuración desde .env
      final loginUrl = dotenv.env['LOGIN_BARRERA_URL'];
      final user = dotenv.env['USER_BARRERA'];
      final password = dotenv.env['PASSWORD_BARRERA'];
      final group = dotenv.env['GROUP_BARRERA'] ?? 'defaultgroup';

      // Validar configuración
      if (loginUrl == null || loginUrl.isEmpty) {
        const errorMsg = 'LOGIN_BARRERA_URL no configurada en .env';
        LogService.instance.logError(
          'BarreraLoginService.connect',
          errorMsg,
        );
        return BarreraLoginResponse.failure(errorMsg);
      }

      if (user == null || user.isEmpty) {
        const errorMsg = 'USER_BARRERA no configurado en .env';
        LogService.instance.logError(
          'BarreraLoginService.connect',
          errorMsg,
        );
        return BarreraLoginResponse.failure(errorMsg);
      }

      if (password == null || password.isEmpty) {
        const errorMsg = 'PASSWORD_BARRERA no configurado en .env';
        LogService.instance.logError(
          'BarreraLoginService.connect',
          errorMsg,
        );
        return BarreraLoginResponse.failure(errorMsg);
      }

      // Construir URL con parámetros (equivalente al String.Format del C#)
      final uri = Uri.parse(loginUrl).replace(
        queryParameters: {'user': user, 'passwd': password, 'group': group},
      );

      LogService.instance.logRequest('BarreraLoginService.connect', {
        'action': 'calling_barrera_service',
        'url': loginUrl, // Solo la URL base sin parámetros sensibles
        'user': user,
        'group': group,
      });

      // Hacer la petición (equivalente a webClient.DownloadString)
      final response = await _http
          .get(uri)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Timeout conectando con servicio de barrera');
            },
          );

      LogService.instance.logRequest('BarreraLoginService.connect', {
        'action': 'barrera_service_response',
        'status_code': response.statusCode,
        'response_length': response.body.length,
      });

      if (response.statusCode != 200) {
        final errorMsg =
            'HTTP ${response.statusCode} - Error en servicio de barrera';
        LogService.instance.logError(
          'BarreraLoginService.connect',
          errorMsg,
        );
        return BarreraLoginResponse.failure(errorMsg);
      }

      final responseData = response.body.trim();

      if (responseData.isEmpty) {
        const errorMsg = 'Respuesta vacía del servicio de barrera';
        LogService.instance.logError(
          'BarreraLoginService.connect',
          errorMsg,
        );
        return BarreraLoginResponse.failure(errorMsg);
      }

      // El data devuelto contiene el userUuid (equivalente a wsResponse.data = data)
      LogService.instance.logRequest('BarreraLoginService.connect', {
        'action': 'barrera_login_success',
        'user_uuid_received': true,
        'response_data_length': responseData.length,
      });

      return BarreraLoginResponse.success(responseData);
    } on SocketException catch (e) {
      final errorMsg = 'Error de conexión: ${e.message}';
      LogService.instance.logError('BarreraLoginService.connect', e);
      return BarreraLoginResponse.failure('WebEx::$errorMsg');
    } on Exception catch (e) {
      final errorMsg = 'Error: ${e.toString()}';
      LogService.instance.logError('BarreraLoginService.connect', e);
      return BarreraLoginResponse.failure('Ex::$errorMsg');
    } catch (e) {
      final errorMsg = 'Error inesperado: ${e.toString()}';
      LogService.instance.logError('BarreraLoginService.connect', e);
      return BarreraLoginResponse.failure('Ex::$errorMsg');
    }
  }
}
