// lib/screens/exp_vacios_incoming/exp_vacios_incoming_screen.dart
// Autor: Abraham Yance
// Fecha: 2025-12-16
// Pantalla de Exportaciones Vacías (similar a Exportación Full, sin mostrar sellos)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/exm/exm_transaction_runner.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/staapisac_api_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyTransaction/atkHeaderBar_transaction.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyTransaction/atkSubheaderBar_transaction.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/atkFooterBar_common.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/exm_incoming/columna1_driver_exm.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/exm_incoming/columna2_exportador_exm.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/exm_incoming/columna3_mapa_exm.dart';

class ExmIncomingScreen extends StatelessWidget {
  const ExmIncomingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ExmIncomingScreenBody();
  }
}

class _ExmIncomingScreenBody extends StatefulWidget {
  const _ExmIncomingScreenBody();

  @override
  State<_ExmIncomingScreenBody> createState() => _ExmIncomingScreenBodyState();
}

class _ExmIncomingScreenBodyState extends State<_ExmIncomingScreenBody>
    with TickerProviderStateMixin {
  ExmTransactionRunner? _runner; // Cambiar tipo
  bool _runnerExecuting = false;

  @override
  void initState() {
    super.initState();
    _runner = ExmTransactionRunner(); 

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
        LogService.instance.logError('EXP_LOAD_PHOTO_FAIL', e, st);
        if (!mounted) return;
      }
    });
  }

  void _executeRunner() {
    if (_runnerExecuting) return;
    _runnerExecuting = true;

    final appManager = context.read<AppStateManager>();
    final manager = context.read<AtkTransactionManager>();

    manager.setManyWithoutNotify({
      'isLoading': true,
      'mensajeInferior':
          'Procesando transacción EXP VACÍOS...\nPor favor espere.',
    });

    _runner!
        .run(context: context, appManager: appManager, manager: manager)
        .then((_) {
          print('✅ [EXM_SCREEN] Runner completado exitosamente');
          _runnerExecuting = false;
        })
        .catchError((e, st) {
          print('❌ [EXM_SCREEN] Error en runner: $e');
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
          // HEADER
          Selector<AtkTransactionManager, int?>(
            selector: (_, m) => m.flowRemainingSeconds,
            builder: (context, flowRemaining, _) {
              return AtkHeaderTransaction(
                title: 'EXPORTACIÓN VACÍOS',
                height: hHeader,
                assetImagePath: 'assets/images/tpg_logo.png',
                initialCountdownSeconds: flowRemaining ?? 300,
                onModeChanged: (isLight) =>
                    context.read<AppStateManager>().setLight(isLight),
              );
            },
          ),

          // SUBHEADER
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

          // BODY
          SizedBox(
            height: hBody,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(flex: 25, child: Columna1DriverExm()),
                  const SizedBox(width: 12),
                  const Expanded(flex: 45, child: Columna2ExportadorExm()),
                  const SizedBox(width: 12),
                  const Expanded(flex: 30, child: Columna3MapaExm()),
                ],
              ),
            ),
          ),

          // FOOTER
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
