// lib/screens/res_incoming/res_incoming_screen.dart
// Autor: Abraham Yance
// Fecha: 2025-12-19
// Pantalla RES (Recepción/Reserva)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/config/incoming/res_incoming_visibility_config.dart.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/res/res_transaction_runner.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/staapisac_api_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyTransaction/atkHeaderBar_transaction.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyTransaction/atkSubheaderBar_transaction.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/atkFooterBar_common.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/res_incoming/columna1_driver_res.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/res_incoming/columna2_informacion_res.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/res_incoming/columna3_mapa_res.dart';

class ResIncomingScreen extends StatelessWidget {
  const ResIncomingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ResIncomingScreenBody();
  }
}

class _ResIncomingScreenBody extends StatefulWidget {
  const _ResIncomingScreenBody();

  @override
  State<_ResIncomingScreenBody> createState() => _ResIncomingScreenBodyState();
}

class _ResIncomingScreenBodyState extends State<_ResIncomingScreenBody>
    with TickerProviderStateMixin {
  ResTransactionRunner? _runner;
  bool _runnerExecuting = false;

  @override
  void initState() {
    super.initState();
    _runner = ResTransactionRunner();

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

  void _executeRunner() {
    // ignore: avoid_print
    print(
      '📍 [RES_SCREEN] _executeRunner() - ${DateTime.now().toIso8601String()}',
    );

    if (_runnerExecuting) {
      // ignore: avoid_print
      print('⚠️ [RES_SCREEN] Runner ya ejecutándose, rechazando duplicado');
      return;
    }

    _runnerExecuting = true;

    final appManager = context.read<AppStateManager>();
    final manager = context.read<AtkTransactionManager>();

    manager.setManyWithoutNotify({
      'isLoading': true,
      'mensajeInferior': 'Procesando transacción RES...\nPor favor espere.',
    });
    manager.notifyListeners();

    _runner!
        .run(context: context, appManager: appManager, manager: manager)
        .then((_) {
          // ignore: avoid_print
          print('✅ [RES_SCREEN] Runner RES completado');
          _runnerExecuting = false;
        })
        .catchError((e, st) {
          // ignore: avoid_print
          print('❌ [RES_SCREEN] Error en runner RES: $e\n$st');
          _runnerExecuting = false;
          manager.setManyWithoutNotify({
            'isLoading': false,
            'mensajeInferior': 'Error RES: $e',
          });
          manager.notifyListeners();
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
          if (ResIncomingVisibilityConfig.show['header.titulo'] ?? true)
            Selector<AtkTransactionManager, int?>(
              selector: (_, m) => m.flowRemainingSeconds,
              builder: (context, flowRemaining, _) {
                final headerCountdownSeconds =
                    (ResIncomingVisibilityConfig.show['header.countdown'] ??
                        true)
                    ? (flowRemaining ?? 300)
                    : 0;
                return AtkHeaderTransaction(
                  title: 'SERVICIO DE RES',
                  height: hHeader,
                  assetImagePath:
                      ResIncomingVisibilityConfig.show['header.logo'] ?? true
                      ? 'assets/images/tpg_logo.png'
                      : null,
                  initialCountdownSeconds: headerCountdownSeconds,
                  onModeChanged: (isLight) =>
                      context.read<AppStateManager>().setLight(isLight),
                );
              },
            ),

          if (ResIncomingVisibilityConfig.show['subheader.textoDespacho'] ??
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

          SizedBox(
            height: hBody,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (ResIncomingVisibilityConfig.show['col1.visible'] ?? true)
                    const Expanded(flex: 25, child: Columna1DriverRes()),
                  if ((ResIncomingVisibilityConfig.show['col1.visible'] ??
                          true) &&
                      (ResIncomingVisibilityConfig.show['col2.visible'] ??
                          true))
                    const SizedBox(width: 12),

                  if (ResIncomingVisibilityConfig.show['col2.visible'] ?? true)
                    const Expanded(flex: 45, child: Columna2InformacionRes()),

                  if ((ResIncomingVisibilityConfig.show['col2.visible'] ??
                          true) &&
                      (ResIncomingVisibilityConfig.show['col3.visible'] ??
                          true))
                    const SizedBox(width: 12),

                  if (ResIncomingVisibilityConfig.show['col3.visible'] ?? true)
                    const Expanded(flex: 30, child: Columna3MapaRes()),
                ],
              ),
            ),
          ),

          if (ResIncomingVisibilityConfig.show['footer.visible'] ?? true)
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
