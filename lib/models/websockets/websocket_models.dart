// lib/models/websockets/websocket_models.dart
// Autor: Abraham Yance
// Actualizado: 2025-11-21
// 🚀 Modelos de respuesta WebSocket unificados

/// Helpers para parseo robusto
String tStr(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) {
      return json[key].toString();
    }
  }
  return '';
}

int tInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key) && json[key] != null) {
      final val = json[key];
      return val is int ? val : int.tryParse(val.toString()) ?? 0;
    }
  }
  return 0;
}

/// Modelo base para todas las respuestas WebSocket
abstract class WebSocketResponse {
  final int code;
  final String message;
  final int gate;
  final int side;

  const WebSocketResponse({
    required this.code,
    required this.message,
    required this.gate,
    required this.side,
  });

  bool get isSuccess => code == 0;
  bool get hasError => code != 0;
}

/// ============================================================================
/// VEHICLE RESPONSE MODEL
/// ============================================================================
class VehicleResponse extends WebSocketResponse {
  final VehicleRecord? record;

  const VehicleResponse({
    required super.code,
    required super.message,
    required super.gate,
    required super.side,
    this.record,
  });

  factory VehicleResponse.fromJson(Map<String, dynamic> json) {
    final recordRaw = json['record'];

    return VehicleResponse(
      code: json['code'] ?? -1,
      message: json['message'] ?? '',
      gate: json['gate'] ?? 0,
      side: json['side'] ?? 0,
      record: (recordRaw is Map<String, dynamic>)
          ? VehicleRecord.fromJson(recordRaw)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'gate': gate,
      'side': side,
      'record': record?.toJson(),
    };
  }
}

class VehicleRecord {
  final String regNumber;
  final String rfid;
  final String brand;
  final String model;
  final String color;
  final String company;
  final String idcompany;
  final String idvehicle;
  final String hexastring;
  final String message;
  final int state;

  const VehicleRecord({
    required this.regNumber,
    required this.rfid,
    required this.brand,
    required this.model,
    required this.color,
    required this.company,
    required this.idcompany,
    required this.idvehicle,
    required this.hexastring,
    required this.message,
    required this.state,
  });

  factory VehicleRecord.fromJson(Map<String, dynamic> json) {
    return VehicleRecord(
      regNumber: tStr(json, ['RegNumber', 'regNumber', 'regnumber']),
      rfid: tStr(json, ['Rfid', 'rfid']),
      brand: tStr(json, ['Brand', 'brand']),
      model: tStr(json, ['Model', 'model']),
      color: tStr(json, ['Color', 'color']),
      company: tStr(json, ['Company', 'company']),
      idcompany: tStr(json, ['idCompany', 'idcompany']),
      idvehicle: tStr(json, ['idVehicle', 'idvehicle']),
      hexastring: tStr(json, ['Hexastring', 'hexastring']),
      message: tStr(json, ['Message', 'message']),
      state: tInt(json, ['State', 'state']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'regNumber': regNumber,
      'rfid': rfid,
      'brand': brand,
      'model': model,
      'color': color,
      'company': company,
      'idVehicle': idvehicle,
      'idCompany': idvehicle,
      'hexastring': hexastring,
      'message': message,
      'state': state,
    };
  }
}

/// ============================================================================
/// EMPLOYEE RESPONSE MODEL
/// ============================================================================
class EmployeeResponse extends WebSocketResponse {
  final EmployeeRecord? record;
  final String sn;
  final String now;

  const EmployeeResponse({
    required super.code,
    required super.message,
    required super.gate,
    required super.side,
    required this.sn,
    required this.now,
    this.record,
  });

  factory EmployeeResponse.fromJson(Map<String, dynamic> json) {
    final hasNestedRecord =
        json['record'] != null && json['record'] is Map<String, dynamic>;

    if (hasNestedRecord) {
      return EmployeeResponse(
        code: json['code'] is int
            ? json['code']
            : int.tryParse('${json['code']}') ?? -1,
        message: json['message']?.toString() ?? '',
        gate: json['gate'] is int
            ? json['gate']
            : int.tryParse('${json['gate']}') ?? 0,
        side: json['side'] is int
            ? json['side']
            : int.tryParse('${json['side']}') ?? 0,
        sn: tStr(json, ['sn', 'SN']),
        now: tStr(json, ['now', 'Now']),
        record: EmployeeRecord.fromJson(json['record'] as Map<String, dynamic>),
      );
    }

    // ✅ Formato facial plano
    final employee = EmployeeRecord.fromFaceFlatJson(json);

    return EmployeeResponse(
      code: 0, // se considera lectura válida si pudo parsearse
      message: 'Lectura facial recibida',
      gate: 0,
      side: 0,
      sn: tStr(json, ['sn', 'SN']),
      now: tStr(json, ['now', 'Now']),
      record: employee,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
      'gate': gate,
      'side': side,
      'sn': sn,
      'now': now,
      'record': record?.toJson(),
    };
  }
}

class EmployeeRecord {
  final String identificationNumber;
  final int code;
  final String name;
  final int typeId;
  final String profile;
  final String company;
  final String message;
  final int license;
  final String licenseExpirationDate;
  final String urlFace;
  final String stateText;
  final int state;

  const EmployeeRecord({
    required this.identificationNumber,
    required this.code,
    required this.name,
    required this.typeId,
    required this.profile,
    required this.company,
    required this.message,
    required this.license,
    required this.licenseExpirationDate,
    required this.urlFace,
    required this.stateText,
    required this.state,
  });

  factory EmployeeRecord.fromJson(Map<String, dynamic> json) {
    return EmployeeRecord(
      identificationNumber: tStr(json, [
        'identificationnumber',
        'Identificationnumber',
        'IdentificationNumber',
        'identificationNumber',
      ]),
      code: tInt(json, ['Code', 'code']),
      name: tStr(json, ['Name', 'name']),
      typeId: tInt(json, ['TypeId', 'typeId']),
      profile: tStr(json, ['Profile', 'profile']),
      company: tStr(json, ['Company', 'company']),
      message: tStr(json, ['Message', 'message']),
      license: tInt(json, ['License', 'license']),
      licenseExpirationDate: tStr(json, [
        'LicenseExpirationDate',
        'licenseExpirationDate',
      ]),
      urlFace: tStr(json, ['UrlFace', 'urlFace']),
      stateText: tStr(json, ['StateText', 'stateText', 'state']),
      state: tInt(json, ['State', 'state']),
    );
  }

  factory EmployeeRecord.fromFaceFlatJson(Map<String, dynamic> json) {
    final rawState = tStr(json, ['state', 'State']).toUpperCase();

    return EmployeeRecord(
      identificationNumber: tStr(json, [
        'identificationnumber',
        'Identificationnumber',
        'IdentificationNumber',
        'identificationNumber',
      ]),
      code: tInt(json, ['code', 'Code']),
      name: tStr(json, ['name', 'Name']),
      typeId: 0,
      profile: tStr(json, ['profile', 'Profile']),
      company: '',
      message: '',
      license: 0,
      licenseExpirationDate: tStr(json, [
        'licenseexpirationdate',
        'LicenseExpirationDate',
        'licenseExpirationDate',
      ]),
      urlFace: '',
      stateText: rawState,
      state: rawState == 'ACTIVO' ? 1 : 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'identificationNumber': identificationNumber,
      'code': code,
      'name': name,
      'typeId': typeId,
      'profile': profile,
      'company': company,
      'message': message,
      'license': license,
      'licenseExpirationDate': licenseExpirationDate,
      'urlFace': urlFace,
      'stateText': stateText,
      'state': state,
    };
  }
}

/// ============================================================================
/// WEIGHT RESPONSE MODEL
/// ============================================================================
class WeightRecord {
  final double weight;

  WeightRecord({required this.weight});

  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    // Puede venir como "Weight", "weight" o incluso string
    final dynamic raw = json['Weight'] ?? json['weight'] ?? json['WEIGHT'] ?? 0;

    double parsed;

    if (raw is num) {
      parsed = raw.toDouble();
    } else if (raw is String) {
      parsed = double.tryParse(raw) ?? 0;
    } else {
      parsed = 0;
    }

    return WeightRecord(weight: parsed);
  }
}

class WeightResponse {
  final int code;
  final String message;
  final int gate;
  final WeightRecord? record;

  bool get isSuccess => code == 0;

  WeightResponse({
    required this.code,
    required this.message,
    required this.gate,
    required this.record,
  });

  factory WeightResponse.fromJson(Map<String, dynamic> json) {
    final dynamic recordRaw = json['record'];

    WeightRecord? parsedRecord;

    if (recordRaw is Map<String, dynamic>) {
      parsedRecord = WeightRecord.fromJson(recordRaw);
    } else if (json.containsKey('weight') ||
        json.containsKey('Weight') ||
        json.containsKey('WEIGHT')) {
      parsedRecord = WeightRecord.fromJson(json);
    } else {
      parsedRecord = null;
    }

    return WeightResponse(
      code: json['code'] ?? 0,
      message: json['message']?.toString() ?? '',
      gate: json['gate'] ?? 0,
      record: parsedRecord,
    );
  }
}
