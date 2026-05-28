// lib/widgets/common/atk_info_panel.dart
// Autor: Abraham Yance
// Widget informativo reutilizable (versión responsive corregida)
// Fecha: 2025-11-08

import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

class AtkInfoPanel extends StatelessWidget {
  final String title;
  final String? value;

  /// Estos valores pueden ser sobreescritos, pero se escalan automáticamente
  final double? fontSize;
  final double? height;
  final EdgeInsetsGeometry? margin;

  const AtkInfoPanel({
    super.key,
    required this.title,
    required this.value,
    this.fontSize,
    this.height,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    // 🔢 Escalas proporcionales con conversión segura a double
    final titleFontSize = (fontSize ?? (w * 0.014).clamp(14, 24)).toDouble();
    final valueFontSize = (titleFontSize * 0.95).toDouble();
    final containerHeight = (height ?? (h * 0.033).clamp(42, 68)).toDouble();
    final spacing = (h * 0.007).clamp(4, 10).toDouble();
    final paddingH = (w * 0.015).clamp(8, 24).toDouble();
    final borderRadius = (w * 0.008).clamp(6, 14).toDouble();
    final marginBottom = (h * 0.015).clamp(8, 20).toDouble();

    return Padding(
      
      padding: margin ?? EdgeInsets.only(bottom: marginBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🏷️ Etiqueta superior
          Text(
            title,
            style: TextStyle(
              color: p.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: titleFontSize,
              letterSpacing: 0.4,
            ),
          ),
          SizedBox(height: spacing),

          // 📦 Contenedor de valor
          Container(
            height: containerHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: p.surfaceBorder.withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: p.surfaceBorder, width: 1.2),
            ),
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.symmetric(horizontal: paddingH),
            child: Text(
              (value?.trim().isNotEmpty ?? false) ? value! : '—',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: valueFontSize,
                color: p.textPrimary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
