// lib/utils/env_utils.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

bool _parseBool(String? raw, {bool defaultValue = false}) {
  if (raw == null) return defaultValue;
  switch (raw.trim().toLowerCase()) {
    case 'true':
    case '1':
    case 'yes':
    case 'y':
    case 'on':
      return true;
    case 'false':
    case '0':
    case 'no':
    case 'n':
    case 'off':
      return false;
    default:
      return defaultValue;
  }
}

/// Lee un booleano desde dotenv con tolerancia a distintos formatos.
bool envBool(String key, {bool defaultValue = false}) =>
    _parseBool(dotenv.env[key], defaultValue: defaultValue);

/// Lee un string desde dotenv (con default).
String envString(String key, {String defaultValue = ''}) =>
    dotenv.env[key] ?? defaultValue;

/// Flag reutilizable en toda la app.
bool get isTestMode => envBool('IS_TEST_MODE');

class EnvUtils {
  static bool get isTestMode {
    try {
      final testMode = dotenv.env['IS_TEST_MODE'];
      if (testMode == null) return false;
      return testMode.toLowerCase() == 'true' || testMode == '1';
    } catch (e) {
      return false;
    }
  }
}

class KioskUserEnv {
  const KioskUserEnv._();

  static String get usuario {
    // final group = (dotenv.env['GROUP'] ?? '').trim();
    // final bascula = (dotenv.env['BASCULA'] ?? '').trim();
    final usuario = (dotenv.env['USUARIO'] ?? '').trim();

    // final value = '$group $bascula'.trim();

    // if (value.isNotEmpty) return value;

    if (usuario.isNotEmpty) return usuario;

    return 'KIOSK';
  }
}
