// lib/widgets/dsp_incoming/columna2_importador_dsp.dart
// Columna 2 — Peso e Importador (versión compacta responsive)
// Autor: Abraham Yance
// Fecha: 2025-11-08

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/config/incoming/dsp_incoming_visibility_config.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/atk_info_panel.dart';

class Columna2ImportadorDsp extends StatelessWidget {
  const Columna2ImportadorDsp({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(DspIncomingVisibilityConfig.show['col2.visible'] ?? true)) {
      return const SizedBox.shrink();
    }

    final p = context.palette;
    final manager = context.watch<AtkTransactionManager>();

    // Dimensiones responsivas
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    // Escalas ajustadas (espacios y paddings reducidos)
    final paddingH = (w * 0.015).clamp(8, 18).toDouble();
    final paddingV = (h * 0.015).clamp(8, 14).toDouble();
    final spacing = (h * 0.012).clamp(4, 10).toDouble(); // menos espacio
    final borderRadius = (w * 0.009).clamp(6, 14).toDouble();
    final pesoHeight = (h * 0.05).clamp(40, 70).toDouble();
    final iconSize = (w * 0.02).clamp(22, 34).toDouble();
    final pesoFontSize = (w * 0.045).clamp(24, 36).toDouble();
    final unidadFontSize = (w * 0.024).clamp(12, 16).toDouble();
    final headerFontSize = (w * 0.012).clamp(14, 18).toDouble();
    final infoFontSize = (w * 0.009).clamp(11, 15).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.surfaceBorder, width: 1.2),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ⚖️ Peso (más compacto)
          if (DspIncomingVisibilityConfig.show['col2.peso'] ?? true)
            Container(
              height: pesoHeight,
              decoration: BoxDecoration(
                color: p.surfaceBorder.withValues(alpha:0.10),
                border: Border.all(color: p.panelTitleBlue, width: 1.2),
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              padding: EdgeInsets.symmetric(horizontal: paddingH * 0.6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (DspIncomingVisibilityConfig.show['col2.peso.icono'] ??
                      true)
                    Icon(
                      Icons.scale_rounded,
                      size: iconSize,
                      color: p.panelTitleBlue,
                    ),
                  SizedBox(width: w * 0.01),
                  Text(
                    manager.pesoActualBascula.toString(),
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: pesoFontSize,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (DspIncomingVisibilityConfig.show['col2.peso.unidad'] ??
                      true)
                    SizedBox(width: w * 0.01),
                  if (DspIncomingVisibilityConfig.show['col2.peso.unidad'] ??
                      true)
                    Text(
                      'kg',
                      style: TextStyle(
                        color: p.textMuted,
                        fontSize: unidadFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),

          SizedBox(height: spacing * 1.4),

          // 🔷 Encabezado
          if (DspIncomingVisibilityConfig.show['col2.encabezado'] ?? true)
            Center(
              child: Text(
                'DATOS DEL IMPORTADOR',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: p.panelTitleBlue,
                  fontSize: headerFontSize,
                ),
              ),
            ),

          SizedBox(height: spacing * 1.2),

          // 🧾 Campos informativos (compactos)
          if (DspIncomingVisibilityConfig.show['col2.importador'] ?? true)
            AtkInfoPanel(
              title: 'IMPORTADOR',
              value: manager.importador,
              fontSize: infoFontSize,
            ),
          if (DspIncomingVisibilityConfig.show['col2.dres'] ?? true)
            AtkInfoPanel(
              title: 'DRES',
              value: manager.dres,
              fontSize: infoFontSize,
            ),
          if (DspIncomingVisibilityConfig.show['col2.contenedor'] ?? true)
            AtkInfoPanel(
              title: 'CONTENEDOR',
              value: manager.contenedor,
              fontSize: infoFontSize,
            ),
          if (DspIncomingVisibilityConfig.show['col2.ubicacion'] ?? true)
            AtkInfoPanel(
              title: 'UBICACIÓN',
              value: manager.ubicacion,
              fontSize: infoFontSize,
            ),
          if (DspIncomingVisibilityConfig.show['col2.turno'] ?? true)
            AtkInfoPanel(
              title: 'TURNO',
              value: manager.turno,
              fontSize: infoFontSize,
            ),
        ],
      ),
    );
  }
}
