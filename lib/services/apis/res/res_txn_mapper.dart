// lib/services/apis/res/res_txn_mapper.dart

import 'package:tpg_attack_kiosko_muelle/models/res/res_models.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';

class ResTxnMapper {
  static void applyInit(AtkTransactionManager m, ApiEnvelope<ResInitData> env) {
    final data = env.data;

    m.setManyWithoutNotify({
      'numTrans': data?.numTrans ?? 0,
      'isLoading': false,
      'mensajeInferior': env.isOk
          ? 'RES inicializado.\nPuede continuar.'
          : 'RES init falló: ${env.message}',
    });

    m.notifyListeners();
  }

  static void applyGuardar(
    AtkTransactionManager m,
    ApiEnvelope<ResGuardarData> env,
  ) {
    final data = env.data;

    m.setManyWithoutNotify({
      'numTrans': data?.numTrans ?? m.get('numTrans') ?? 0,
      'isLoading': false,
      'mensajeInferior': env.isOk
          ? 'RES guardado OK.\nPuede terminar o imprimir.'
          : 'RES guardar falló: ${env.message}',
    });

    m.notifyListeners();
  }

  static void applyTerminar(
    AtkTransactionManager m,
    ApiEnvelope<ResTerminarData> env,
  ) {
    m.setManyWithoutNotify({
      'isLoading': false,
      'mensajeInferior': env.isOk
          ? 'RES terminar OK.\nBarrera procesada.'
          : 'RES terminar falló: ${env.message}',
    });

    m.notifyListeners();
  }

  static void applyCancelar(
    AtkTransactionManager m,
    ApiEnvelope<ResCancelarData> env,
  ) {
    m.setManyWithoutNotify({
      'isLoading': false,
      'mensajeInferior': env.isOk
          ? 'RES cancelado.\nRetornando...'
          : 'RES cancelar falló: ${env.message}',
    });

    m.notifyListeners();
  }

  static void applyImprimir(
    AtkTransactionManager m,
    ApiEnvelope<ResImprimirData> env,
  ) {
    final data = env.data;
    final printable = data?.printable;

    if (printable != null) {
      // ✅ Guardar el printable completo en el data map

    } else {
      m.setManyWithoutNotify({
        'isLoading': false,
        'mensajeInferior': env.isOk
            ? 'RES listo para imprimir.'
            : 'RES imprimir falló: ${env.message}',
      });
    }

    m.notifyListeners();
  }
}

extension ResTxnManagerRead on AtkTransactionManager {
  int? getInt(String key) {
    final v = get(key);
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  String? getString(String key) {
    final v = get(key);
    return v?.toString();
  }
}
