// lib/screens/dspcs_incoming/dspcs_incoming_screen.dart
// OPTIMIZADO 2025-12-09 - Mismo patrón que DSP
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/config/incoming/dspcs_incoming_visibility_config.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/dspcs/dspcs_transaction_runner.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/staapisac_api_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyTransaction/atkHeaderBar_transaction.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyTransaction/atkSubheaderBar_transaction.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/atkFooterBar_common.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/dspcs_incoming/columna1_driver_dspcs.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/dspcs_incoming/columna2_importador_dspcs.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/dspcs_incoming/columna3_mapa_dspcs.dart';

class DspCsIncomingScreen extends StatelessWidget {
  const DspCsIncomingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _DspCsIncomingScreenBody();
  }
}

class _DspCsIncomingScreenBody extends StatefulWidget {
  const _DspCsIncomingScreenBody();

  @override
  State<_DspCsIncomingScreenBody> createState() =>
      _DspCsIncomingScreenBodyState();
}

class _DspCsIncomingScreenBodyState extends State<_DspCsIncomingScreenBody>
    with TickerProviderStateMixin {
  DspCsTransactionRunner? _runner;
  bool _runnerStarted = false;

  // ✅ Cache de managers
  AppStateManager? _appManager;
  AtkTransactionManager? _manager;

  @override
  void initState() {
    super.initState();
    _runner = DspCsTransactionRunner();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appState = context.read<AppStateManager>();
      final txn = context.read<AtkTransactionManager>();

      // 1) Cargar foto luego (ya con cédula correcta desde init)
      final id = (txn.driverCedula ?? '').trim();
      if (id.isEmpty) return;

      final sta = StaapisacApiService();
      try {
        final imgB64 = await sta.getFotoChoferBase64(
          appState: appState,
          choferId: id,
        );
        if (!mounted) return;

        if (imgB64 != null && imgB64.isNotEmpty) {
          txn.setDriverPhotoUrl(imgB64);
        }
      } catch (e, st) {
        await LogService.instance.logError('EXP_LOAD_PHOTO_FAIL', e, st);
        if (!mounted) return;
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_runnerStarted) {
      _runnerStarted = true;

      // ✅ Cache de managers (una sola vez)
      _appManager = context.read<AppStateManager>();
      _manager = context.read<AtkTransactionManager>();

      // ✅ Setear loading SIN notificar (UI aún no lista)
      _manager!.setManyWithoutNotify({
        'isLoading': true,
        'mensajeInferior':
            'Procesando transacción DSP-CS...\nPor favor espere.',
      });

      // ✅ Iniciar runner DESPUÉS del primer frame
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        // Ejecutar en siguiente ciclo
        Future.microtask(() {
          if (!mounted) return;
          _runner!.run(
            context: context,
            appManager: _appManager!,
            manager: _manager!,
          );
        });
      });
    }
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
          // Header con Selector (solo rebuild cuando cambia countdown)
          if (DspCsIncomingVisibilityConfig.show['header.titulo'] ?? true)
            Selector<AtkTransactionManager, int?>(
              selector: (_, m) => m.flowRemainingSeconds,
              builder: (context, flowRemaining, _) {
                final headerCountdownSeconds =
                    (DspCsIncomingVisibilityConfig.show['header.countdown'] ??
                        true)
                    ? (flowRemaining ?? 300)
                    : 0;
                return AtkHeaderTransaction(
                  title: 'DESPACHO DE CARGA SUELTA',
                  height: hHeader,
                  assetImagePath:
                      DspCsIncomingVisibilityConfig.show['header.logo'] ?? true
                      ? 'assets/images/tpg_logo.png'
                      : null,
                  initialCountdownSeconds: headerCountdownSeconds,
                  onModeChanged: (isLight) =>
                      context.read<AppStateManager>().setLight(isLight),
                );
              },
            ),

          // Subheader con Selector (solo rebuild cuando cambia driverName)
          if (DspCsIncomingVisibilityConfig.show['subheader.textoDespacho'] ??
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

          // Body
          if ((DspCsIncomingVisibilityConfig.show['col1.driver'] ?? true) ||
              (DspCsIncomingVisibilityConfig.show['col2.importador'] ?? true) ||
              (DspCsIncomingVisibilityConfig.show['col3.mapa'] ?? true))
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
                    if (DspCsIncomingVisibilityConfig.show['col1.driver'] ??
                        true)
                      const Expanded(flex: 25, child: Columna1DriverDspCs()),
                    if ((DspCsIncomingVisibilityConfig.show['col1.driver'] ??
                            true) &&
                        ((DspCsIncomingVisibilityConfig
                                    .show['col2.importador'] ??
                                true) ||
                            (DspCsIncomingVisibilityConfig.show['col3.mapa'] ??
                                true)))
                      const SizedBox(width: 12),
                    if (DspCsIncomingVisibilityConfig.show['col2.importador'] ??
                        true)
                      const Expanded(
                        flex: 45,
                        child: Columna2ImportadorDspCs(),
                      ),
                    if ((DspCsIncomingVisibilityConfig
                                .show['col2.importador'] ??
                            true) &&
                        (DspCsIncomingVisibilityConfig.show['col3.mapa'] ??
                            true))
                      const SizedBox(width: 12),
                    if (DspCsIncomingVisibilityConfig.show['col3.mapa'] ?? true)
                      const Expanded(flex: 30, child: Columna3MapaDspCs()),
                  ],
                ),
              ),
            ),

          // Footer
          if (DspCsIncomingVisibilityConfig.show['footer.toggleTheme'] ?? true)
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
