import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';

class WeightValidationUtils {
  /// Valida y convierte un string de peso a double
  /// Equivalente a Helpers.valida_double(lblWeight.Text) en C#
  static double validaDouble(String weightString) {
    LogService.instance.logRequest('WeightValidationUtils.validaDouble', {
      'action': 'validating_weight_string',
      'input': weightString,
    });

    try {
      final cleanWeight = weightString.trim().replaceAll(',', '.');

      if (cleanWeight.isEmpty || cleanWeight == "-100") {
        LogService.instance.logWarning('WeightValidationUtils.validaDouble', {
          'warning': 'Weight string is empty or error value',
          'input': weightString,
          'cleaned': cleanWeight,
        });
        return 0.0;
      }

      final peso = double.tryParse(cleanWeight) ?? 0.0;

      LogService.instance.logRequest('WeightValidationUtils.validaDouble', {
        'action': 'weight_parsing_completed',
        'input': weightString,
        'cleaned': cleanWeight,
        'parsed_value': peso,
        'is_valid': peso > 0,
      });

      return peso;
    } catch (e) {
      LogService.instance.logError('WeightValidationUtils.validaDouble', e);
      return 0.0;
    }
  }
}