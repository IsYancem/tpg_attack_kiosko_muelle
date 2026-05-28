import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/config/incoming/descarga_incoming_visibility_config.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/atk_info_panel.dart';

class Columna2ImportadorDescarga extends StatelessWidget {
  const Columna2ImportadorDescarga({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(DescargaIncomingVisibilityConfig.show['col2.visible'] ?? true)) {
      return const SizedBox.shrink();
    }

    final p = context.palette;
    final manager = context.watch<AtkTransactionManager>();

    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    final paddingH = (w * 0.015).clamp(8, 18).toDouble();
    final paddingV = (h * 0.015).clamp(8, 14).toDouble();
    final spacing = (h * 0.012).clamp(6, 12).toDouble();
    final borderRadius = (w * 0.009).clamp(6, 14).toDouble();
    final headerFontSize = (w * 0.012).clamp(14, 18).toDouble();
    final infoFontSize = (w * 0.009).clamp(12, 16).toDouble();
    final highlightFontSize = (w * 0.020).clamp(24, 42).toDouble();

    final pesoIngreso = manager.pesoActualBascula;

    final pesoPorteo =
        double.tryParse(manager.pesoPorteo?.toString() ?? '') ?? 0;

    final tara = double.tryParse(manager.pesoTara?.toString() ?? '') ?? 0;

    final pesoCarga = pesoIngreso - pesoPorteo - tara;

    final pesoCargaTexto = pesoCarga > 0 ? pesoCarga.toStringAsFixed(0) : '0';

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
              'DATOS DE DESCARGA',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: p.panelTitleBlue,
                fontSize: headerFontSize,
              ),
            ),
          ),

          SizedBox(height: spacing * 1.5),

          _HighlightedValue(
            title: '',
            value: manager.vehiculoPlaca,
            fontSize: highlightFontSize * 0.60,
            color: p.panelTitleBlue,
            borderRadius: borderRadius,
          ),

          SizedBox(height: spacing),

          _HighlightedValue(
            title: '',
            value: manager.contenedor,
            fontSize: highlightFontSize * 0.60,
            color: p.panelTitleBlue,
            borderRadius: borderRadius,
          ),

          SizedBox(height: spacing),

          AtkInfoPanel(
            title: 'TARA (kg)',
            value: manager.pesoTara,
            fontSize: infoFontSize,
          ),

          SizedBox(height: spacing),

          AtkInfoPanel(
            title: 'PESO INGRESO (kg)',
            value: manager.pesoActualBascula.toStringAsFixed(0),
            fontSize: infoFontSize,
          ),

          AtkInfoPanel(
            title: 'PESO PORTEO (kg)',
            value: manager.pesoPorteo,
            fontSize: infoFontSize,
          ),

          AtkInfoPanel(
            title: 'PESO CARGA (kg)',
            value: pesoCargaTexto,
            fontSize: infoFontSize,
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
    final cleanValue = value?.trim().isNotEmpty == true ? value!.trim() : '---';

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          cleanValue,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: TextStyle(
            color: color,
            fontSize: fontSize * 1.18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
