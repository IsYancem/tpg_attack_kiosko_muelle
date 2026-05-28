import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

class AtkDetailBarError extends StatelessWidget {
  final double height;
  final String message;

  const AtkDetailBarError({
    super.key,
    required this.height,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    const base = 80.0;
    final s = (height / base).clamp(0.6, 2.0);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.all(12 * s),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade700,
              size: 40 * s, // 🔴 icono más grande
            ),
            const SizedBox(height: 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30 * s,
                fontWeight: FontWeight.bold,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 32 * s,
              ),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Entendido",
                style: TextStyle(
                  fontSize: 18 * s,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "Presione el intercomunicador",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14 * s,
                color: p.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
