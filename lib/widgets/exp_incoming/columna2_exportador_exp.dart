import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/config/incoming/exp_incoming_visibility_config.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

class Columna2ExportadorExp extends StatelessWidget {
  const Columna2ExportadorExp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(ExpIncomingVisibilityConfig.show['col2.exportador.visible'] ??
        true)) {
      return const SizedBox.shrink();
    }

    final p = context.palette;
    final manager = context.watch<AtkTransactionManager>();
    final size = MediaQuery.of(context).size;

    final w = size.width;
    final h = size.height;

    final padding = (w * 0.012).clamp(8, 18).toDouble();
    final borderRadius = (w * 0.009).clamp(6, 14).toDouble();
    final spacing = (h * 0.012).clamp(6, 14).toDouble();
    final headerFontSize = (w * 0.012).clamp(14, 20).toDouble();
    final labelFontSize = (w * 0.011).clamp(13, 18).toDouble();
    final valueFontSize = (w * 0.010).clamp(12, 16).toDouble();

    // Fondo de campo según tema (no blanco fijo)
    final fieldBg = Color.alphaBlend(
      p.fallbackSurfaceOverlay.withValues(alpha:0.4),
      p.panelBg,
    );
    final fieldBorder = p.surfaceBorder.withValues(alpha:0.8);

    Widget buildRowField(String label, String? value) {
      return Padding(
        padding: EdgeInsets.only(bottom: spacing * 0.6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Label
            Expanded(
              flex: 3,
              child: Text(
                label,
                style: TextStyle(
                  color: p.panelTitleBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: labelFontSize,
                ),
              ),
            ),
            // Valor
            Expanded(
              flex: 7,
              child: Container(
                height: h * 0.05,
                decoration: BoxDecoration(
                  color: fieldBg,
                  border: Border.all(color: fieldBorder, width: 1.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.symmetric(horizontal: padding * 0.5),
                child: Text(
                  value?.isNotEmpty == true ? value! : '',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: valueFontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildSelloField(String? value) {
      return Padding(
        padding: EdgeInsets.only(bottom: spacing * 0.4),
        child: Container(
          height: h * 0.045,
          decoration: BoxDecoration(
            color: fieldBg,
            border: Border.all(color: fieldBorder, width: 1.1),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.centerLeft,
          padding: EdgeInsets.symmetric(horizontal: padding * 0.5),
          child: Text(
            value?.isNotEmpty == true ? value! : '',
            style: TextStyle(
              color: p.textPrimary,
              fontSize: valueFontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: p.panelBg,
        border: Border.all(color: p.surfaceBorder, width: 1.2),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          if (Theme.of(context).brightness == Brightness.light)
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          else
            BoxShadow(
              color: Colors.black.withValues(alpha:0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      padding: EdgeInsets.all(padding),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🟦 Encabezado principal
            if (ExpIncomingVisibilityConfig
                    .show['col2.exportador.encabezado'] ??
                true)
              Padding(
                padding: EdgeInsets.only(bottom: spacing * 0.6),
                child: Center(
                  child: Text(
                    'Datos del Exportador',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: p.panelTitleBlue,
                      fontSize: headerFontSize,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),

            // 🧾 Campos de información
            if (ExpIncomingVisibilityConfig.show['col2.exportador.cliente'] ??
                true)
              buildRowField('Cliente', manager.clienteExp),
            if (ExpIncomingVisibilityConfig.show['col2.exportador.producto'] ??
                true)
              buildRowField('Producto', manager.productoExp),
            if (ExpIncomingVisibilityConfig.show['col2.exportador.booking'] ??
                true)
              buildRowField('Booking', manager.bookingExp),
            if (ExpIncomingVisibilityConfig.show['col2.exportador.nave'] ??
                true)
              buildRowField('Nave', manager.naveExp),

            SizedBox(height: spacing * 1.1),

            if (ExpIncomingVisibilityConfig
                    .show['col2.exportador.contenedor'] ??
                true)
              buildRowField('Contenedor', manager.contenedorExp),

            SizedBox(height: spacing * 0.8),

            // 🔹 Sección de sellos
            Text(
              'Sellos',
              style: TextStyle(
                color: p.panelTitleBlue,
                fontWeight: FontWeight.w900,
                fontSize: headerFontSize,
              ),
            ),
            SizedBox(height: spacing * 0.5),

            if (ExpIncomingVisibilityConfig.show['col2.exportador.sello1'] ??
                true)
              buildSelloField(manager.sello1Exp),
            if (ExpIncomingVisibilityConfig.show['col2.exportador.sello2'] ??
                true)
              buildSelloField(manager.sello2Exp),
            if (ExpIncomingVisibilityConfig.show['col2.exportador.sello3'] ??
                true)
              buildSelloField(manager.sello3Exp),
            if (ExpIncomingVisibilityConfig.show['col2.exportador.sello4'] ??
                true)
              buildSelloField(manager.sello4Exp),
          ],
        ),
      ),
    );
  }
}
