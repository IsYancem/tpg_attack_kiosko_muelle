import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/config/incoming/dspcs_incoming_visibility_config.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

class Columna3MapaDspCs extends StatelessWidget {
  const Columna3MapaDspCs({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(DspCsIncomingVisibilityConfig.show['col3.visible'] ?? true)) {
      return const SizedBox.shrink();
    }

    final p = context.palette;
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;
    final manager = context.watch<AtkTransactionManager>();

    // 📏 Escalas adaptativas (versión compacta)
    final padding = (w * 0.012).clamp(8, 18).toDouble();
    final borderRadius = (w * 0.009).clamp(6, 14).toDouble();
    final innerBorderRadius = (w * 0.008).clamp(5, 12).toDouble();
    final spacing = (h * 0.012).clamp(6, 14).toDouble();
    final messageHeight = (h * 0.07).clamp(45, 65).toDouble();
    final messageFontSize = (w * 0.014).clamp(12, 18).toDouble();

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
          // 🗺️ Imagen del mapa o imagen de respaldo
          if (DspCsIncomingVisibilityConfig.show['col3.mapa'] ?? true)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: p.panelBg,
                  border: Border.all(color: p.surfaceBorder, width: 1.0),
                  borderRadius: BorderRadius.circular(innerBorderRadius),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/warningValoraTuVida.png',
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  colorBlendMode: BlendMode.modulate,
                  opacity: const AlwaysStoppedAnimation(0.85),
                ),
              ),
            ),

          SizedBox(height: spacing),

          // 🔵 Mensaje inferior (autoajustable, multilinea)
          if (DspCsIncomingVisibilityConfig.show['col3.mensajeInferior'] ??
              true)
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
}
