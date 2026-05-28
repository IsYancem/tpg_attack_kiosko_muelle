// lib/services/print/print_result.dart

/// Resultado de una operación de impresión
class PrintResult {
  final bool isSuccess;
  final String message;

  PrintResult({required this.isSuccess, required this.message});

  @override
  String toString() => 'PrintResult(success: $isSuccess, message: $message)';

  /// Factory method para resultado exitoso
  factory PrintResult.success([String message = 'Impresión exitosa']) {
    return PrintResult(isSuccess: true, message: message);
  }

  /// Factory method para resultado fallido
  factory PrintResult.error(String message) {
    return PrintResult(isSuccess: false, message: message);
  }
}
