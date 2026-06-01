// lib/screens/muelle/expDoble_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/config/incoming/exp_incoming_visibility_config.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/ocrScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/expDoble/exp_doble_transaction_runner.dart';
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

class ExpDobleScreen extends StatelessWidget {
  const ExpDobleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ExpDobleScreenBody();
  }
}

class _ExpDobleScreenBody extends StatefulWidget {
  const _ExpDobleScreenBody();

  @override
  State<_ExpDobleScreenBody> createState() => _ExpDobleScreenBodyState();
}

class _ExpDobleScreenBodyState extends State<_ExpDobleScreenBody>
    with TickerProviderStateMixin {
  bool _runnerStarted = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final appState = context.read<AppStateManager>();
      final txn = context.read<AtkTransactionManager>();

      txn.setManyWithoutNotify({
        'isLoading': true,
        'expDobleScreenReady': true,
        'mensajeInferior':
            'Transacción de salida confirmada.\nProcesando doble exportación...',
      });

      if (mounted) setState(() {});

      // Cargar foto del conductor (no bloquea el flujo).
      _cargarFotoConductor(appState, txn);

      // Lanzar el flujo doble completo una sola vez.
      await _lanzarRunner(appState, txn);
    });
  }

  Future<void> _cargarFotoConductor(
    AppStateManager appState,
    AtkTransactionManager txn,
  ) async {
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
      await LogService.instance.logError('EXP_DOBLE_LOAD_PHOTO_FAIL', e, st);
    }
  }

  Future<void> _lanzarRunner(
    AppStateManager appState,
    AtkTransactionManager txn,
  ) async {
    if (_runnerStarted) return;
    _runnerStarted = true;

    final runner = ExpDobleTransactionRunner();

    await runner.run(
      context: context,
      appManager: appState,
      manager: txn,
      onFinished: () async {
        if (!mounted) return;

        // 1) Estado final estable (NO reseteamos todavía: resetear aquí
        //    repinta esta pantalla con datos vacíos y causa el salto brusco).
        txn.setMany({
          'isLoading': true,
          'mensajeInferior':
              'Doble exportación completada.\nRegresando al escáner...',
        });

        // 2) Pequeña pausa para que la pantalla final se perciba, no un corte seco.
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;

        // 3) Navegar con transición suave (fade largo y con curva).
        await Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const OcrScannerScreen(),
            transitionDuration: const Duration(milliseconds: 450),
            reverseTransitionDuration: const Duration(milliseconds: 300),
            transitionsBuilder: (_, animation, __, child) {
              final curved = CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              );
              return FadeTransition(opacity: curved, child: child);
            },
          ),
          (route) => false,
        );

        // 4) Reset DESPUÉS de navegar: la pantalla vieja ya no es visible,
        //    así que el repintado por notifyListeners no se nota.
        //    OcrScannerScreen.initState ya hace resetOcr/resetDriver, pero
        //    dejamos el manager limpio para el siguiente ciclo.
        txn.resetAll();
      },
    );
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
          if (ExpIncomingVisibilityConfig.show['header.titulo'] ?? true)
            Selector<AtkTransactionManager, int?>(
              selector: (_, m) => m.flowRemainingSeconds,
              builder: (context, flowRemaining, _) {
                return AtkHeaderTransaction(
                  title: 'DOBLE EXPORTACIÓN FULL',
                  height: hHeader,
                  assetImagePath:
                      ExpIncomingVisibilityConfig.show['header.logo'] ?? true
                      ? 'assets/images/tpg_logo.png'
                      : null,
                  initialCountdownSeconds: flowRemaining ?? 300,
                  onModeChanged: (isLight) =>
                      context.read<AppStateManager>().setLight(isLight),
                );
              },
            ),

          // Subheader: muestra el conductor y, ahora, el contenedor activo.
          if (ExpIncomingVisibilityConfig.show['subheader.textoDespacho'] ??
              true)
            Selector<AtkTransactionManager, String?>(
              selector: (_, m) {
                final activo =
                    (m.get('expDobleContenedorActivo') as String?) ?? '';
                final driver = m.driverName ?? '';
                return activo.isEmpty ? driver : '$driver — $activo';
              },
              builder: (context, personName, _) {
                return AtkSubHeaderBarTransaction(
                  height: hSubHeader,
                  personName: personName ?? '',
                  flowType: FlowType.entrada,
                );
              },
            ),

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
