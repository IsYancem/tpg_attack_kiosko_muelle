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
