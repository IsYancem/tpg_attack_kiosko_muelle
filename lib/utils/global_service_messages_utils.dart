/// Buffer global para mensajes cortos de otros servicios (éxitos/errores)
class GlobalServiceMessages {
  static final List<String> items = [];

  static void push(String message) {
    items.add(message);
    // (Opcional) evita crecer infinito
    if (items.length > 500) items.removeAt(0);
  }
}
