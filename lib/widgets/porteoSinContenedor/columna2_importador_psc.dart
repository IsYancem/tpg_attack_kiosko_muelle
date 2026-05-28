import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/config/incoming/psc_incoming_visibility_config.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/atk_info_panel.dart';

class Columna2ImportadorPsc extends StatelessWidget {
  const Columna2ImportadorPsc({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(PscIncomingVisibilityConfig.show['col2.visible'] ?? true)) {
      return const SizedBox.shrink();
    }

    final p = context.palette;
    final manager = context.watch<AtkTransactionManager>();

    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    final paddingH = (w * 0.015).clamp(8, 18).toDouble();
    final paddingV = (h * 0.015).clamp(8, 14).toDouble();
    final spacing = (h * 0.014).clamp(8, 16).toDouble();
    final borderRadius = (w * 0.009).clamp(6, 14).toDouble();
    final headerFontSize = (w * 0.012).clamp(14, 18).toDouble();
    final infoFontSize = (w * 0.010).clamp(13, 17).toDouble();
    final placaFontSize = (w * 0.020).clamp(24, 42).toDouble();

    final placa = manager.vehiculoPlaca;
    final pesoIngreso = manager.pesoActualBascula > 0
        ? manager.pesoActualBascula.toStringAsFixed(0)
        : manager.pesoIngreso;

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
          Center(
            child: Text(
              'DATOS DE PORTEO',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: p.panelTitleBlue,
                fontSize: headerFontSize,
              ),
            ),
          ),

          SizedBox(height: spacing * 1.8),

          _HighlightedValue(
            title: 'PLACA',
            value: placa,
            fontSize: placaFontSize,
            color: p.panelTitleBlue,
            borderRadius: borderRadius,
          ),

          SizedBox(height: spacing * 1.4),

          AtkInfoPanel(
            title: 'PESO INGRESO (kg)',
            value: pesoIngreso,
            fontSize: infoFontSize,
          ),

          const Spacer(),

          _PorteoInfoMessage(
            borderRadius: borderRadius,
          ),
        ],
      ),
    );
  }
}

class _HighlightedValue extends StatelessWidget {
  final String title;
  final String? value;
  final double fontSize;
  final Color color;
  final double borderRadius;

  const _HighlightedValue({
    required this.title,
    required this.value,
    required this.fontSize,
    required this.color,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cleanValue = value?.trim().isNotEmpty == true ? value!.trim() : '---';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: p.textSecondary,
              fontSize: fontSize * 0.34,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              cleanValue,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PorteoInfoMessage extends StatelessWidget {
  final double borderRadius;

  const _PorteoInfoMessage({
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: p.panelBg,
        border: Border.all(color: p.surfaceBorder, width: 1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Text(
        'Porteo sin contenedor',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: p.textSecondary,
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}