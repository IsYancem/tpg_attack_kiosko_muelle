import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/login_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/access_denied_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/rfidScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/error_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/staapisac_api_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/global_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/windows_user_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/routes.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:window_manager/window_manager.dart';
import 'package:window_size/window_size.dart';

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

  LogService.instance.logRequest('APP_START_LOGIN_SCREEN', {
    'windowsUser': winUser,
    'bascula': bascula,
    'deviceId': deviceId,
  });

  runApp(_wrapWithState(appState, atkManager, const LoginScreen()));

  unawaited(_loginStaapisacInBackground(appState));
}

Future<void> _loginStaapisacInBackground(AppStateManager appState) async {
  try {
    await StaapisacApiService()
        .loginStaapisac(appState: appState)
        .timeout(const Duration(seconds: 8));
  } catch (e, st) {
    LogService.instance.logError('STAAPISAC_LOGIN_MAIN_FAIL', e, st);
  }
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
