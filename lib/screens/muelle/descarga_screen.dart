import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/config/incoming/descarga_incoming_visibility_config.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/descarga/descarga_transaction_runner.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyTransaction/atkHeaderBar_transaction.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyTransaction/atkSubheaderBar_transaction.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/atkFooterBar_common.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/descarga_incoming/columna1_driver_descarga.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/descarga_incoming/columna2_importador_descarga.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/descarga_incoming/columna3_mapa_descarga.dart';

class DescargaScreen extends StatelessWidget {
  const DescargaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DescargaScreenBody();
  }
}

class _DescargaScreenBody extends StatefulWidget {
  const _DescargaScreenBody();

  @override
  State<_DescargaScreenBody> createState() => _DescargaScreenBodyState();
}

class _DescargaScreenBodyState extends State<_DescargaScreenBody>
    with TickerProviderStateMixin {
  late final DescargaTransactionRunner _runner;
  bool _runnerStarted = false;

  AppStateManager? _appManager;
  AtkTransactionManager? _manager;

  @override
  void initState() {
    super.initState();
    _runner = DescargaTransactionRunner();

    // ⚠️ La foto del chofer ya NO se carga aquí.
    // El runner la dispara en paralelo (_loadDriverPhoto, unawaited),
    // así evitamos pedir la misma foto dos veces para el mismo driverCedula.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_runnerStarted) return;

    _runnerStarted = true;

    _appManager = context.read<AppStateManager>();
    _manager = context.read<AtkTransactionManager>();

    _manager!.setManyWithoutNotify({
      'isLoading': true,
      'mensajeInferior': 'Procesando descarga...\nPor favor espere.',
    });

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      Future.microtask(() {
        if (!mounted) return;

        _runner.run(
          context: context,
          appManager: _appManager!,
          manager: _manager!,
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
          if (DescargaIncomingVisibilityConfig.show['header.titulo'] ?? true)
            Selector<AtkTransactionManager, int?>(
              selector: (_, m) => m.flowRemainingSeconds,
              builder: (context, flowRemaining, _) {
                final headerCountdownSeconds =
                    (DescargaIncomingVisibilityConfig
                                .show['header.countdown'] ??
                            true)
                        ? (flowRemaining ?? 300)
                        : 0;

                return AtkHeaderTransaction(
                  title: 'DESCARGA',
                  height: hHeader,
                  assetImagePath:
                      DescargaIncomingVisibilityConfig.show['header.logo'] ??
                              true
                          ? 'assets/images/tpg_logo.png'
                          : null,
                  initialCountdownSeconds: headerCountdownSeconds,
                  onModeChanged: (isLight) =>
                      context.read<AppStateManager>().setLight(isLight),
                );
              },
            ),

          if (DescargaIncomingVisibilityConfig
                  .show['subheader.textoDespacho'] ??
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

          if ((DescargaIncomingVisibilityConfig.show['col1.driver'] ?? true) ||
              (DescargaIncomingVisibilityConfig.show['col2.importador'] ??
                  true) ||
              (DescargaIncomingVisibilityConfig.show['col3.mapa'] ?? true))
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
                    if (DescargaIncomingVisibilityConfig.show['col1.driver'] ??
                        true)
                      const Expanded(
                        flex: 25,
                        child: Columna1DriverDescarga(),
                      ),

                    if ((DescargaIncomingVisibilityConfig.show['col1.driver'] ??
                            true) &&
                        ((DescargaIncomingVisibilityConfig
                                    .show['col2.importador'] ??
                                true) ||
                            (DescargaIncomingVisibilityConfig
                                    .show['col3.mapa'] ??
                                true)))
                      const SizedBox(width: 12),

                    if (DescargaIncomingVisibilityConfig
                            .show['col2.importador'] ??
                        true)
                      const Expanded(
                        flex: 45,
                        child: Columna2ImportadorDescarga(),
                      ),

                    if ((DescargaIncomingVisibilityConfig
                                .show['col2.importador'] ??
                            true) &&
                        (DescargaIncomingVisibilityConfig.show['col3.mapa'] ??
                            true))
                      const SizedBox(width: 12),

                    if (DescargaIncomingVisibilityConfig.show['col3.mapa'] ??
                        true)
                      const Expanded(
                        flex: 30,
                        child: Columna3MapaDescarga(),
                      ),
                  ],
                ),
              ),
            ),

          if (DescargaIncomingVisibilityConfig.show['footer.toggleTheme'] ??
              true)
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