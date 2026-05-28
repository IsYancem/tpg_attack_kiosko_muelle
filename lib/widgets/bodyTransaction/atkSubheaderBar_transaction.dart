import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

enum FlowType { entrada, salida }

class AtkSubHeaderBarTransaction extends StatelessWidget {
  final double height;
  final String personName;
  final FlowType flowType;

  const AtkSubHeaderBarTransaction({
    super.key,
    required this.height,
    required this.personName,
    required this.flowType,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const green = Color(0xFF22C55E);
    const red = Color(0xFFE53935);

    final isEntrada = flowType == FlowType.entrada;
    final badgeColor = isEntrada ? green : red;

    // escalar tipografías según altura base 80
    const base = 80.0;
    final s = (height / base).clamp(0.6, 2.0);

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
        ),
        child: Card(
          color: p.surface, 
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32 * s),
            child: Row(
              children: [
                // Nombre a la izquierda
                Expanded(
                  child: Text(
                    personName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 45 * s,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                // Estado a la derecha (ENTRADA/SALIDA)
                Container(
                  padding: EdgeInsets.symmetric(
                    vertical: 6 * s,
                    horizontal: 14 * s,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha:0.12),
                    borderRadius: BorderRadius.circular(10 * s),
                    border: Border.all(color: badgeColor.withValues(alpha:0.45)),
                  ),
                  child: Text(
                    isEntrada ? 'ENTRADA' : 'SALIDA',
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 28 * s,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
