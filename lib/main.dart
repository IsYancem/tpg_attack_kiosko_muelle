import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/ocrScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/access_denied_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/rfidScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/error_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/login_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/staapisac_api_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/global_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/connectivity_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/windows_user_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/routes.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart';

String _normId(String? v) => (v ?? '').trim().toLowerCase();

bool _publicKeyMatchesDeviceId({
  required String? publicKey,
  required String deviceId,
}) {
  // Si publicKey viene vacío => NO permitir
  if ((publicKey ?? '').trim().isEmpty) return false;

  return _normId(publicKey) == _normId(deviceId);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LogService.instance.init();

  // 🖥️ Config ventana
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await windowManager.ensureInitialized();
    final screen = await getCurrentScreen();
    final visible =
        screen?.visibleFrame ?? const Rect.fromLTWH(0, 0, 1280, 800);
    const desiredMin = Size(800, 600);
    final safeMin = Size(
      math.min(desiredMin.width, visible.width),
      math.min(desiredMin.height, visible.height),
    );
    await windowManager.setMinimumSize(safeMin);
    await windowManager.waitUntilReadyToShow().then((_) async {
      await windowManager.setResizable(false);
      await windowManager.setFullScreen(true);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  await WindowsUserService.instance.initialize();
  await WindowsDeviceIdService.instance.initialize();
  final machineInfo = await WindowsDeviceIdService.instance
      .getUuidHostnameDomainIp();

  final deviceId = WindowsDeviceIdService.instance.deviceId ?? 'Unknown';
  await dotenv.load(fileName: ".env");

  final isMuelle = dotenv.env['MUELLE']?.toLowerCase() == 'true';

  final appState = await AppStateManager.init();
  appState.setMuelle(isMuelle);

  final atkManager = AtkTransactionManager();
  GlobalManager.instance.init(atkManager);

  final isTestMode = dotenv.env['IS_TEST_MODE']?.toLowerCase() == 'true';
  final winUser = isTestMode
      ? (dotenv.env['TEST_USER'] ?? 'TestUserNotSet')
      : (WindowsUserService.instance.getUserInfo()['username'] ?? 'Unknown');
  final baseMw = dotenv.env['BASE_MIDDLEWARE_URL'] ?? '';
  final bascula = dotenv.env['BASCULA'] ?? '';

  if (baseMw.isEmpty || bascula.isEmpty) {
    final msg = baseMw.isEmpty
        ? 'BASE_MIDDLEWARE_URL vacío en .env'
        : 'BASCULA vacío en .env';
    runApp(_wrapWithState(appState, atkManager, ErrorScreen(error: msg)));
    return;
  }

  await LogService.instance.logRequest('UnifiedLogin-Start', {
    'username': winUser,
    'bascula': bascula,
    'deviceId': deviceId,
  });

  final loginResponse = await LoginOrchestratorService.executeLogin(
    username: winUser,
    usernameApp: dotenv.env['USERNAME'] ?? '123456',
    password: dotenv.env['PASSWORD_MIDDLEWARE'] ?? '123456',
    app: dotenv.env['APP_MIDDLEWARE'] ?? '123456',
    bascula: bascula,
    machineInfo: machineInfo,
  );
  Widget initialScreen;

  if (loginResponse == null) {
    await LogService.instance.logError('UnifiedLogin-NullResponse', {});
    initialScreen = const ErrorScreen(error: 'Sin respuesta del servidor.');
  } else if (loginResponse.errorCode != 0) {
    await LogService.instance.logWarning('UnifiedLogin-Failed', {
      'msg': loginResponse.message,
    });
    initialScreen = AccessDeniedScreen(username: winUser);
  } else {
    final kioskCfg = loginResponse.data.kioskConfig?.data;

    final publicKey = (kioskCfg?['public_key'] ?? '').toString();

    final okDevice = _publicKeyMatchesDeviceId(
      publicKey: publicKey,
      //deviceId: deviceId,
      deviceId: 'cc8d5c16-9baf-4ae5-af2f-9d83e3c6d53e',
    );

    await LogService.instance.logRequest('KIOSK_PUBLICKEY_VALIDATE', {
      'user': winUser,
      'bascula': bascula,
      'deviceId': deviceId,
      'publicKey': publicKey,
      'match': okDevice,
    });

    if (!okDevice) {
      initialScreen = AccessDeniedScreen(username: winUser);
    } else {
      await LogService.instance.logRequest('KIOSK_PUBLICKEY_MATCH_OK', {
        'user': winUser,
        'bascula': bascula,
        'deviceId': deviceId,
      });

      await LogService.instance.logRequest('UnifiedLogin-OK', {
        'user': winUser,
        'msg': loginResponse.message,
      });

      atkManager.set('mensajeInferior', 'Bascula conectada correctamente');
      atkManager.set(
        'vehiculoNave',
        loginResponse.data.kioskConfig?.data?['gate'] ?? '',
      );

      await ConnectivityManager.instance.init(appState);

      initialScreen = isMuelle ? const OcrScannerScreen() : const RfidScreen();
    }
  }

  final sta = StaapisacApiService();
  try {
    await sta.loginStaapisac(appState: appState);
  } catch (e, st) {
    await LogService.instance.logError('STAAPISAC_LOGIN_MAIN_FAIL', e, st);
  }

  runApp(_wrapWithState(appState, atkManager, initialScreen));
}

Widget _wrapWithState(
  AppStateManager appState,
  AtkTransactionManager atkManager,
  Widget home,
) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: appState),
      ChangeNotifierProvider.value(value: atkManager),
    ],
    child: _KioskApp(initialScreen: home),
  );
}

class _KioskApp extends StatelessWidget {
  final Widget initialScreen;
  const _KioskApp({required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateManager>(
      builder: (_, state, __) {
        return MaterialApp(
          title:
              'TPG Kiosko - ${WindowsUserService.instance.currentUser ?? "Usuario"}',
          debugShowCheckedModeBanner: false,
          themeMode: state.themeMode,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case AppRoutes.rfid:
                return MaterialPageRoute(
                  builder: (_) => const RfidScreen(),
                  settings: settings,
                );
              case AppRoutes.error:
                final err =
                    settings.arguments as String? ?? 'Error desconocido';
                return MaterialPageRoute(
                  builder: (_) => ErrorScreen(error: err),
                  settings: settings,
                );
              case AppRoutes.accessDenied:
                final username =
                    settings.arguments as String? ?? 'Usuario desconocido';
                return MaterialPageRoute(
                  builder: (_) => AccessDeniedScreen(username: username),
                  settings: settings,
                );
              default:
                return MaterialPageRoute(
                  builder: (_) => initialScreen,
                  settings: const RouteSettings(name: '/'),
                );
            }
          },
          home: initialScreen,
        );
      },
    );
  }
}
