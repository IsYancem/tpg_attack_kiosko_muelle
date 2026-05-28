// lib/models/datos/conseguir_data_conductor_model.dart

typedef JsonMap = Map<String, dynamic>;

class ConseguirDataConductorRequest {
  final String? ruc;

  const ConseguirDataConductorRequest({
    required this.ruc,
  });

  JsonMap toJson() => {
        'ruc': ruc?.trim().toUpperCase(),
      };
}

class ConseguirDataConductorResponse {
  final String? ruc;
  final DataConductorRow? conductor;
  final ConseguirDataConductorServices? services;

  const ConseguirDataConductorResponse({
    required this.ruc,
    required this.conductor,
    required this.services,
  });

  factory ConseguirDataConductorResponse.fromJson(JsonMap json) {
    return ConseguirDataConductorResponse(
      ruc: json['ruc']?.toString(),
      conductor: json['conductor'] is JsonMap
          ? DataConductorRow.fromJson(
              Map<String, dynamic>.from(json['conductor'] as JsonMap),
            )
          : null,
      services: json['services'] is JsonMap
          ? ConseguirDataConductorServices.fromJson(
              Map<String, dynamic>.from(json['services'] as JsonMap),
            )
          : null,
    );
  }

  JsonMap toJson() => {
        'ruc': ruc,
        'conductor': conductor?.toJson(),
        'services': services?.toJson(),
      };
}

class DataConductorRow {
  final String? enrollCode;
  final String? code;
  final String? identificationNumber;
  final String? firstName;
  final String? lastName;
  final int? accessLevel;
  final int? typeId;
  final int? statusId;
  final int? hasLicense;
  final String? licenseType;
  final String? licenseExpirationDate;
  final int? state;
  final String? ruc;
  final String? companyName;
  final int errorCode;
  final String errorMsg;
  final int? id;
  final int? idCompany;

  const DataConductorRow({
    required this.enrollCode,
    required this.code,
    required this.identificationNumber,
    required this.firstName,
    required this.lastName,
    required this.accessLevel,
    required this.typeId,
    required this.statusId,
    required this.hasLicense,
    required this.licenseType,
    required this.licenseExpirationDate,
    required this.state,
    required this.ruc,
    required this.companyName,
    required this.errorCode,
    required this.errorMsg,
    required this.id,
    required this.idCompany,
  });

  factory DataConductorRow.fromJson(JsonMap json) {
    return DataConductorRow(
      enrollCode: json['ENROLLCODE']?.toString(),
      code: json['CODE']?.toString(),
      identificationNumber: json['IDENTIFICATIONNUMBER']?.toString().trim(),
      firstName: json['FIRSTNAME']?.toString().trim(),
      lastName: json['LASTNAME']?.toString().trim(),
      accessLevel: _toInt(json['ACCESSLEVEL']),
      typeId: _toInt(json['TYPEID']),
      statusId: _toInt(json['STATUSID']),
      hasLicense: _toInt(json['HASLICENSE']),
      licenseType: json['LICENCETYPE']?.toString().trim(),
      licenseExpirationDate: json['LICENSEEXPIRATIONDATE']?.toString(),
      state: _toInt(json['STATE']),
      ruc: json['RUC']?.toString().trim(),
      companyName: json['NAME']?.toString().trim(),
      errorCode: _toInt(json['ERRORCODE']) ?? 1,
      errorMsg: json['ERRORMSG']?.toString() ?? '',
      id: _toInt(json['ID']),
      idCompany: _toInt(json['IDCOMPANY']),
    );
  }

  bool get isOk => errorCode == 0;

  String get fullName {
    final f = firstName?.trim() ?? '';
    final l = lastName?.trim() ?? '';
    return '$f $l'.trim();
  }

  JsonMap toJson() => {
        'ENROLLCODE': enrollCode,
        'CODE': code,
        'IDENTIFICATIONNUMBER': identificationNumber,
        'FIRSTNAME': firstName,
        'LASTNAME': lastName,
        'ACCESSLEVEL': accessLevel,
        'TYPEID': typeId,
        'STATUSID': statusId,
        'HASLICENSE': hasLicense,
        'LICENCETYPE': licenseType,
        'LICENSEEXPIRATIONDATE': licenseExpirationDate,
        'STATE': state,
        'RUC': ruc,
        'NAME': companyName,
        'ERRORCODE': errorCode,
        'ERRORMSG': errorMsg,
        'ID': id,
        'IDCOMPANY': idCompany,
      };

  static int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }
}

class ConseguirDataConductorServices {
  final ConseguirDataConductorStep? atkGetDataPerson;

  const ConseguirDataConductorServices({
    required this.atkGetDataPerson,
  });

  factory ConseguirDataConductorServices.fromJson(JsonMap json) {
    return ConseguirDataConductorServices(
      atkGetDataPerson: json['atkGetDataPerson'] is JsonMap
          ? ConseguirDataConductorStep.fromJson(
              Map<String, dynamic>.from(json['atkGetDataPerson'] as JsonMap),
            )
          : null,
    );
  }

  JsonMap toJson() => {
        'atkGetDataPerson': atkGetDataPerson?.toJson(),
      };
}

class ConseguirDataConductorStep {
  final int errorCode;
  final String message;
  final DataConductorRow? data;

  const ConseguirDataConductorStep({
    required this.errorCode,
    required this.message,
    required this.data,
  });

  factory ConseguirDataConductorStep.fromJson(JsonMap json) {
    return ConseguirDataConductorStep(
      errorCode: DataConductorRow._toInt(json['errorCode']) ?? 1,
      message: json['message']?.toString() ?? '',
      data: json['data'] is JsonMap
          ? DataConductorRow.fromJson(
              Map<String, dynamic>.from(json['data'] as JsonMap),
            )
          : null,
    );
  }

  JsonMap toJson() => {
        'errorCode': errorCode,
        'message': message,
        'data': data?.toJson(),
      };
}