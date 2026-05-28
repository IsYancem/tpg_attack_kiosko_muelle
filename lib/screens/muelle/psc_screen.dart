import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/config/incoming/psc_incoming_visibility_config.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/psc/psc_transaction_runner.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyTransaction/atkHeaderBar_transaction.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyTransaction/atkSubheaderBar_transaction.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/atkFooterBar_common.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/porteoSinContenedor/columna1_driver_psc.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/porteoSinContenedor/columna2_importador_psc.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/porteoSinContenedor/columna3_mapa_psc.dart';

class PorteoSinContenedor extends StatelessWidget {
  const PorteoSinContenedor({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PorteoSinContenedorBody();
  }
}

class _PorteoSinContenedorBody extends StatefulWidget {
  const _PorteoSinContenedorBody();

  @override
  State<_PorteoSinContenedorBody> createState() =>
      _PorteoSinContenedorBodyState();
}

class _PorteoSinContenedorBodyState extends State<_PorteoSinContenedorBody> {
  late final PscTransactionRunner _runner;
  bool _runnerStarted = false;

  @override
  void initState() {
    super.initState();
    _runner = PscTransactionRunner();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_runnerStarted) return;
    _runnerStarted = true;

    final appManager = context.read<AppStateManager>();
    final manager = context.read<AtkTransactionManager>();

    manager.setManyWithoutNotify({
      'isLoading': true,
      'mensajeInferior': 'Preparando porteo sin contenedor...',
      'pscRunning': true,
    });

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Future.microtask(() {
        if (!mounted) return;

        _runner.run(
          context: context,
          appManager: appManager,
          manager: manager,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = MediaQuery.sizeOf(context);

    final hHeader = size.height * 0.15;
    final hSubHeader = size.height * 0.08;
    final hBody = size.height * 0.70;
    final hFooter = size.height * 0.07;

    return Scaffold(
      backgroundColor: p.bg,
      body: Column(
        children: [
          if (PscIncomingVisibilityConfig.show['header.titulo'] ?? true)
            Selector<AtkTransactionManager, int?>(
              selector: (_, m) => m.flowRemainingSeconds,
              builder: (context, flowRemaining, _) {
                final headerCountdownSeconds =
                    (PscIncomingVisibilityConfig.show['header.countdown'] ??
                            true)
                        ? (flowRemaining ?? 300)
                        : 0;

                return AtkHeaderTransaction(
                  title: 'PORTEO SIN CONTENEDOR',
                  height: hHeader,
                  assetImagePath:
                      PscIncomingVisibilityConfig.show['header.logo'] ?? true
                          ? 'assets/images/tpg_logo.png'
                          : null,
                  initialCountdownSeconds: headerCountdownSeconds,
                  onModeChanged: (isLight) =>
                      context.read<AppStateManager>().setLight(isLight),
                );
              },
            ),
          if (PscIncomingVisibilityConfig.show['subheader.textoDespacho'] ??
              true)
            Selector<AtkTransactionManager, String?>(
              selector: (_, m) => m.driverName,
              builder: (context, driverName, _) {
                return AtkSubHeaderBarTransaction(
                  height: hSubHeader,
                  personName: driverName ?? '',
                  flowType: FlowType.entrada,
                );
              },
            ),
          if ((PscIncomingVisibilityConfig.show['col1.driver'] ?? true) ||
              (PscIncomingVisibilityConfig.show['col2.importador'] ?? true) ||
              (PscIncomingVisibilityConfig.show['col3.mapa'] ?? true))
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
                    if (PscIncomingVisibilityConfig.show['col1.driver'] ??
                        true)
                      const Expanded(
                        flex: 25,
                        child: Columna1DriverPsc(),
                      ),
                    if ((PscIncomingVisibilityConfig.show['col1.driver'] ??
                            true) &&
                        ((PscIncomingVisibilityConfig.show['col2.importador'] ??
                                true) ||
                            (PscIncomingVisibilityConfig.show['col3.mapa'] ??
                                true)))
                      const SizedBox(width: 12),
                    if (PscIncomingVisibilityConfig.show['col2.importador'] ??
                        true)
                      const Expanded(
                        flex: 45,
                        child: Columna2ImportadorPsc(),
                      ),
                    if ((PscIncomingVisibilityConfig.show['col2.importador'] ??
                            true) &&
                        (PscIncomingVisibilityConfig.show['col3.mapa'] ??
                            true))
                      const SizedBox(width: 12),
                    if (PscIncomingVisibilityConfig.show['col3.mapa'] ?? true)
                      const Expanded(
                        flex: 30,
                        child: Columna3MapaPsc(),
                      ),
                  ],
                ),
              ),
            ),
          if (PscIncomingVisibilityConfig.show['footer.toggleTheme'] ?? true)
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