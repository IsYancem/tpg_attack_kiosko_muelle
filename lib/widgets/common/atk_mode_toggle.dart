import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

class AtkModeToggle extends StatelessWidget {
  final ValueChanged<bool> onChanged;
  final double scale;

  const AtkModeToggle({super.key, required this.onChanged, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isLight = Theme.of(context).brightness == Brightness.light;

    final size = 100.0 * scale;
    final iconSize = 50.0 * scale;

    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12 * scale),
          side: BorderSide(color: p.headerSubtitle.withValues(alpha:0.35)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12 * scale),
          onTap: () => onChanged(!isLight),
          child: Center(
            child: Icon(
              isLight ? Icons.wb_sunny_rounded : Icons.nightlight,
              size: iconSize,
              color: p.iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
