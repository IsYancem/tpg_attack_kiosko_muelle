class DescargaApiResponse {
  final int errorCode;
  final String message;
  final Map<String, dynamic>? data;

  DescargaApiResponse({
    required this.errorCode,
    required this.message,
    this.data,
  });

  factory DescargaApiResponse.fromJson(Map<String, dynamic> json) {
    return DescargaApiResponse(
      errorCode: int.tryParse(json['errorCode']?.toString() ?? '1') ?? 1,
      message: json['message']?.toString() ?? '',
      data: json['data'] is Map<String, dynamic>
          ? json['data'] as Map<String, dynamic>
          : null,
    );
  }

  Map<String, dynamic> toManagerMap() {
    final m = <String, dynamic>{};

    if (data == null) return m;

    final dataMap = data!;

    final services = dataMap['services'] is Map<String, dynamic>
        ? dataMap['services'] as Map<String, dynamic>
        : <String, dynamic>{};

    final vars = dataMap['vars'] is Map<String, dynamic>
        ? dataMap['vars'] as Map<String, dynamic>
        : <String, dynamic>{};

    final porteoStep = services['atkGetPorteo2'];
    final personStep = services['atkGetDataPerson'];

    final porteoData =
        porteoStep is Map<String, dynamic> &&
            porteoStep['data'] is Map<String, dynamic>
        ? porteoStep['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    final personData =
        personStep is Map<String, dynamic> &&
            personStep['data'] is Map<String, dynamic>
        ? personStep['data'] as Map<String, dynamic>
        : <String, dynamic>{};

    final firstName = (personData['FIRSTNAME'] ?? '').toString().trim();
    final lastName = (personData['LASTNAME'] ?? '').toString().trim();
    final fullName = '$firstName $lastName'.trim();

    // Datos generales
    m['transactionType'] = 'DES';
    m['tituloPantalla'] = 'Descarga de contenedor';

    // Mantener compatibilidad anterior
    if (dataMap['contenedor'] != null) {
      m['contenedor'] = dataMap['contenedor']?.toString();
    }

    if (dataMap['tara'] != null) {
      m['pesoTara'] = dataMap['tara']?.toString();
    }

    // Vars del inicializador
    if (vars['placa'] != null) {
      m['vehiculoPlaca'] = vars['placa']?.toString();
    }

    if (vars['peso'] != null) {
      m['pesoIngreso'] = vars['peso']?.toString();
      m['pesoActualBascula'] =
          double.tryParse(vars['peso']?.toString() ?? '0') ?? 0.0;
    }

    if (vars['porteo'] != null) {
      m['pesoPorteo'] = vars['porteo']?.toString();
    }

    if (vars['pesoCarga'] != null) {
      m['pesoSalida'] = vars['pesoCarga']?.toString();
    }

    // Resultado atkGetPorteo2
    if (porteoData.isNotEmpty) {
      m['descargaValida'] = porteoData['valida']?.toString();
      m['descargaChofer'] = porteoData['chofer']?.toString();
      m['descargaError'] = porteoData['error']?.toString();
      m['descargaMensaje'] = porteoData['desc_error']?.toString();
    }

    // Datos del chofer
    // Datos del chofer
    if (personData.isNotEmpty) {
      m['driverCedula'] = personData['IDENTIFICATIONNUMBER']?.toString();

      m['driverFirstName'] = firstName;
      m['driverLastName'] = lastName;
      m['driverFullName'] = fullName;
      m['driverName'] = fullName;

      m['driverLicenciaTipo'] = personData['LICENCETYPE']?.toString();
      m['driverLicenciaExp'] = personData['LICENSEEXPIRATIONDATE']?.toString();
      m['driverEmpresa'] = personData['NAME']?.toString();
      m['driverRucEmpresa'] = personData['RUC']?.toString();
      m['driverId'] = personData['ID']?.toString();
      m['driverAlerta'] = personData['ERRORMSG']?.toString();

      m['IDENTIFICATIONNUMBER1'] = personData['IDENTIFICATIONNUMBER']
          ?.toString();
      m['FIRSTNAME1'] = firstName;
      m['LASTNAME1'] = lastName;
      m['NOMBRES_COMPLETOS1'] = fullName;
      m['LICENCETYPE1'] = personData['LICENCETYPE']?.toString();
      m['LICENSEEXPIRATIONDATE1'] = personData['LICENSEEXPIRATIONDATE']
          ?.toString();
    }

    // Raw para debug
    m['descargaInitialRaw'] = dataMap;
    m['descargaInitialServices'] = services;
    m['descargaInitialVars'] = vars;

    return m;
  }
}
