import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/config/incoming/exp_incoming_visibility_config.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/expRepesaje/exp_repesaje_transaction_runner.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/staapisac_api_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyTransaction/atkHeaderBar_transaction.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyTransaction/atkSubheaderBar_transaction.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/atkFooterBar_common.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/exp_incoming/columna1_driver_exp.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/exp_incoming/columna2_exportador_exp.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/exp_incoming/columna3_mapa_exp.dart';

class ExpRepesajeScreen extends StatelessWidget {
  const ExpRepesajeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ExpRepesajeScreenBody();
  }
}

class _ExpRepesajeScreenBody extends StatefulWidget {
  const _ExpRepesajeScreenBody();

  @override
  State<_ExpRepesajeScreenBody> createState() => _ExpRepesajeScreenBodyState();
}

class _ExpRepesajeScreenBodyState extends State<_ExpRepesajeScreenBody>
    with TickerProviderStateMixin {
  ExpRespesajeTransactionRunner? _runner;
  bool _runnerExecuting = false; // ⬅️ Flag atómico

  @override
  void initState() {
    super.initState();
    _runner = ExpRespesajeTransactionRunner();

    // ✅ Ejecutar UNA SOLA VEZ después del primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appState = context.read<AppStateManager>();
      final txn = context.read<AtkTransactionManager>();

      _executeRunner();

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

  // exp_incoming_screen.dart
  void _executeRunner() {
    print(
      '📍 [EXP_SCREEN] _executeRunner() llamado - ${DateTime.now().toIso8601String()}',
    );

    if (_runnerExecuting) {
      print(
        '⚠️ [EXP_SCREEN] Runner ya está ejecutándose, RECHAZANDO llamada duplicada',
      );
      return;
    }

    print('🚀 [EXP_SCREEN] Iniciando runner (flag=false→true)');
    _runnerExecuting = true;

    final appManager = context.read<AppStateManager>();
    final manager = context.read<AtkTransactionManager>();

    manager.setManyWithoutNotify({
      'isLoading': true,
      'mensajeInferior': 'Procesando transacción EXP...\nPor favor espere.',
    });

    _runner!
        .run(context: context, appManager: appManager, manager: manager)
        .then((_) {
          print('✅ [EXP_SCREEN] Runner completado exitosamente');
          _runnerExecuting = false;
        })
        .catchError((e, st) {
          print('❌ [EXP_SCREEN] Error en runner: $e');
          _runnerExecuting = false;
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
          // Header con Selector
          if (ExpIncomingVisibilityConfig.show['header.titulo'] ?? true)
            Selector<AtkTransactionManager, int?>(
              selector: (_, m) => m.flowRemainingSeconds,
              builder: (context, flowRemaining, _) {
                final headerCountdownSeconds =
                    (ExpIncomingVisibilityConfig.show['header.countdown'] ??
                        true)
                    ? (flowRemaining ?? 300)
                    : 0;
                return AtkHeaderTransaction(
                  title: 'REPESAJE EXPORTACIÓN FULL',
                  height: hHeader,
                  assetImagePath:
                      ExpIncomingVisibilityConfig.show['header.logo'] ?? true
                      ? 'assets/images/tpg_logo.png'
                      : null,
                  initialCountdownSeconds: headerCountdownSeconds,
                  onModeChanged: (isLight) =>
                      context.read<AppStateManager>().setLight(isLight),
                );
              },
            ),

          // Subheader con Selector
          if (ExpIncomingVisibilityConfig.show['subheader.textoDespacho'] ??
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
          if ((ExpIncomingVisibilityConfig.show['col1.driver'] ?? true) ||
              (ExpIncomingVisibilityConfig.show['col2.importador'] ?? true) ||
              (ExpIncomingVisibilityConfig.show['col3.mapa'] ?? true))
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
                    if (ExpIncomingVisibilityConfig.show['col1.driver'] ?? true)
                      const Expanded(flex: 25, child: Columna1DriverExp()),
                    if ((ExpIncomingVisibilityConfig.show['col1.driver'] ??
                            true) &&
                        ((ExpIncomingVisibilityConfig.show['col2.importador'] ??
                                true) ||
                            (ExpIncomingVisibilityConfig.show['col3.mapa'] ??
                                true)))
                      const SizedBox(width: 12),
                    if (ExpIncomingVisibilityConfig.show['col2.importador'] ??
                        true)
                      const Expanded(flex: 45, child: Columna2ExportadorExp()),
                    if ((ExpIncomingVisibilityConfig.show['col2.importador'] ??
                            true) &&
                        (ExpIncomingVisibilityConfig.show['col3.mapa'] ?? true))
                      const SizedBox(width: 12),
                    if (ExpIncomingVisibilityConfig.show['col3.mapa'] ?? true)
                      const Expanded(flex: 30, child: Columna3MapaExp()),
                  ],
                ),
              ),
            ),

          // Footer
          if (ExpIncomingVisibilityConfig.show['footer.toggleTheme'] ?? true)
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
