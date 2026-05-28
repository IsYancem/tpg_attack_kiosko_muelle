import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/ocrScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/rfidScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart'; // ✅ NUEVO
import 'package:tpg_attack_kiosko_muelle/services/status/connectivity_manager.dart';
import 'package:tpg_attack_kiosko_muelle/utils/routes.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyError/atkDetailBar_error.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyError/atkSubheader_error.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyRfid/atkHeaderBar_rfid.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/atkFooterBar_common.dart';

class ErrorScreen extends StatefulWidget {
  final String error;
  const ErrorScreen({super.key, required this.error});

  @override
  State<ErrorScreen> createState() => _ErrorScreenState();
}

class _ErrorScreenState extends State<ErrorScreen> {
  Timer? _countdownTimer;
  final ValueNotifier<int> _remainingSeconds = ValueNotifier<int>(20);
  bool _disposed = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _disposed) return;

      // ✅ 1) Detener TODOS los servicios de conectividad
      await _cleanupServices();

      // ✅ 2) Limpiar datos del manager
      context.read<AtkTransactionManager>().resetAll();

      // ✅ 3) Log del error
      await LogService.instance.logError('ERROR_SCREEN_ENTERED', widget.error);

      // ✅ 4) Iniciar countdown
      _startCountdownTimer();
    });
  }

  Future<void> _cleanupServices() async {
    try {
      final cm = ConnectivityManager.instance;
      cm.stopAll();

      await LogService.instance.logRequest('SERVICES_STOPPED', {
        'reason': 'error_screen',
        'error': widget.error,
      });
    } catch (e) {
      await LogService.instance.logWarning('SERVICES_STOP_FAILED', {
        'error': e.toString(),
      });
    }
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel(); // ✅ Cancelar cualquier timer previo
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _disposed || _isNavigating) {
        timer.cancel();
        return;
      }

      final next = _remainingSeconds.value - 1;
      _remainingSeconds.value = next;

      if (next <= 0) {
        timer.cancel();
        _goToRfid();
      }
    });
  }

  void _goToRfid() async {
    if (_disposed || !mounted || _isNavigating) return;

    _isNavigating = true;
    _countdownTimer?.cancel();

    try {
      final appState = context.read<AppStateManager>();
      final isMuelle = appState.isMuelle;

      if (mounted) {
        context.read<AtkTransactionManager>().resetAll();
      }

      await ConnectivityManager.instance.restart(appState);

      await LogService.instance.logRequest('ERROR_SCREEN_EXIT', {
        'action': isMuelle ? 'returning_to_ocr' : 'returning_to_rfid',
        'isMuelle': isMuelle,
      });

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              isMuelle ? const OcrScannerScreen() : const RfidScreen(),
          settings: RouteSettings(name: isMuelle ? '/ocr' : AppRoutes.rfid),
        ),
        (route) => false,
      );
    } catch (e) {
      await LogService.instance.logError('ERROR_SCREEN_NAVIGATION_FAILED', e);

      if (!mounted) return;

      final isMuelle = context.read<AppStateManager>().isMuelle;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              isMuelle ? const OcrScannerScreen() : const RfidScreen(),
        ),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _countdownTimer?.cancel();
    _remainingSeconds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final hHeader = size.height * 0.15;
    final hSubHeader = size.height * 0.10;
    final hBody = size.height * 0.68;
    final hFooter = size.height * 0.07;

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              AtkHeaderRfid(
                title: 'Error en pantalla',
                height: hHeader,
                assetImagePath: 'assets/images/tpg_logo.png',
                onModeChanged: (isLight) =>
                    context.read<AppStateManager>().setLight(isLight),
              ),
              ValueListenableBuilder<int>(
                valueListenable: _remainingSeconds,
                builder: (_, seconds, __) => AtkSubHeaderBarError(
                  height: hSubHeader,
                  remainingSeconds: seconds,
                  now: DateTime.now(),
                ),
              ),
              AtkDetailBarError(
                height: hBody,
                message: widget.error
                    .replaceAll('Exception: ', '')
                    .replaceAll('Error::', '')
                    .replaceAll('Error:', '')
                    .trim(),
              ),
              AtkFooterBarCommon(
                height: hFooter,
                onModeChanged: (isLight) =>
                    context.read<AppStateManager>().setLight(isLight),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
