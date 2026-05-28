import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/config/incoming/trl_incoming_visibility_config.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

class Columna3ContenedoresTrl extends StatelessWidget {
  const Columna3ContenedoresTrl({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(TrlIncomingVisibilityConfig.show['col3.visible'] ?? true)) {
      return const SizedBox.shrink();
    }

    final p = context.palette;
    final manager = context.watch<AtkTransactionManager>();
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    final padding = (w * 0.012).clamp(8, 18).toDouble();
    final borderRadius = (w * 0.009).clamp(6, 14).toDouble();
    final innerBorderRadius = (w * 0.008).clamp(5, 12).toDouble();
    final spacing = (h * 0.012).clamp(6, 14).toDouble();
    final titleFontSize = (w * 0.013).clamp(13, 20).toDouble();
    final valueFontSize = (w * 0.011).clamp(12, 16).toDouble();

    Widget buildPanel(
      String titulo,
      String? valorPrincipal,
      String? valorDetalle,
    ) {
      return Container(
        margin: EdgeInsets.only(bottom: spacing),
        padding: EdgeInsets.all(padding * 0.8),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border.all(color: p.surfaceBorder, width: 1.2),
          borderRadius: BorderRadius.circular(innerBorderRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔷 Título del panel
            Text(
              titulo,
              style: TextStyle(
                color: p.panelTitleBlue,
                fontWeight: FontWeight.w900,
                fontSize: titleFontSize,
              ),
            ),
            SizedBox(height: spacing * 0.6),

            _buildFieldBox(valorPrincipal ?? '', p, valueFontSize, h * 0.05),

            SizedBox(height: spacing * 0.4),
            _buildFieldBox(valorDetalle ?? '', p, valueFontSize, h * 0.10),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.surfaceBorder, width: 1.2),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 🧱 Panel Contenedor 1
          if (TrlIncomingVisibilityConfig.show['col3.contenedor1'] ?? true)
            buildPanel('Contenedor 1', manager.contenedor1, manager.detalle1),

          // 🧱 Panel Contenedor 2
          if (TrlIncomingVisibilityConfig.show['col3.contenedor2'] ?? true)
            buildPanel('Contenedor 2', manager.contenedor2, manager.detalle2),
        ],
      ),
    );
  }

  Widget _buildFieldBox(
    String value,
    AppPalette p, // Cambiar de dynamic a AppPalette
    double fontSize,
    double height,
  ) {
    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: p.fieldBg, // Ahora fieldBg existe
        border: Border.all(color: p.surfaceBorder, width: 1.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        value.isNotEmpty ? value : '',
        style: TextStyle(
          color: p.textPrimary,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.fade,
        softWrap: true,
      ),
    );
  }
}
