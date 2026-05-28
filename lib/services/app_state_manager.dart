// Autor: Abraham Yance
// Fecha: 2025-11-11
// Manejo global de estado de la app y almacenamiento de configuración del kiosko
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tpg_attack_kiosko_muelle/models/attack/gate_config_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/attack/kioskConfig_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/attack/parameters_atak_model.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';

class AppStateManager extends ChangeNotifier {
  static const _key = 'themeMode';
  final SharedPreferences _prefs;
  ThemeMode themeMode;

  AppStateManager._(this._prefs, this.themeMode);
  static AppStateManager? _instance;

  static AppStateManager get instance {
    if (_instance == null) {
      throw Exception(
        'AppStateManager no inicializado. Llama a init() primero.',
      );
    }
    return _instance!;
  }

  static Future<AppStateManager> init() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    final mode = v == 'light' ? ThemeMode.light : ThemeMode.dark;
    final mgr = AppStateManager._(prefs, mode);
    _instance = mgr;
    return mgr;
  }

  void setLight(bool isLight) {
    themeMode = isLight ? ThemeMode.light : ThemeMode.dark;
    _prefs.setString(_key, isLight ? 'light' : 'dark');
    notifyListeners();
  }

  bool get isLight => themeMode == ThemeMode.light;

  // ──────────────── Login Unificado ────────────────
  String? _accessToken;
  String? _refreshToken;
  KioskConfigModel? _kioskConfig;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  KioskConfigModel? get kioskConfig => _kioskConfig;

  ParametersAtakModel? _parametersAtak;

  ParametersAtakModel? get parametersAtak => _parametersAtak;

  bool get hasParametersAtak => _parametersAtak != null;

  String get faceDeviceSn => _kioskConfig?.faceDeviceSn ?? '';

  GateConfigModel? _gateConfig;
  GateConfigModel? get gateConfig => _gateConfig;

  bool muelle = false;

  bool get isMuelle => muelle;

  void setMuelle(bool value) {
    if (muelle == value) return;
    muelle = value;
    notifyListeners();
  }

  void setGateConfig(GateConfigModel? cfg) {
    _gateConfig = cfg;
    LogService.instance.logRequest('APPSTATE_SET_GATE_CONFIG', {
      'serverPlc': cfg?.serverPlc,
      'apiKeyLen': cfg?.apiKey.length,
      'gateLocation': cfg?.gateLocation,
    });
    notifyListeners();
  }

  bool get hasValidConfig => _kioskConfig != null;

  void setTokens(String? access, String? refresh) {
    _accessToken = access;
    _refreshToken = refresh;
    LogService.instance.logRequest('APPSTATE_SET_TOKENS', {
      'hasAccess': access != null && access.isNotEmpty,
      'hasRefresh': refresh != null && refresh.isNotEmpty,
    });
    notifyListeners();
  }

  void setKioskConfig(KioskConfigModel? cfg) {
    _kioskConfig = cfg;
    LogService.instance.logRequest('APPSTATE_SET_CONFIG', {
      'bascula': cfg?.bascula,
      'patio': cfg?.patio,
      'gate': cfg?.gate,
      'server': cfg?.kioskServer,
      'faceDeviceSn': cfg?.faceDeviceSn,
    });
    notifyListeners();
  }

  void clearSession() {
    _accessToken = null;
    _refreshToken = null;
    _kioskConfig = null;
    _gateConfig = null;

    // IMPORTANTE:
    // No limpiar _parametersAtak aquí si esta configuración debe sobrevivir
    // a limpiezas de transacción o retorno a OCR.

    LogService.instance.logRequest('APPSTATE_CLEAR_SESSION', {
      'parametersAtakPreserved': _parametersAtak != null,
    });

    notifyListeners();
  }

  // =======================
  // STAAPISAC AUTH CACHE
  // =======================
  String staapisacId = '';
  String staapisacUsername = '';
  String staapisacComputerName = '';
  String staapisacAccessToken = '';
  String staapisacRefreshToken = '';

  bool get hasStaapisacAuth =>
      staapisacAccessToken.isNotEmpty && staapisacRefreshToken.isNotEmpty;

  void setStaapisacAuth({
    required String id,
    required String username,
    required String computerName,
    required String accessToken,
    required String refreshToken,
  }) {
    staapisacId = id;
    staapisacUsername = username;
    staapisacComputerName = computerName;
    staapisacAccessToken = accessToken;
    staapisacRefreshToken = refreshToken;
    notifyListeners();
  }

  double get porteoPeso => _parametersAtak?.porteoPeso ?? 0;
  double get pesoBypass => _parametersAtak?.pesoBypass ?? 0;
  double get pesoPromedio => _parametersAtak?.pesoPromedio ?? 0;
  double get promedioPorteo => _parametersAtak?.promedioPorteo ?? 0;
  double get toleranciaPorteo => _parametersAtak?.toleranciaPorteo ?? 0;
  double get toleranciaVacio => _parametersAtak?.toleranciaVacio ?? 0;
  double get tolerancia => _parametersAtak?.tolerancia ?? 0;
  double get tolerancia2 => _parametersAtak?.tolerancia2 ?? 0;
  int get huella => _parametersAtak?.huella ?? 0;
  int get huellaMuelle => _parametersAtak?.huellaMuelle ?? 0;
  int get pesoAMano => _parametersAtak?.pesoAMano ?? 0;

  void setParametersAtak(ParametersAtakModel? params) {
    _parametersAtak = params;

    LogService.instance.logRequest('APPSTATE_SET_PARAMETERS_ATAK', {
      'hasParameters': params != null,
      'PORTEOPESO': params?.porteoPeso,
      'peso_bypass': params?.pesoBypass,
      'peso_promedio': params?.pesoPromedio,
      'promedio_porteo': params?.promedioPorteo,
      'tolerancia_porteo': params?.toleranciaPorteo,
      'tolerancia_vacio': params?.toleranciaVacio,
      'huella': params?.huella,
      'huella_muelle': params?.huellaMuelle,
      'peso_a_mano': params?.pesoAMano,
      'raw': params?.raw,
    });

    notifyListeners();
  }
}
