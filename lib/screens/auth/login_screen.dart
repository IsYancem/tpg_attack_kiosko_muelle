import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/ocrScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/rfidScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/screens/errors/access_denied_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/login_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/staapisac_api_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/app_state_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/keycloak_auth_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/status/connectivity_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/windows_user_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyRfid/atkHeaderBar_rfid.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/atkFooterBar_common.dart';

/// Pantalla de Login:
/// 1) Valida contra Keycloak (KeycloakAuthService — igual que el Postman).
/// 2) Guarda accessToken/refreshToken en AtkTransactionManager.
/// 3) Ejecuta el orquestador y valida public_key.
/// 4) Inicializa conectividad + STAAPISAC y navega.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;

  // ⚠️ Valor de prueba: coincide con el public_key registrado en tu entorno.
  //    En producción cambia esto por WindowsDeviceIdService.instance.deviceId.
  static const String _validationDeviceId =
      'cc8d5c16-9baf-4ae5-af2f-9d83e3c6d53e';

  // --------------------------------------------------------------
  // Helpers de validación de public_key
  // --------------------------------------------------------------
  static String _normId(String? v) => (v ?? '').trim().toLowerCase();

  static bool _publicKeyMatchesDeviceId({
    required String? publicKey,
    required String deviceId,
  }) {
    if ((publicKey ?? '').trim().isEmpty) return false;
    return _normId(publicKey) == _normId(deviceId);
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _showSnack(ScaffoldMessengerState messenger, String msg) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
  }

  // --------------------------------------------------------------
  // Login: Keycloak → guardar tokens → Orquestador → validar → navegar
  // --------------------------------------------------------------
  Future<void> _login() async {
    final username = _userCtrl.text.trim();
    final password = _passCtrl.text;

    // Capturamos referencias ANTES de los await (evita usar context
    // a través de async gaps).
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final atk = context.read<AtkTransactionManager>();
    final appState = context.read<AppStateManager>();

    if (username.isEmpty || password.isEmpty) {
      _showSnack(messenger, 'Ingrese usuario y contraseña');
      return;
    }

    setState(() => _loading = true);

    try {
      await LogService.instance.logRequest('LOGIN_MANUAL_START', {
        'username': username,
      });

      // ---- 1. Autenticación contra Keycloak (TU servicio, sin cambios) ----
      final token = await KeycloakAuthService.login(
        username: username,
        password: password,
      );

      if (!mounted) return;

      if (token == null) {
        _showSnack(messenger, 'Credenciales inválidas o error de conexión');
        return;
      }

      // ---- 2. Guardar tokens de Keycloak en AtkTransactionManager ----
      atk.setMany({
        'accessToken': token.accessToken,
        'refreshToken': token.refreshToken,
        'tokenType': token.tokenType,
        'idToken': token.idToken,
        'sessionState': token.sessionState,
        'tokenExpiresIn': token.expiresIn,
        'refreshExpiresIn': token.refreshExpiresIn,
      });

      await LogService.instance.logRequest('LOGIN_KEYCLOAK_TOKENS_SAVED_ATK', {
        'hasAccessToken': token.accessToken.isNotEmpty,
        'hasRefreshToken': token.refreshToken.isNotEmpty,
        'sessionState': token.sessionState,
      });

      // ---- 3. Información de la máquina ----
      final machineInfo =
          await WindowsDeviceIdService.instance.getUuidHostnameDomainIp();
      final deviceId = WindowsDeviceIdService.instance.deviceId ?? 'Unknown';

      if (!mounted) return;

      // ---- 4. Login Orchestrator ----
      final orch = await LoginOrchestratorService.executeLogin(
        // El username ingresado identifica al operador.
        username: username,
        // 🔧 Credenciales de servicio del middleware (vienen del .env).
        //    Si quieres usar la contraseña ingresada para el middleware,
        //    reemplaza usernameApp/password aquí.
        usernameApp: dotenv.env['USERNAME'] ?? '123456',
        password: dotenv.env['PASSWORD_MIDDLEWARE'] ?? '123456',
        app: dotenv.env['APP_MIDDLEWARE'] ?? '123456',
        bascula: dotenv.env['BASCULA'] ?? '',
        machineInfo: machineInfo,
      );

      if (!mounted) return;

      if (orch == null) {
        await LogService.instance.logError('LOGIN_ORCH_NULL', {});
        _showSnack(messenger, 'Sin respuesta del servidor.');
        return;
      }

      if (orch.errorCode != 0) {
        await LogService.instance.logWarning('LOGIN_ORCH_FAILED', {
          'msg': orch.message,
        });
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => AccessDeniedScreen(username: username),
          ),
          (route) => false,
        );
        return;
      }

      // ---- 5. Validar public_key contra deviceId ----
      final kioskCfg = orch.data.kioskConfig?.data;
      final publicKey = (kioskCfg?['public_key'] ?? '').toString();

      final okDevice = _publicKeyMatchesDeviceId(
        publicKey: publicKey,
        // deviceId: deviceId,  // ← usar este en producción
        deviceId: _validationDeviceId,
      );

      await LogService.instance.logRequest('KIOSK_PUBLICKEY_VALIDATE', {
        'user': username,
        'deviceId': deviceId,
        'publicKey': publicKey,
        'match': okDevice,
      });

      if (!okDevice) {
        navigator.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => AccessDeniedScreen(username: username),
          ),
          (route) => false,
        );
        return;
      }

      // ---- 6. Todo OK: estado post-login ----
      atk.set('mensajeInferior', 'Bascula conectada correctamente');
      atk.set('vehiculoNave', kioskCfg?['gate'] ?? '');

      await ConnectivityManager.instance.init(appState);

      // STAAPISAC (no bloqueante)
      try {
        await StaapisacApiService().loginStaapisac(appState: appState);
      } catch (e, st) {
        await LogService.instance.logError('STAAPISAC_LOGIN_LOGIN_FAIL', e, st);
      }

      await LogService.instance.logRequest('LOGIN_MANUAL_OK', {
        'user': username,
        'msg': orch.message,
      });

      if (!mounted) return;

      // ---- 7. Navegar según el modo ----
      final isMuelle = appState.isMuelle;
      final nextScreen =
          isMuelle ? const OcrScannerScreen() : const RfidScreen();

      navigator.pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => nextScreen,
          transitionDuration: const Duration(milliseconds: 200),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
        (route) => false,
      );
    } catch (e, st) {
      await LogService.instance.logError('LOGIN_MANUAL_ERROR', e, st);
      if (!mounted) return;
      _showSnack(messenger, 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // --------------------------------------------------------------
  // Build
  // --------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final appManager = context.watch<AppStateManager>();
    final size = MediaQuery.sizeOf(context);
    final hHeader = size.height * 0.15;
    final hSubHeader = size.height * 0.10;
    final hBody = size.height * 0.68;
    final hFooter = size.height * 0.07;

    return Scaffold(
      body: Column(
        children: [
          AtkHeaderRfid(
            title: 'Inicio de Sesión',
            height: hHeader,
            assetImagePath: 'assets/images/tpg_logo.png',
            onModeChanged: (isLight) => appManager.setLight(isLight),
          ),
          _LoginSubHeader(height: hSubHeader),
          _LoginBody(
            height: hBody,
            loading: _loading,
            onLogin: _login,
            userController: _userCtrl,
            passController: _passCtrl,
          ),
          AtkFooterBarCommon(
            height: hFooter,
            onModeChanged: (isLight) => appManager.setLight(isLight),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Subheader con mensaje y fecha
// ---------------------------------------------------------------------
class _LoginSubHeader extends StatefulWidget {
  final double height;
  const _LoginSubHeader({required this.height});

  @override
  State<_LoginSubHeader> createState() => _LoginSubHeaderState();
}

class _LoginSubHeaderState extends State<_LoginSubHeader> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = (widget.height / 100).clamp(0.6, 2.0);

    return SizedBox(
      height: widget.height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32 * s),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Ingrese sus credenciales para continuar',
                style: TextStyle(
                  fontSize: 25 * s,
                  fontWeight: FontWeight.w900,
                  color: p.textPrimary,
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 24 * s),
            Text(
              _now.toLocal().toString().split(' ')[0],
              style: TextStyle(
                fontSize: 18 * s,
                fontWeight: FontWeight.w600,
                color: p.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Cuerpo principal: formulario centrado sobre fondo decorativo
// ---------------------------------------------------------------------
class _LoginBody extends StatelessWidget {
  final double height;
  final bool loading;
  final VoidCallback onLogin;
  final TextEditingController userController;
  final TextEditingController passController;

  const _LoginBody({
    required this.height,
    required this.loading,
    required this.onLogin,
    required this.userController,
    required this.passController,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.palette;
    final s = (height / 680).clamp(0.6, 1.6);

    return SizedBox(
      height: height,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.azulCorporativo.withValues(alpha: 0.06),
              colors.bg.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60 * s,
              right: -40 * s,
              child: _GlowCircle(
                size: 220 * s,
                color: colors.azulCorporativo.withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              bottom: -50 * s,
              left: -30 * s,
              child: _GlowCircle(
                size: 180 * s,
                color: colors.accent.withValues(alpha: 0.06),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 24 * s,
                  vertical: 12 * s,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 460 * s),
                  child: _LoginForm(
                    loading: loading,
                    onLogin: onLogin,
                    userController: userController,
                    passController: passController,
                    s: s,
                    colors: colors,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Círculo difuminado para el fondo decorativo.
class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0.0)],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Formulario de login
// ---------------------------------------------------------------------
class _LoginForm extends StatefulWidget {
  final bool loading;
  final VoidCallback onLogin;
  final TextEditingController userController;
  final TextEditingController passController;
  final double s;
  final AppPalette colors;

  const _LoginForm({
    required this.loading,
    required this.onLogin,
    required this.userController,
    required this.passController,
    required this.s,
    required this.colors,
  });

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _passFocus = FocusNode();
  bool _obscure = true;

  @override
  void dispose() {
    _passFocus.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    final c = widget.colors;
    final s = widget.s;
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(16 * s),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 22 * s, color: c.textSecondary),
      suffixIcon: suffix,
      filled: true,
      fillColor: c.fieldBg,
      isDense: true,
      contentPadding:
          EdgeInsets.symmetric(vertical: 18 * s, horizontal: 16 * s),
      labelStyle: TextStyle(fontSize: 15 * s, color: c.textSecondary),
      border: border(Colors.transparent),
      enabledBorder: border(c.border.withValues(alpha: 0.4)),
      focusedBorder: border(c.azulCorporativo, width: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final s = widget.s;

    return Card(
      elevation: 14,
      color: c.surface,
      shadowColor: c.azulCorporativo.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28 * s),
        side: BorderSide(color: c.border.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(30 * s, 34 * s, 30 * s, 30 * s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 76 * s,
                height: 76 * s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      c.azulCorporativo,
                      c.azulCorporativo.withValues(alpha: 0.7),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: c.azulCorporativo.withValues(alpha: 0.35),
                      blurRadius: 18 * s,
                      offset: Offset(0, 6 * s),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.lock_person_outlined,
                  color: Colors.white,
                  size: 38 * s,
                ),
              ),
            ),
            SizedBox(height: 20 * s),
            Text(
              'Bienvenido',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 30 * s,
                fontWeight: FontWeight.bold,
                color: c.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
            SizedBox(height: 6 * s),
            Text(
              'Acceso al sistema de despacho',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14 * s, color: c.textSecondary),
            ),
            SizedBox(height: 30 * s),

            // Usuario
            TextField(
              controller: widget.userController,
              enabled: !widget.loading,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.emailAddress,
              onSubmitted: (_) => _passFocus.requestFocus(),
              decoration: _fieldDecoration(
                label: 'Usuario',
                icon: Icons.person_outline,
              ),
              style: TextStyle(fontSize: 17 * s, color: c.textPrimary),
            ),
            SizedBox(height: 18 * s),

            // Contraseña
            TextField(
              controller: widget.passController,
              focusNode: _passFocus,
              enabled: !widget.loading,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => widget.loading ? null : widget.onLogin(),
              decoration: _fieldDecoration(
                label: 'Contraseña',
                icon: Icons.lock_outline,
                suffix: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 22 * s,
                    color: c.textSecondary,
                  ),
                  tooltip: _obscure ? 'Mostrar' : 'Ocultar',
                ),
              ),
              style: TextStyle(fontSize: 17 * s, color: c.textPrimary),
            ),
            SizedBox(height: 30 * s),

            _GradientButton(
              loading: widget.loading,
              onPressed: widget.onLogin,
              colors: c,
              s: s,
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    ).animate().scale(delay: 150.ms, duration: 500.ms, curve: Curves.easeOut);
  }
}

/// Botón principal con degradado y estado de carga.
class _GradientButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  final AppPalette colors;
  final double s;

  const _GradientButton({
    required this.loading,
    required this.onPressed,
    required this.colors,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18 * s);

    return SizedBox(
      height: 58 * s,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                colors.azulCorporativo,
                colors.azulCorporativo.withValues(alpha: 0.78),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: colors.azulCorporativo.withValues(alpha: 0.35),
                blurRadius: 16 * s,
                offset: Offset(0, 6 * s),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: loading ? null : onPressed,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 26 * s,
                      height: 26 * s,
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.6,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.login_rounded,
                            color: Colors.white, size: 22 * s),
                        SizedBox(width: 10 * s),
                        Text(
                          'Ingresar',
                          style: TextStyle(
                            fontSize: 19 * s,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}