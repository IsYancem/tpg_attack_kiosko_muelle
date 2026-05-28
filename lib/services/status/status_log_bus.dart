// services/status/status_log_bus.dart
import 'dart:async';

class StatusLogBus {
  StatusLogBus._();
  static final StatusLogBus instance = StatusLogBus._();

  final _ctrl = StreamController<String>.broadcast();
  Stream<String> get stream => _ctrl.stream;

  /// Mensaje de estado tipo UP/DOWN
  void addStatus(String source, bool up) {
    final msg = up ? '✅ UP' : '❌ DOWN';
    // Formato uniforme para fácil parseo en el log panel
    _ctrl.add('[$source] $msg');
  }

  /// Mensaje de texto del servicio (handshake, raw, etc.)
  void addText(String source, String text) {
    _ctrl.add('[$source] $text');
  }
}
