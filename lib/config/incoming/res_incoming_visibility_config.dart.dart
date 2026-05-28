// lib/config/incoming/res_incoming_visibility_config.dart
// Autor: Abraham Yance
// Configuración de visibilidad completa para la pantalla ResIncomingScreen
// Similar a EXP pero adaptado para RES (Recepción/Reserva)

class ResIncomingVisibilityConfig {
  static final Map<String, bool> show = {
    // ════════════════════════════════════════════════════════════════════════════
    // 🔹 PANTALLA PRINCIPAL
    // ════════════════════════════════════════════════════════════════════════════
    'pantalla.resIncomingScreen': true,

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
    'subheader.tipoFlujo': true,

    // ════════════════════════════════════════════════════════════════════════════
    // 🔸 COLUMNA 1 — DRIVER
    // ════════════════════════════════════════════════════════════════════════════
    'col1.visible': true,
    'col1.fotoConductor': true,
    'col1.cedula': true,
    'col1.companiaTransporte': true,

    // ════════════════════════════════════════════════════════════════════════════
    // 🔸 COLUMNA 2 — PESO Y OBSERVACIÓN (CENTRO)
    // ════════════════════════════════════════════════════════════════════════════
    'col2.visible': true,
    'col2.encabezado': true,
    'col2.peso': true,
    'col2.observacion': true,

    // ════════════════════════════════════════════════════════════════════════════
    // 🔸 COLUMNA 3 — DATOS ADICIONALES (DERECHA)
    // ════════════════════════════════════════════════════════════════════════════
    'col3.visible': true,
    'col3.encabezado': true,
    'col3.mapa': true,
    'col3.mapa.textoNoDisponible': true,
    'col3.mensajeInferior': true,

    // ════════════════════════════════════════════════════════════════════════════
    // 🔸 FOOTER (AtkFooterBarCommon)
    // ════════════════════════════════════════════════════════════════════════════
    'footer.visible': true,
    'footer.toggleTheme': true,
    'footer.logotipo': true,
    'footer.statusServicios': true,
  };
}
