import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/config/incoming/Trl_incoming_visibility_config.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyTransaction/atkHeaderBar_transaction.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyTransaction/atkSubheaderBar_transaction.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/atkFooterBar_common.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/trl_incoming/columna1_driver_trl.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/trl_incoming/columna2_importador_trl.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/trl_incoming/columna3_contendores_trl.dart';

class TrlIncomingScreen extends StatelessWidget {
  const TrlIncomingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AtkTransactionManager(),
      child: const _TrlIncomingScreenBody(),
    );
  }
}

class _TrlIncomingScreenBody extends StatelessWidget {
  const _TrlIncomingScreenBody();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final manager = context.watch<AtkTransactionManager>();
    final size = MediaQuery.sizeOf(context);

    final hHeader = size.height * 0.15;
    final hSubHeader = size.height * 0.08;
    final hBody = size.height * 0.70;
    final hFooter = size.height * 0.07;

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          // HEADER
          if (TrlIncomingVisibilityConfig.show['header.titulo'] ?? true)
            AtkHeaderTransaction(
              title: 'DESPACHO DE CARGA SUELTA',
              height: hHeader,
              assetImagePath:
                  TrlIncomingVisibilityConfig.show['header.logo'] ?? true
                  ? 'assets/images/tpg_logo.png'
                  : null,
              initialCountdownSeconds:
                  TrlIncomingVisibilityConfig.show['header.countdown'] ?? true
                  ? 300
                  : 0,
              onModeChanged: (isLight) =>
                  context.read<AppStateManager>().setLight(isLight),
            ),

          // SUBHEADER
          if (TrlIncomingVisibilityConfig.show['subheader.textoDespacho'] ??
              true)
            AtkSubHeaderBarTransaction(
              height: hSubHeader,
              personName: manager.driverName ?? '',
              flowType: FlowType.entrada,
              // : FlowType.salida,
            ),

          // BODY — 3 columnas
          if ((TrlIncomingVisibilityConfig.show['col1.driver'] ?? true) ||
              (TrlIncomingVisibilityConfig.show['col2.importador'] ?? true) ||
              (TrlIncomingVisibilityConfig.show['col3.mapa'] ?? true))
            SizedBox(
              height: hBody,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (TrlIncomingVisibilityConfig.show['col1.driver'] ?? true)
                      const Expanded(flex: 25, child: Columna1DriverTrl()),
                    if ((TrlIncomingVisibilityConfig.show['col1.driver'] ??
                            true) &&
                        ((TrlIncomingVisibilityConfig.show['col2.importador'] ??
                                true) ||
                            (TrlIncomingVisibilityConfig.show['col3.mapa'] ??
                                true)))
                      const SizedBox(width: 12),
                    if (TrlIncomingVisibilityConfig.show['col2.importador'] ??
                        true)
                      const Expanded(flex: 45, child: Columna2TransferenciaTrl()),
                    if ((TrlIncomingVisibilityConfig.show['col2.importador'] ??
                            true) &&
                        (TrlIncomingVisibilityConfig.show['col3.mapa'] ?? true))
                      const SizedBox(width: 12),
                    if (TrlIncomingVisibilityConfig.show['col3.mapa'] ?? true)
                      const Expanded(flex: 30, child: Columna3ContenedoresTrl()),
                  ],
                ),
              ),
            ),

          // FOOTER
          if (TrlIncomingVisibilityConfig.show['footer.toggleTheme'] ?? true)
            AtkFooterBarCommon(
              height: hFooter,
              onModeChanged: (isLight) =>
                  context.read<AppStateManager>().setLight(isLight),
            ),
        ],
      ),
    );
  }
}
