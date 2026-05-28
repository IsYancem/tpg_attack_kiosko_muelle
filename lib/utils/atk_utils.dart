// lib/utils/atk_utils.dart
// Autor: Abraham Yance
// Fecha: 2025-12-02
// Utilitarios comunes para transacciones Attack Kiosko

class AtkUtils {
  /// Intercambia el side recibido: si es 1 retorna 2, si es 2 retorna 1, si es null o inválido retorna 1
  static int invertSide(int? side) {
    if (side == 1) return 2;
    if (side == 2) return 1;
    return 1;
  }
}
