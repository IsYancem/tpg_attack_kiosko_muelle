// lib/services/global_manager.dart
// Autor: Abraham Yance
// Fecha: 2025-11-11
// 🔗 Provee acceso global a AtkTransactionManager sin depender de context()

import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';

class GlobalManager {
  static final GlobalManager _instance = GlobalManager._internal();
  late AtkTransactionManager transactionManager;

  GlobalManager._internal();

  static GlobalManager get instance => _instance;

  void init(AtkTransactionManager manager) {
    transactionManager = manager;
  }
}
