// services/windows_user_service.dart
import 'dart:io';
import 'dart:convert';

import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';

class WindowsUserService {
  static WindowsUserService? _instance;
  static WindowsUserService get instance =>
      _instance ??= WindowsUserService._();
  WindowsUserService._();

  String? _currentUser;
  String? get currentUser => _currentUser;

  /// Inicializa y obtiene el usuario actual de Windows
  Future<void> initialize() async {
    _currentUser = await _getCurrentWindowsUser();

    LogService.instance.logRequest('WindowsUserService', {
      'initialized': true,
      'user': _currentUser ?? 'Unknown',
      'platform': Platform.operatingSystem,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Obtiene información completa del usuario y sistema
  Map<String, dynamic> getUserInfo() {
    return {
      'username': _currentUser,
      'computer_name': Platform.localHostname,
      'platform': Platform.operatingSystem,
      'platform_version': Platform.operatingSystemVersion,
      'user_domain': Platform.environment['USERDOMAIN'],
      'user_profile': Platform.environment['USERPROFILE'],
      'user_home':
          Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'],
      'processor_architecture': Platform.environment['PROCESSOR_ARCHITECTURE'],
      'number_of_processors': Platform.environment['NUMBER_OF_PROCESSORS'],
    };
  }

  /// Obtiene el usuario actual usando múltiples métodos de respaldo
  Future<String?> _getCurrentWindowsUser() async {
    try {
      if (!Platform.isWindows) {
        LogService.instance.logRequest('WindowsUserService', {
          'error': 'No es plataforma Windows',
          'platform': Platform.operatingSystem,
        });
        return null;
      }

      // Método 1: Variable de entorno USERNAME
      final username = Platform.environment['USERNAME'];
      if (username != null && username.isNotEmpty) {
        LogService.instance.logRequest('WindowsUserService', {
          'method': 'environment_USERNAME',
          'username': username,
          'success': true,
        });
        return username;
      }

      // Método 2: Comando whoami
      try {
        final result = await Process.run('whoami', [], runInShell: true);

        if (result.exitCode == 0) {
          final fullUser = result.stdout.toString().trim();
          final extractedUser = fullUser.contains('\\')
              ? fullUser.split('\\').last
              : fullUser;

          LogService.instance.logRequest('WindowsUserService', {
            'method': 'whoami_command',
            'full_user': fullUser,
            'extracted_user': extractedUser,
            'success': true,
          });
          return extractedUser;
        } else {
          LogService.instance.logRequest('WindowsUserService', {
            'method': 'whoami_command',
            'exit_code': result.exitCode,
            'stderr': result.stderr.toString(),
            'success': false,
          });
        }
      } catch (e) {
        LogService.instance.logRequest('WindowsUserService', {
          'method': 'whoami_command',
          'error': e.toString(),
          'success': false,
        });
      }

      // Método 3: Variable USERPROFILE como último recurso
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        final extractedUser = userProfile.split('\\').last;
        LogService.instance.logRequest('WindowsUserService', {
          'method': 'environment_USERPROFILE',
          'userprofile_path': userProfile,
          'extracted_user': extractedUser,
          'success': true,
        });
        return extractedUser;
      }

      // Si llegamos aquí, no pudimos obtener el usuario
      LogService.instance.logRequest('WindowsUserService', {
        'error': 'No se pudo obtener el usuario de Windows con ningún método',
        'available_env_vars': Platform.environment.keys
            .where((key) => key.contains('USER') || key.contains('NAME'))
            .toList(),
        'success': false,
      });

      return null;
    } catch (e) {
      LogService.instance.logRequest('WindowsUserService', {
        'error': 'Error general al obtener usuario de Windows',
        'exception': e.toString(),
        'success': false,
      });
      return null;
    }
  }

  /// Método para refrescar la información del usuario
  Future<void> refresh() async {
    await initialize();
  }

  /// Verifica si el servicio está inicializado
  bool get isInitialized => _currentUser != null;
}

class WindowsDeviceIdService {
  static WindowsDeviceIdService? _instance;
  static WindowsDeviceIdService get instance =>
      _instance ??= WindowsDeviceIdService._();
  WindowsDeviceIdService._();

  String? _deviceId;
  String? get deviceId => _deviceId;

  Future<void> initialize() async {
    _deviceId = await getBestDeviceId();

    LogService.instance.logRequest('WindowsDeviceIdService', {
      'initialized': true,
      'deviceId': _deviceId ?? 'Unknown',
      'platform': Platform.operatingSystem,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Devuelve un ID estable del equipo (mejor esfuerzo).
  /// Nota: WMIC puede no existir (Windows moderno). Por eso:
  /// - MachineGuid (registro) funciona casi siempre
  /// - Para BIOS/UUID usamos PowerShell CIM (dumpBiosCim)
  Future<String?> getBestDeviceId() async {
    if (!Platform.isWindows) return null;

    // 1) MachineGuid (Registro) - lo más usado como "device id" en Windows
    final mg = await _getMachineGuid();
    if (_isGoodId(mg)) return mg;

    // 2) Intentar UUID / BIOS Serial por PowerShell CIM (sin WMIC)
    final ids = await _getIdsViaCim();
    final uuid = ids['uuid'];
    if (_isGoodId(uuid)) return uuid;

    final biosSerial = ids['biosSerial'];
    if (_isGoodId(biosSerial)) return biosSerial;

    // 3) Fallback (no garantizado único globalmente)
    final fallback =
        '${Platform.localHostname}|${Platform.environment['USERDOMAIN'] ?? ''}'
            .trim();
    return fallback.isNotEmpty ? fallback : null;
  }

  bool _isGoodId(String? v) {
    if (v == null) return false;
    final s = v.trim();
    if (s.isEmpty) return false;

    // muchos equipos devuelven valores genéricos
    final upper = s.toUpperCase();
    const bad = {
      'TO BE FILLED BY O.E.M.',
      'DEFAULT STRING',
      'NONE',
      'UNKNOWN',
      '0',
      '00000000-0000-0000-0000-000000000000',
    };
    if (bad.contains(upper)) return false;

    // serial/uuid muy cortos suelen ser basura
    return s.length >= 8;
  }

  Future<String?> _getMachineGuid() async {
    try {
      // reg query HKLM\SOFTWARE\Microsoft\Cryptography /v MachineGuid
      final result = await Process.run('reg', [
        'query',
        r'HKLM\SOFTWARE\Microsoft\Cryptography',
        '/v',
        'MachineGuid',
      ], runInShell: true);

      if (result.exitCode != 0) {
        LogService.instance.logRequest('WindowsDeviceIdService', {
          'method': 'reg_machineguid',
          'exitCode': result.exitCode,
          'stderr': result.stderr.toString(),
          'success': false,
        });
        return null;
      }

      final out = result.stdout.toString();
      // Ejemplo línea: MachineGuid    REG_SZ    xxxxxxxx-xxxx-....
      final lines = out.split(RegExp(r'\r?\n')).map((e) => e.trim()).toList();
      final line = lines.firstWhere(
        (l) => l.toLowerCase().startsWith('machineguid'),
        orElse: () => '',
      );
      if (line.isEmpty) return null;

      final parts = line.split(RegExp(r'\s+'));
      // último token suele ser el guid
      final guid = parts.isNotEmpty ? parts.last.trim() : null;

      LogService.instance.logRequest('WindowsDeviceIdService', {
        'method': 'reg_machineguid',
        'guid': guid,
        'success': guid != null && guid.isNotEmpty,
      });

      return guid;
    } catch (e, st) {
      LogService.instance.logError(
        'WindowsDeviceIdService_reg_exception',
        e,
        st,
      );
      return null;
    }
  }

  // ==========================
  // BIOS/HW DUMP (CIM via PowerShell)
  // ==========================

  /// Dump “lo más completo” posible (BIOS + baseboard + csproduct + system enclosure + cpu).
  /// Devuelve:
  /// - meta (timestamp, platform...)
  /// - salida JSON (string) y también objeto parseado si se puede
  Future<Map<String, dynamic>> dumpBiosCim({
    int jsonDepth = 6,
    int maxRawCharsToLog = 6000,
  }) async {
    if (!Platform.isWindows) {
      return {'error': 'NotWindows', 'platform': Platform.operatingSystem};
    }

    final script =
        r'''
$ErrorActionPreference = "SilentlyContinue";

$bios = Get-CimInstance Win32_BIOS | Select-Object *
$cs = Get-CimInstance Win32_ComputerSystem | Select-Object *
$csprod = Get-CimInstance Win32_ComputerSystemProduct | Select-Object *
$board = Get-CimInstance Win32_BaseBoard | Select-Object *
$enc = Get-CimInstance Win32_SystemEnclosure | Select-Object *
$cpu = Get-CimInstance Win32_Processor | Select-Object *

$result = [PSCustomObject]@{
  bios = $bios
  computerSystem = $cs
  computerSystemProduct = $csprod
  baseBoard = $board
  systemEnclosure = $enc
  cpu = $cpu
}

$result | ConvertTo-Json -Depth %DEPTH%
'''
            .replaceAll('%DEPTH%', jsonDepth.toString());

    final out = await _runPowerShell(script);

    final raw = (out['stdout'] ?? '').toString();
    final trimmedRaw = _truncate(raw, maxRawCharsToLog);

    // Log para observación inmediata
    LogService.instance.logRequest('BIOS_DUMP_CIM', {
      'exitCode': out['exitCode'],
      'stderr': out['stderr'],
      'raw': trimmedRaw,
      'rawTruncated': raw.length > trimmedRaw.length,
    });

    // Intentar parsear JSON a Map (para inspección)
    dynamic parsed;
    try {
      if (raw.trim().isNotEmpty) {
        parsed = jsonDecode(raw);
      }
    } catch (_) {
      parsed = null;
    }

    return {
      'timestamp': DateTime.now().toIso8601String(),
      'platform': Platform.operatingSystem,
      'platform_version': Platform.operatingSystemVersion,
      'hostname': Platform.localHostname,
      'command': 'powershell Get-CimInstance Win32_* | ConvertTo-Json',
      'exitCode': out['exitCode'],
      'stderr': out['stderr'],
      'json': raw, // JSON completo
      'parsed': parsed, // objeto parseado si pudo
    };
  }

  /// Obtiene IDs clave via CIM (sin WMIC):
  /// - UUID: Win32_ComputerSystemProduct.UUID
  /// - BIOS Serial: Win32_BIOS.SerialNumber
  Future<Map<String, String?>> _getIdsViaCim() async {
    final script = r'''
$ErrorActionPreference = "SilentlyContinue";
$uuid = (Get-CimInstance Win32_ComputerSystemProduct).UUID
$biosSerial = (Get-CimInstance Win32_BIOS).SerialNumber
[PSCustomObject]@{ uuid=$uuid; biosSerial=$biosSerial } | ConvertTo-Json -Depth 3
''';

    final out = await _runPowerShell(script);
    final raw = (out['stdout'] ?? '').toString().trim();

    if (out['exitCode'] != 0 || raw.isEmpty) {
      LogService.instance.logRequest('WindowsDeviceIdService', {
        'method': 'cim_ids',
        'exitCode': out['exitCode'],
        'stderr': out['stderr'],
        'success': false,
      });
      return {'uuid': null, 'biosSerial': null};
    }

    try {
      final obj = jsonDecode(raw);
      final uuid = (obj is Map && obj['uuid'] != null)
          ? obj['uuid'].toString().trim()
          : null;
      final biosSerial = (obj is Map && obj['biosSerial'] != null)
          ? obj['biosSerial'].toString().trim()
          : null;

      LogService.instance.logRequest('WindowsDeviceIdService', {
        'method': 'cim_ids',
        'uuid': uuid,
        'biosSerial': biosSerial,
        'success': true,
      });

      return {'uuid': uuid, 'biosSerial': biosSerial};
    } catch (e) {
      LogService.instance.logRequest('WindowsDeviceIdService', {
        'method': 'cim_ids',
        'error': e.toString(),
        'raw': _truncate(raw, 1000),
        'success': false,
      });
      return {'uuid': null, 'biosSerial': null};
    }
  }

  Future<Map<String, dynamic>> _runPowerShell(String psScript) async {
    try {
      final result = await Process.run(
        r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          psScript,
        ],
        runInShell: false,
      );

      return {
        'exitCode': result.exitCode,
        'stdout': result.stdout.toString(),
        'stderr': result.stderr.toString(),
      };
    } catch (e, st) {
      LogService.instance.logError('PS_RUN_FAIL', e, st);
      return {'exitCode': -1, 'stdout': '', 'stderr': e.toString()};
    }
  }

  String _truncate(String s, int maxChars) {
    if (maxChars <= 0) return '';
    if (s.length <= maxChars) return s;
    return s.substring(0, maxChars);
  }

  Future<Map<String, dynamic>> getHardwareBiosSummary() async {
    if (!Platform.isWindows) {
      return {'error': 'NotWindows', 'platform': Platform.operatingSystem};
    }

    // Extrae solo lo importante, en JSON
    final script = r'''
$ErrorActionPreference = "SilentlyContinue";

$bios = Get-CimInstance Win32_BIOS
$cs = Get-CimInstance Win32_ComputerSystem
$csprod = Get-CimInstance Win32_ComputerSystemProduct

$serial = $null
$smbios = $null
if ($bios) {
  $serial = $bios.SerialNumber
  $smbios = $bios.SMBIOSBIOSVersion
}

$manufacturer = $null
$model = $null
if ($cs) {
  $manufacturer = $cs.Manufacturer
  $model = $cs.Model
}

$uuid = $null
if ($csprod) {
  $uuid = $csprod.UUID
}

[PSCustomObject]@{
  serialNumber = $serial
  uuid = $uuid
  manufacturer = $manufacturer
  model = $model
  smbiosBiosVersion = $smbios
} | ConvertTo-Json -Depth 3
''';

    final out = await _runPowerShell(script);
    final raw = (out['stdout'] ?? '').toString().trim();

    if (out['exitCode'] != 0 || raw.isEmpty) {
      final res = {
        'error': 'PowerShellCimFailed',
        'exitCode': out['exitCode'],
        'stderr': out['stderr'],
      };

      LogService.instance.logRequest('BIOS_SUMMARY', res);
      return res;
    }

    try {
      final obj = jsonDecode(raw);

      // Normalizamos strings
      String? s(dynamic v) => v == null ? null : v.toString().trim();

      final summary = <String, dynamic>{
        'serialNumber': s(obj['serialNumber']),
        'uuid': s(obj['uuid']),
        'manufacturer': s(obj['manufacturer']),
        'model': s(obj['model']),
        'smbiosBiosVersion': s(obj['smbiosBiosVersion']),
        'timestamp': DateTime.now().toIso8601String(),
        'hostname': Platform.localHostname,
        'platform': Platform.operatingSystem,
        'platform_version': Platform.operatingSystemVersion,
      };

      LogService.instance.logRequest('BIOS_SUMMARY', summary);
      return summary;
    } catch (e) {
      final res = {
        'error': 'JsonParseFailed',
        'raw': raw,
        'exception': e.toString(),
      };

      LogService.instance.logRequest('BIOS_SUMMARY', res);
      return res;
    }
  }

  Future<Map<String, dynamic>> getUuidHostnameDomainIp() async {
    final hostname = Platform.localHostname; // OK siempre
    final domainEnv = (Platform.environment['USERDOMAIN'] ?? '').trim();

    // IPs por Dart (no depende de PowerShell)
    final ips = await _getLocalIps();

    // Dominio real (AD/Workgroup) por PowerShell (si devuelve)
    final domainPs = await _tryGetDomainByPowerShell();

    // UUID “tipo BIOS” (Win32_ComputerSystemProduct.UUID)
    final uuidPs = await _tryGetUuidByPowerShell();

    final res = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'hostname': hostname,
      'domain_env': domainEnv.isEmpty ? null : domainEnv,
      'domain_ps': domainPs,
      'uuid': uuidPs,
      'ips': ips,
      'platform': Platform.operatingSystem,
      'platform_version': Platform.operatingSystemVersion,
    };

    LogService.instance.logRequest('MACHINE_INFO', res);
    return res;
  }

  Future<List<String>> _getLocalIps() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.any,
      );

      final ips = <String>{};
      for (final i in interfaces) {
        for (final a in i.addresses) {
          // Filtra link-local y cosas raras si quieres
          if (a.isLoopback) continue;
          final ip = a.address.trim();
          if (ip.isEmpty) continue;
          ips.add(ip);
        }
      }
      return ips.toList()..sort();
    } catch (e, st) {
      LogService.instance.logError('GET_IPS_FAIL', e, st);
      return [];
    }
  }

  Future<String?> _tryGetUuidByPowerShell() async {
    if (!Platform.isWindows) return null;

    // UUID del “ComputerSystemProduct” (SMBIOS/System UUID)
    final script = r'''
$ErrorActionPreference = "SilentlyContinue";
$u = (Get-CimInstance Win32_ComputerSystemProduct).UUID
if ($u) { $u.ToString() }
''';

    final out = await _runPowerShell(script);
    final raw = (out['stdout'] ?? '').toString().trim();

    if (out['exitCode'] == 0 && raw.isNotEmpty) {
      LogService.instance.logRequest('UUID_PS_OK', {'uuid': raw});
      return raw;
    }

    LogService.instance.logRequest('UUID_PS_EMPTY', {
      'exitCode': out['exitCode'],
      'stderr': out['stderr'],
    });
    return null;
  }

  Future<String?> _tryGetDomainByPowerShell() async {
    if (!Platform.isWindows) return null;

    // Win32_ComputerSystem.Domain (dominio o workgroup)
    final script = r'''
$ErrorActionPreference = "SilentlyContinue";
$d = (Get-CimInstance Win32_ComputerSystem).Domain
if ($d) { $d.ToString() }
''';

    final out = await _runPowerShell(script);
    final raw = (out['stdout'] ?? '').toString().trim();

    if (out['exitCode'] == 0 && raw.isNotEmpty) {
      LogService.instance.logRequest('DOMAIN_PS_OK', {'domain': raw});
      return raw;
    }

    LogService.instance.logRequest('DOMAIN_PS_EMPTY', {
      'exitCode': out['exitCode'],
      'stderr': out['stderr'],
    });
    return null;
  }
}
