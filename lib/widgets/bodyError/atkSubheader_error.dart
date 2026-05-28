import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/utils/format/fecha_utils.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

class AtkSubHeaderBarError extends StatelessWidget {
  final double height;
  final int remainingSeconds;
  final DateTime now; // ← NUEVO: viene del padre

  const AtkSubHeaderBarError({
    super.key,
    required this.height,
    required this.remainingSeconds,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const base = 80.0;
    final s = (height / base).clamp(0.6, 2.0);

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Card(
          color: p.surface,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32 * s),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ⏳ Countdown: viene del padre
                Text(
                  "Redirigiendo en $remainingSeconds s",
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontSize: 20 * s,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // 📆 Fecha: también viene “driven” por el rebuild del padre
                Container(
                  padding: EdgeInsets.symmetric(vertical: 6 * s),
                  child: Text(
                    now.toFechaLargaEs(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 28 * s,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
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
