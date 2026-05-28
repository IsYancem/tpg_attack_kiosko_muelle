// lib/config/incoming/dspcs_incoming_visibility_config.dart
// Autor: Abraham Yance
// Configuración de visibilidad completa para la pantalla ExmIncomingScreen
// Cada elemento visual puede activarse o desactivarse con un booleano.

class ExmIncomingVisibilityConfig {
  static final Map<String, bool> show = {
    // ════════════════════════════════════════════════════════════════════════════
    // 🔹 PANTALLA PRINCIPAL
    // ════════════════════════════════════════════════════════════════════════════
    'pantalla.dspcsIncomingScreen': true,

    // ════════════════════════════════════════════════════════════════════════════
    // 🔸 HEADER (AtkHeaderTransaction)
    // ════════════════════════════════════════════════════════════════════════════
    'header.logo': true,
    'header.titulo': true,
    'header.reloj': true,
    'header.countdown': true,
    'header.fondo': true,

    // ════════════════════════════════════════════════════════════════════════════
    // 🔸 SUBHEADER (AtkSubHeaderBarTransaction)
    // ════════════════════════════════════════════════════════════════════════════
    'subheader.icono': true,
    'subheader.textoDespacho': true,
    'subheader.nombreConductor': true,
    'subheader.tipoFlujo': true, // Entrada / Salida
    // ════════════════════════════════════════════════════════════════════════════
    // 🔸 COLUMNA 1 — DRIVER
    // ════════════════════════════════════════════════════════════════════════════
    'col1.visible': true,
    'col1.fotoConductor': true,
    'col1.cedula': true,
    'col1.companiaTransporte': true,

    // ════════════════════════════════════════════════════════════════════════════
    // 🔸 COLUMNA 2 — IMPORTADOR + PESO
    // ════════════════════════════════════════════════════════════════════════════
    'col2.exportador.visible': true,
    'col2.exportador.encabezado': true,
    'col2.exportador.cliente': true,
    'col2.exportador.producto': true,
    'col2.exportador.booking': true,
    'col2.exportador.nave': true,
    'col3.exportador.visible': true,
    'col3.exportador.contenedor': true,
    'col3.exportador.sello1': true,
    'col3.exportador.sello2': true,
    'col3.exportador.sello3': true,
    'col3.exportador.sello4': true,

    // ════════════════════════════════════════════════════════════════════════════
    // 🔸 COLUMNA 3 — MAPA + MENSAJE
    // ════════════════════════════════════════════════════════════════════════════
    'col3.visible': true,
    'col3.encabezado':
        false, // (Se removió en diseño actual, mantener por compatibilidad)
    'col3.mapa': true,
    'col3.mapa.textoNoDisponible': true,
    'col3.mensajeInferior': true, // "Procesando la transacción..."
    // ════════════════════════════════════════════════════════════════════════════
    // 🔸 FOOTER (AtkFooterBarCommon)
    // ════════════════════════════════════════════════════════════════════════════
    'footer.visible': true,
    'footer.toggleTheme': true,
    'footer.logotipo': true,
    'footer.statusServicios': true, // indicadores TOS, RFID, BASCULA, FACE, etc.
  };
}
