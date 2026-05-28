// lib/widgets/trl_incoming/columna2_transferencia_trl.dart
// Autor: Abraham Yance
// Columna 2 — Lugar de Transferencia (solo visual, sin campos editables)
// Fecha: 2025-11-09

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/config/incoming/trl_incoming_visibility_config.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

class Columna2TransferenciaTrl extends StatelessWidget {
  const Columna2TransferenciaTrl({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(TrlIncomingVisibilityConfig.show['col2.visible'] ?? true)) {
      return const SizedBox.shrink();
    }

    final p = context.palette;
    final manager = context.watch<AtkTransactionManager>();
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    // Escalas adaptativas
    final paddingH = (w * 0.015).clamp(8, 20).toDouble();
    final paddingV = (h * 0.015).clamp(8, 18).toDouble();
    final borderRadius = (w * 0.009).clamp(6, 14).toDouble();
    final headerFontSize = (w * 0.012).clamp(14, 22).toDouble();
    final labelFontSize = (w * 0.011).clamp(13, 18).toDouble();
    final textFontSize = (w * 0.010).clamp(12, 16).toDouble();
    final spacing = (h * 0.015).clamp(8, 16).toDouble();
    final messageFontSize = (w * 0.014).clamp(12, 18).toDouble();
    final messageHeight = (h * 0.07).clamp(45, 65).toDouble();
    final padding = (w * 0.012).clamp(8, 18).toDouble();
    final innerBorderRadius = (w * 0.008).clamp(5, 12).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.surfaceBorder, width: 1.3),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ?? Encabezado principal
          if (TrlIncomingVisibilityConfig.show['col2.encabezado'] ?? true)
            Center(
              child: Text(
                'Lugar de Transferencia',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: p.panelTitleBlue,
                  fontSize: headerFontSize,
                ),
              ),
            ),

          SizedBox(height: spacing),

          // ??? Etiqueta "TPG"
          if (TrlIncomingVisibilityConfig.show['col2.tpgEtiqueta'] ?? true)
            Padding(
              padding: EdgeInsets.only(left: paddingH * 0.3),
              child: Text(
                'TPG',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                  fontSize: labelFontSize,
                ),
              ),
            ),

          SizedBox(height: spacing * 0.6),

          // ?? Bloques Origen / Destino
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabelWithAsterisk(
                      context,
                      label: 'Origen',
                      fontSize: labelFontSize,
                    ),
                    SizedBox(height: spacing * 0.3),
                    _buildFieldBox(
                      manager.origenTrl ?? '',
                      p,
                      textFontSize,
                      paddingH,
                      paddingV,
                    ),
                  ],
                ),
              ),
              SizedBox(width: spacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabelWithAsterisk(
                      context,
                      label: 'Destino',
                      fontSize: labelFontSize,
                    ),
                    SizedBox(height: spacing * 0.3),
                    _buildFieldBox(
                      manager.destinoTrl ?? '',
                      p,
                      textFontSize,
                      paddingH,
                      paddingV,
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: spacing),

          // 🔵 Mensaje inferior (autoajustable, multilinea)
          if (TrlIncomingVisibilityConfig.show['col3.mensajeInferior'] ?? true)
            Container(
              constraints: BoxConstraints(
                minHeight: messageHeight * 0.8,
                maxHeight: messageHeight * 2.2,
              ),
              decoration: BoxDecoration(
                color: p.panelTitleBlue,
                borderRadius: BorderRadius.circular(innerBorderRadius),
              ),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(
                horizontal: padding * 0.6,
                vertical: 6,
              ),
              child: Text(
                manager.mensajeInferior?.isNotEmpty == true
                    ? manager.mensajeInferior!
                    : 'Procesando la transacción...',
                textAlign: TextAlign.center,
                softWrap: true,
                maxLines: null,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: messageFontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  height: 1.2,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// ?? Helper para mostrar etiqueta con asterisco rojo
  Widget _buildLabelWithAsterisk(
    BuildContext context, {
    required String label,
    required double fontSize,
  }) {
    final p = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: p.panelTitleBlue,
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
          ),
        ),
      ],
    );
  }

  /// ?? Bloque visual no editable (simula dropdown bloqueado)
  Widget _buildFieldBox(
    String value,
    dynamic p,
    double fontSize,
    double paddingH,
    double paddingV,
  ) {
    return Container(
      height: paddingV * 2.6,
      width: double.infinity,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: paddingH * 0.5),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: p.surfaceBorder, width: 1.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        value.isNotEmpty ? value : '',
        style: TextStyle(
          color: p.textPrimary,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
