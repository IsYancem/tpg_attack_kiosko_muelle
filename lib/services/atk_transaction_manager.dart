// lib/services/atk_transaction_manager.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AtkTransactionManager extends ChangeNotifier {
  // ── Backing store ──────────────────────────────────────────────────────────
  final Map<String, dynamic> _d = {};

  // ── API genérica ───────────────────────────────────────────────────────────

  Map<String, dynamic> get data => _d;

  dynamic get(String key) => _d[key];

  void set(String key, dynamic value) {
    _d[key] = value;
    notifyListeners();
  }

  void setMany(Map<String, dynamic> values) {
    _d.addAll(values);
    notifyListeners();
  }

  void setManyWithoutNotify(Map<String, dynamic> values) => _d.addAll(values);

  // ── Helpers de coerción ────────────────────────────────────────────────────

  static int? _int(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  static double? _dbl(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return null;
  }

  static bool? _bool(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true' || s == '1' || s == 's' || s == 'y') return true;
      if (s == 'false' || s == '0' || s == 'n') return false;
    }
    return null;
  }

  static List<String> _strList(dynamic v) {
    if (v is List<String>) return v;
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }

  // ── Estado general ─────────────────────────────────────────────────────────

  bool get transaccionActiva => _d['transaccionActiva'] as bool? ?? false;
  set transaccionActiva(bool v) {
    _d['transaccionActiva'] = v;
    notifyListeners();
  }

  bool get isLoading => _d['isLoading'] as bool? ?? false;
  bool get hasError => _d['hasError'] as bool? ?? false;
  String? get errorMessage => _d['errorMessage'] as String?;
  bool get loading => isLoading;

  void setTransaccionActiva(bool v) {
    _d['transaccionActiva'] = v;
    notifyListeners();
  }

  void setLoading(bool v) => set('isLoading', v);

  void setError(String message) {
    _d['hasError'] = true;
    _d['errorMessage'] = message;
    notifyListeners();
  }

  void clearError() {
    _d['hasError'] = false;
    _d['errorMessage'] = null;
    notifyListeners();
  }

  // ── Datos generales ────────────────────────────────────────────────────────

  String? get tituloPantalla => _d['tituloPantalla'] as String?;
  String? get transactionType => _d['transactionType'] as String?;
  String? get atkId => _d['atkId'] as String?;
  String? get numTrans => _d['numTrans'] as String?;
  String? get driverName => _d['driverName'] as String?;
  String? get sideGate => _d['sideGate'] as String?;

  // ── Metadata orquestador ──────────────────────────────────────────────────

  int? get metadataElapsedMs => _int(_d['metadataElapsedMs']);
  int? get metadataTotalSteps => _int(_d['metadataTotalSteps']);
  int? get metadataSuccessfulSteps => _int(_d['metadataSuccessfulSteps']);
  List<String> get metadataFailures => _strList(_d['metadataFailures']);
  String? get metadataFatalError => _d['metadataFatalError'] as String?;

  // ── Conductor ─────────────────────────────────────────────────────────────

  String? get driverPhotoUrl => _d['driverPhotoUrl'] as String?;
  String? get driverCedula => _d['driverCedula'] as String?;
  String? get driverLicenciaExp => _d['driverLicenciaExp'] as String?;
  String? get driverLicenciaTipo => _d['driverLicenciaTipo'] as String?;
  String? get driverEmpresa => _d['driverEmpresa'] as String?;
  String? get driverRucEmpresa => _d['driverRucEmpresa'] as String?;
  String? get driverAlerta => _d['driverAlerta'] as String?;
  String? get driverId => _d['driverId'] as String?;

  // ── Vehículo ──────────────────────────────────────────────────────────────

  String? get vehiculoPlaca => _d['vehiculoPlaca'] as String?;
  String? get vehiculoTipoCarga => _d['vehiculoTipoCarga'] as String?;
  String? get vehiculoProducto => _d['vehiculoProducto'] as String?;
  String? get vehiculoRefrigerado => _d['vehiculoRefrigerado'] as String?;
  String? get vehiculoCargaImo => _d['vehiculoCargaImo'] as String?;
  String? get vehiculoBooking => _d['vehiculoBooking'] as String?;
  String? get vehiculoNave => _d['vehiculoNave'] as String?;
  String? get vehiculoObservaciones => _d['vehiculoObservaciones'] as String?;
  String? get vehiculoRfid => _d['vehiculoRfid'] as String?;
  String? get vehiculoMarca => _d['vehiculoMarca'] as String?;
  String? get vehiculoModelo => _d['vehiculoModelo'] as String?;
  String? get vehiculoColor => _d['vehiculoColor'] as String?;
  String? get vehiculoEmpresa => _d['vehiculoEmpresa'] as String?;
  String? get vehiculoEstado => _d['vehiculoEstado'] as String?;
  String? get vehiculoMensaje => _d['vehiculoMensaje'] as String?;

  // ── Importador / Carga ────────────────────────────────────────────────────

  String? get importador => _d['importador'] as String?;
  String? get dres => _d['dres'] as String?;
  String? get contenedor => _d['contenedor'] as String?;
  String? get ubicacion => _d['ubicacion'] as String?;
  String? get turno => _d['turno'] as String?;

  // ── Ponchado DSP ──────────────────────────────────────────────────────────

  int? get ponchadoCodChofer => _int(_d['ponchadoCodChofer']);
  String? get ponchadoCargaSuelta => _d['ponchadoCargaSuelta'] as String?;
  int? get ponchadoPatio => _int(_d['ponchadoPatio']);
  int? get ponchadoAniodres1 => _int(_d['ponchadoAniodres1']);
  int? get ponchadoCordres1 => _int(_d['ponchadoCordres1']);
  int? get ponchadoAniodres2 => _int(_d['ponchadoAniodres2']);
  int? get ponchadoCordres2 => _int(_d['ponchadoCordres2']);
  double? get ponchadoPesoBultos => _dbl(_d['ponchadoPesoBultos']);
  int? get ponchadoTotalBultos => _int(_d['ponchadoTotalBultos']);
  int? get ponchadoNumregAtk => _int(_d['ponchadoNumregAtk']);
  int? get ponchadoCargaNoPesable => _int(_d['ponchadoCargaNoPesable']);
  String? get ponchadoDai => _d['ponchadoDai'] as String?;
  String? get ponchadoPonchadoWeb => _d['ponchadoPonchadoWeb'] as String?;
  String? get ponchadoFechaProgramado =>
      _d['ponchadoFechaProgramado'] as String?;

  // ── Pesos ─────────────────────────────────────────────────────────────────

  String? get pesoIngreso => _d['pesoIngreso'] as String?;
  String? get pesoSalida => _d['pesoSalida'] as String?;
  String? get pesoTara => _d['pesoTara'] as String?;
  String? get pesoPorteo => _d['pesoPorteo'] as String?;

  double? get validarPesoRecibido => _dbl(_d['validarPesoRecibido']);
  double? get validarPesoValidado => _dbl(_d['validarPesoValidado']);
  double? get validarPesoParseado => _dbl(_d['validarPesoParseado']);
  bool? get validarPesoEsValido => _d['validarPesoEsValido'] as bool?;

  double get pesoActualBascula => _dbl(_d['pesoActualBascula']) ?? 0.0;
  set pesoActualBascula(double v) => _d['pesoActualBascula'] = v;
  void setPesoActualBascula(double v) => set('pesoActualBascula', v);

  // ── Traslado TRL ──────────────────────────────────────────────────────────

  String? get origenTrl => _d['origenTrl'] as String?;
  String? get destinoTrl => _d['destinoTrl'] as String?;

  List<String> get origenTrlOptions =>
      _strList(_d['origenTrlOptions'] ?? const ['TPG A', 'TPG B', 'TPG C']);
  List<String> get destinoTrlOptions =>
      _strList(_d['destinoTrlOptions'] ?? const ['TPG A', 'TPG B', 'TPG C']);

  // ── Mapa / Imagen ─────────────────────────────────────────────────────────

  ImageProvider? get mapaUbicacion => _d['mapaUbicacion'] as ImageProvider?;
  String? get mapaUrl => _d['mapaUrl'] as String?;
  Uint8List? get mapaBytes => _d['mapaBytes'] as Uint8List?;

  // ── Contenedores ──────────────────────────────────────────────────────────

  String? get contenedor1 => _d['contenedor1'] as String?;
  String? get contenedor2 => _d['contenedor2'] as String?;
  String? get sello1 => _d['sello1'] as String?;
  String? get sello2 => _d['sello2'] as String?;
  String? get sello3 => _d['sello3'] as String?;
  String? get sello4 => _d['sello4'] as String?;
  String? get sello5 => _d['sello5'] as String?;
  String? get detalle1 => _d['detalle1'] as String?;
  String? get detalle2 => _d['detalle2'] as String?;

  // DSP: Cons Contenedor x Dres
  int? get consCntCodError => _int(_d['consCntCodError']);
  String? get consCntDesError => _d['consCntDesError'] as String?;
  int? get consCntAnoOperacion => _int(_d['consCntAnoOperacion']);
  int? get consCntCorOperacion => _int(_d['consCntCorOperacion']);
  String? get consCntCodSigla => _d['consCntCodSigla'] as String?;
  int? get consCntCodNumero => _int(_d['consCntCodNumero']);
  String? get consCntCodDigito => _d['consCntCodDigito'] as String?;
  String? get consCntUbicacion => _d['consCntUbicacion'] as String?;

  // DSP: Barrera
  bool? get barreraSkipped => _d['barreraSkipped'] as bool?;
  String? get barreraReason => _d['barreraReason'] as String?;
  int? get barreraGate => _int(_d['barreraGate']);
  int? get barreraVehicleAccessId => _int(_d['barreraVehicleAccessId']);
  bool? get barreraUnlocked => _d['barreraUnlocked'] as bool?;

  // ── Mensaje inferior ──────────────────────────────────────────────────────

  String? get mensajeInferior => _d['mensajeInferior'] as String?;
  set mensajeInferior(String? v) => _d['mensajeInferior'] = v;

  // ── Exportador EXP ────────────────────────────────────────────────────────

  String? get clienteExp => _d['clienteExp'] as String?;
  String? get productoExp => _d['productoExp'] as String?;
  String? get bookingExp => _d['bookingExp'] as String?;
  String? get naveExp => _d['naveExp'] as String?;
  String? get contenedorExp => _d['contenedorExp'] as String?;
  String? get sello1Exp => _d['sello1Exp'] as String?;
  String? get sello2Exp => _d['sello2Exp'] as String?;
  String? get sello3Exp => _d['sello3Exp'] as String?;
  String? get sello4Exp => _d['sello4Exp'] as String?;
  String? get daniosExp => _d['daniosExp'] as String?;

  Map<String, dynamic>? get rutaResult =>
      _d['rutaResult'] as Map<String, dynamic>?;

  // ── DISV ──────────────────────────────────────────────────────────────────

  int? get aniodisv => _int(_d['aniodisv']);
  int? get numdisv => _int(_d['numdisv']);
  int? get idTraslados => _int(_d['idTraslados']);

  // ── TRL: Contenedor 1 ─────────────────────────────────────────────────────

  int? get trlAnoOperacion1 => _int(_d['trlAnoOperacion1']);
  int? get trlCorOperacion1 => _int(_d['trlCorOperacion1']);
  String? get trlOrigen1 => _d['trlOrigen1'] as String?;
  String? get trlDestino1 => _d['trlDestino1'] as String?;
  String? get trlAreaOrigen1 => _d['trlAreaOrigen1'] as String?;
  String? get trlAreaDestino1 => _d['trlAreaDestino1'] as String?;
  String? get trlBl1 => _d['trlBl1'] as String?;
  String? get trlDocTransporte1 => _d['trlDocTransporte1'] as String?;
  String? get trlRutaTraslado1 => _d['trlRutaTraslado1'] as String?;
  int? get trlSalidaNum1 => _int(_d['trlSalidaNum1']);
  int? get trlMaeId1 => _int(_d['trlMaeId1']);
  String? get trlZonaPrimariaOrigen1 =>
      _d['trlZonaPrimariaOrigen1'] as String?;
  String? get trlZonaPrimariaDestino1 =>
      _d['trlZonaPrimariaDestino1'] as String?;
  String? get trlFechaEstTraslado1 => _d['trlFechaEstTraslado1'] as String?;
  bool? get trlNotificarStm1 => _bool(_d['trlNotificarStm1']);
  String? get trlDetalle1 => _d['trlDetalle1'] as String?;
  String? get trlFecha1 => _d['trlFecha1'] as String?;
  String? get trlHora1 => _d['trlHora1'] as String?;
  double? get trlPeso1 => _dbl(_d['trlPeso1']);
  double? get trlTara1 => _dbl(_d['trlTara1']);
  String? get trlRucEmpresaTransporte1 =>
      _d['trlRucEmpresaTransporte1'] as String?;
  String? get trlNombreEmpresaTransporte1 =>
      _d['trlNombreEmpresaTransporte1'] as String?;

  // ── TRL: Contenedor 2 ─────────────────────────────────────────────────────

  int? get trlAnoOperacion2 => _int(_d['trlAnoOperacion2']);
  int? get trlCorOperacion2 => _int(_d['trlCorOperacion2']);
  String? get trlOrigen2 => _d['trlOrigen2'] as String?;
  String? get trlDestino2 => _d['trlDestino2'] as String?;
  String? get trlAreaOrigen2 => _d['trlAreaOrigen2'] as String?;
  String? get trlAreaDestino2 => _d['trlAreaDestino2'] as String?;
  String? get trlBl2 => _d['trlBl2'] as String?;
  String? get trlDocTransporte2 => _d['trlDocTransporte2'] as String?;
  String? get trlDetalle2 => _d['trlDetalle2'] as String?;

  // ── TRL: Transacciones y Monitor ──────────────────────────────────────────

  int? get trlNumeroTransaccion1 => _int(_d['trlNumeroTransaccion1']);
  int? get trlNumeroTransaccion2 => _int(_d['trlNumeroTransaccion2']);

  bool? get trlMonitorSent => _d['trlMonitorSent'] as bool?;
  String? get trlMonitorTransaccion => _d['trlMonitorTransaccion'] as String?;
  String? get trlMonitorTipoMov => _d['trlMonitorTipoMov'] as String?;
  String? get trlMonitorBarrera => _d['trlMonitorBarrera'] as String?;
  String? get trlMonitorFechaBarrera =>
      _d['trlMonitorFechaBarrera'] as String?;
  bool? get trlShowContenedor2 => _d['trlShowContenedor2'] as bool?;

  // ── EXM: Snapshots ────────────────────────────────────────────────────────

  Map<String, dynamic>? get exmInicializarRaw =>
      _d['exmInicializarRaw'] as Map<String, dynamic>?;
  Map<String, dynamic>? get exmInicializarData =>
      _d['exmInicializarData'] as Map<String, dynamic>?;
  Map<String, dynamic>? get exmResolved =>
      _d['exmResolved'] as Map<String, dynamic>?;
  Map<String, dynamic>? get exmMonitorRequested =>
      _d['exmMonitorRequested'] as Map<String, dynamic>?;
  Map<String, dynamic>? get exmMonitorSent =>
      _d['exmMonitorSent'] as Map<String, dynamic>?;
  Map<String, dynamic>? get exmServices =>
      _d['exmServices'] as Map<String, dynamic>?;

  // ── EXM: Resolved tipado ──────────────────────────────────────────────────

  String? get exmContenedorSource => _d['exmContenedorSource'] as String?;
  bool? get exmContenedorLocked => _bool(_d['exmContenedorLocked']);
  String? get exmPesa => _d['exmPesa'] as String?;
  String? get exmFechaIng => _d['exmFechaIng'] as String?;
  String? get exmCodEmpresa => _d['exmCodEmpresa'] as String?;

  // ── EXM: Monitor tipado ───────────────────────────────────────────────────

  String? get exmMonitorAccion => _d['exmMonitorAccion'] as String?;
  String? get exmMonitorPatio => _d['exmMonitorPatio'] as String?;
  String? get exmMonitorBascula => _d['exmMonitorBascula'] as String?;
  String? get exmMonitorNumBascula => _d['exmMonitorNumBascula'] as String?;
  String? get exmMonitorBarrera => _d['exmMonitorBarrera'] as String?;
  String? get exmMonitorFechaBarrera =>
      _d['exmMonitorFechaBarrera'] as String?;
  String? get exmMonitorTransaccion => _d['exmMonitorTransaccion'] as String?;
  String? get exmMonitorTipoMov => _d['exmMonitorTipoMov'] as String?;
  String? get exmMonitorContenedor => _d['exmMonitorContenedor'] as String?;
  String? get exmMonitorInOut => _d['exmMonitorInOut'] as String?;
  int? get exmMonitorVehicleAccessId =>
      _int(_d['exmMonitorVehicleAccessId']);
  String? get exmMonitorCedula => _d['exmMonitorCedula'] as String?;
  String? get exmMonitorNombres => _d['exmMonitorNombres'] as String?;
  String? get exmMonitorFoto => _d['exmMonitorFoto'] as String?;
  String? get exmMonitorIp => _d['exmMonitorIp'] as String?;
  int? get exmMonitorPuerto => _int(_d['exmMonitorPuerto']);
  bool? get exmMonitorOk => _bool(_d['exmMonitorOk']);

  // ── OCR Muelle ────────────────────────────────────────────────────────────

  String? get ocrTransitId => _d['ocrTransitId'] as String?;
  String? get ocrLocation => _d['ocrLocation'] as String?;
  String? get ocrVehicleType => _d['ocrVehicleType'] as String?;
  String? get ocrContainerCount => _d['ocrContainerCount'] as String?;
  String? get ocrNote => _d['ocrNote'] as String?;
  String? get ocrStatus => _d['ocrStatus'] as String?;
  String? get ocrContainersJson => _d['ocrContainersJson'] as String?;
  String? get ocrRawJson => _d['ocrRawJson'] as String?;
  String? get ocrEmittedAt => _d['ocrEmittedAt'] as String?;
  String? get ocrPersistenceSaved => _d['ocrPersistenceSaved'] as String?;
  String? get ocrPersistenceId => _d['ocrPersistenceId'] as String?;
  String? get ocrPersistenceError => _d['ocrPersistenceError'] as String?;
  String? get ocrPersistenceSavedAt =>
      _d['ocrPersistenceSavedAt'] as String?;
  String? get ocrMetaTotalClients => _d['ocrMetaTotalClients'] as String?;
  String? get ocrMetaEmittedAt => _d['ocrMetaEmittedAt'] as String?;
  String? get ocrContainerNumbers => _d['ocrContainerNumbers'] as String?;

  String? get ocrContainer1Index => _d['ocrContainer1Index'] as String?;
  String? get ocrContainer1Number => _d['ocrContainer1Number'] as String?;
  String? get ocrContainer1Confidence =>
      _d['ocrContainer1Confidence'] as String?;
  String? get ocrContainer1IsoCheckType =>
      _d['ocrContainer1IsoCheckType'] as String?;
  String? get ocrContainer1IsoCheckValue =>
      _d['ocrContainer1IsoCheckValue'] as String?;
  String? get ocrContainer1ImageUrl => _d['ocrContainer1ImageUrl'] as String?;
  String? get ocrContainer1Tare => _d['ocrContainer1Tare'] as String?;
  String? get ocrContainer1TareConfidence =>
      _d['ocrContainer1TareConfidence'] as String?;
  String? get ocrContainer1MaxGrossWeight =>
      _d['ocrContainer1MaxGrossWeight'] as String?;
  String? get ocrContainer1MaxNetWeight =>
      _d['ocrContainer1MaxNetWeight'] as String?;

  String? get ocrContainer2Index => _d['ocrContainer2Index'] as String?;
  String? get ocrContainer2Number => _d['ocrContainer2Number'] as String?;
  String? get ocrContainer2Confidence =>
      _d['ocrContainer2Confidence'] as String?;
  String? get ocrContainer2IsoCheckType =>
      _d['ocrContainer2IsoCheckType'] as String?;
  String? get ocrContainer2IsoCheckValue =>
      _d['ocrContainer2IsoCheckValue'] as String?;
  String? get ocrContainer2ImageUrl => _d['ocrContainer2ImageUrl'] as String?;
  String? get ocrContainer2Tare => _d['ocrContainer2Tare'] as String?;
  String? get ocrContainer2TareConfidence =>
      _d['ocrContainer2TareConfidence'] as String?;
  String? get ocrContainer2MaxGrossWeight =>
      _d['ocrContainer2MaxGrossWeight'] as String?;
  String? get ocrContainer2MaxNetWeight =>
      _d['ocrContainer2MaxNetWeight'] as String?;

  // ── Conseguir data conductor por RUC/Cédula ───────────────────────────────

  int? get conseguirDataConductorErrorCode =>
      _int(_d['conseguirDataConductorErrorCode']);
  String? get conseguirDataConductorMessage =>
      _d['conseguirDataConductorMessage'] as String?;
  String? get conseguirDataConductorRuc =>
      _d['conseguirDataConductorRuc'] as String?;
  String? get conseguirDataConductorEnrollCode =>
      _d['conseguirDataConductorEnrollCode'] as String?;
  String? get conseguirDataConductorCode =>
      _d['conseguirDataConductorCode'] as String?;
  String? get conseguirDataConductorIdentificationNumber =>
      _d['conseguirDataConductorIdentificationNumber'] as String?;
  String? get conseguirDataConductorFirstName =>
      _d['conseguirDataConductorFirstName'] as String?;
  String? get conseguirDataConductorLastName =>
      _d['conseguirDataConductorLastName'] as String?;
  String? get conseguirDataConductorFullName =>
      _d['conseguirDataConductorFullName'] as String?;
  String? get conseguirDataConductorAccessLevel =>
      _d['conseguirDataConductorAccessLevel'] as String?;
  String? get conseguirDataConductorTypeId =>
      _d['conseguirDataConductorTypeId'] as String?;
  String? get conseguirDataConductorStatusId =>
      _d['conseguirDataConductorStatusId'] as String?;
  String? get conseguirDataConductorHasLicense =>
      _d['conseguirDataConductorHasLicense'] as String?;
  String? get conseguirDataConductorLicenseType =>
      _d['conseguirDataConductorLicenseType'] as String?;
  String? get conseguirDataConductorLicenseExpirationDate =>
      _d['conseguirDataConductorLicenseExpirationDate'] as String?;
  String? get conseguirDataConductorState =>
      _d['conseguirDataConductorState'] as String?;
  String? get conseguirDataConductorCompanyRuc =>
      _d['conseguirDataConductorCompanyRuc'] as String?;
  String? get conseguirDataConductorCompanyName =>
      _d['conseguirDataConductorCompanyName'] as String?;
  String? get conseguirDataConductorId =>
      _d['conseguirDataConductorId'] as String?;
  String? get conseguirDataConductorIdCompany =>
      _d['conseguirDataConductorIdCompany'] as String?;

  // ── Conseguir conductor por placa ─────────────────────────────────────────

  int? get conseguirConductorErrorCode =>
      _int(_d['conseguirConductorErrorCode']);
  String? get conseguirConductorMessage =>
      _d['conseguirConductorMessage'] as String?;
  String? get conseguirConductorPlaca =>
      _d['conseguirConductorPlaca'] as String?;
  String? get conseguirConductorChofer =>
      _d['conseguirConductorChofer'] as String?;
  String? get conseguirConductorNumTran =>
      _d['conseguirConductorNumTran'] as String?;
  String? get conseguirConductorFechaIng =>
      _d['conseguirConductorFechaIng'] as String?;
  String? get conseguirConductorEstado =>
      _d['conseguirConductorEstado'] as String?;
  String? get conseguirConductorTipoTran =>
      _d['conseguirConductorTipoTran'] as String?;
  String? get conseguirConductorCodtipo =>
      _d['conseguirConductorCodtipo'] as String?;
  String? get conseguirConductorCodContenedor =>
      _d['conseguirConductorCodContenedor'] as String?;
  String? get conseguirConductorTara =>
      _d['conseguirConductorTara'] as String?;
  String? get conseguirConductorPesoIng =>
      _d['conseguirConductorPesoIng'] as String?;
  String? get conseguirConductorPesoSal =>
      _d['conseguirConductorPesoSal'] as String?;

  // ── Expo Repesaje (consulta solicitud update DISV) ────────────────────────

  int? get expoRepesajeErrorCode => _int(_d['expoRepesajeErrorCode']);
  String? get expoRepesajeMessage => _d['expoRepesajeMessage'] as String?;
  String? get expoRepesajeContenedor =>
      _d['expoRepesajeContenedor'] as String?;
  bool get expoRepesajeHasActiveSolicitud =>
      (_d['expoRepesajeHasActiveSolicitud'] as bool?) ?? false;
  String? get expoRepesajeTipoOperacion =>
      _d['expoRepesajeTipoOperacion'] as String?;
  Map<String, dynamic>? get expoRepesajeResponse =>
      _d['expoRepesajeResponse'] as Map<String, dynamic>?;
  String? get expoRepesajeSolicitudId =>
      _d['expoRepesajeSolicitudId'] as String?;
  String? get expoRepesajeSolicitudUid =>
      _d['expoRepesajeSolicitudUid'] as String?;
  String? get expoRepesajeSolicitudDisv =>
      _d['expoRepesajeSolicitudDisv'] as String?;
  String? get expoRepesajeSolicitudNuevoDisv =>
      _d['expoRepesajeSolicitudNuevoDisv'] as String?;
  String? get expoRepesajeSolicitudNuevoContenedor =>
      _d['expoRepesajeSolicitudNuevoContenedor'] as String?;
  String? get expoRepesajeSolicitudEstado =>
      _d['expoRepesajeSolicitudEstado'] as String?;
  String? get expoRepesajeSolicitudTipoOperacion =>
      _d['expoRepesajeSolicitudTipoOperacion'] as String?;
  String? get expoRepesajeSolicitudFechaRegistro =>
      _d['expoRepesajeSolicitudFechaRegistro'] as String?;
  String? get expoRepesajeSolicitudDisvStr =>
      _d['expoRepesajeSolicitudDisv'] as String?;
  String? get expoRepesajeSolicitudCodigoAutorizacion =>
      _d['expoRepesajeSolicitudCodigoAutorizacion'] as String?;
  String? get expoRepesajeSolicitudMsgError =>
      _d['expoRepesajeSolicitudMsgError'] as String?;

  // ── EXP Muelle Repesaje (inicializar → validar → guardar → terminar) ──────

  /// Número de transacción retornado por inicializar (numtrans del SP).
  String? get expMuelleNumtrans => _d['expMuelleNumtrans'] as String?;

  /// Estado de la transacción desde inicializar: 'ENTRANDO' | 'SALIENDO'.
  String? get expMuelleEstado => _d['expMuelleEstado'] as String?;

  /// Contenedor retornado por el DISV en inicializar.
  /// Se compara con el contenedor OCR en validar-contenedor.
  String? get expMuelleContenedorDisv =>
      _d['expMuelleContenedorDisv'] as String?;

  /// true cuando el panel de salida debe ser visible (isSalida).
  bool get expMuellePanelSalidaVisible =>
      (_d['expMuellePanelSalidaVisible'] as bool?) ?? false;

  /// true si el paso validar-contenedor fue exitoso.
  bool get expMuelleValidarContenedorOk =>
      (_d['expMuelleValidarContenedorOk'] as bool?) ?? false;

  /// Contenedor validado retornado por el SP de validación.
  String? get expMuelleContenedorValidado =>
      _d['expMuelleContenedorValidado'] as String?;

  /// Número de transacción generado por guardar.
  String? get expMuelleGuardarNumero =>
      _d['expMuelleGuardarNumero'] as String?;

  /// true si el paso guardar fue exitoso.
  bool get expMuelleGuardarOk =>
      (_d['expMuelleGuardarOk'] as bool?) ?? false;

  /// Estado final retornado por terminar.
  /// Ej: 'AUTORIZADO_SALIDA', 'AUTORIZADO_PROYECCION', 'BLOQUEADO'.
  String? get expMuelleTerminarEstado =>
      _d['expMuelleTerminarEstado'] as String?;

  /// true si el paso terminar fue exitoso.
  bool get expMuelleTerminarOk =>
      (_d['expMuelleTerminarOk'] as bool?) ?? false;

  /// Respuesta completa de inicializar (trazabilidad).
  Map<String, dynamic>? get expMuelleInicializarResponse =>
      _d['expMuelleInicializarResponse'] as Map<String, dynamic>?;

  /// Respuesta completa de guardar (trazabilidad).
  Map<String, dynamic>? get expMuelleGuardarResponse =>
      _d['expMuelleGuardarResponse'] as Map<String, dynamic>?;

  /// Respuesta completa de terminar (trazabilidad).
  Map<String, dynamic>? get expMuelleTerminarResponse =>
      _d['expMuelleTerminarResponse'] as Map<String, dynamic>?;

  // ── Utilitarios ───────────────────────────────────────────────────────────

  bool get hasPhoto => driverPhotoUrl?.isNotEmpty == true;
  bool get hasDriver => driverCedula?.isNotEmpty == true;
  bool get hasVehiculo => vehiculoPlaca?.isNotEmpty == true;
  bool get hasContenedor1 => contenedor1?.isNotEmpty == true;
  bool get hasContenedor2 => contenedor2?.isNotEmpty == true;

  bool get isTruckEmpty => (_d['isTruckEmpty'] as bool?) ?? false;

  String? get ocrFlowType => _d['ocrFlowType'] as String?;

  int? get flowRemainingSeconds => _int(_d['flowRemainingSeconds']);
  void setFlowRemainingSeconds(int? v) => set('flowRemainingSeconds', v);
  void clearFlowRemainingSeconds() => set('flowRemainingSeconds', null);

  // ── Reset por categoría ───────────────────────────────────────────────────

  static const Map<String, List<String>> _categoryKeys = {
    'driver': [
      'driverPhotoUrl',
      'sideGate',
      'driverCedula',
      'driverLicenciaExp',
      'driverLicenciaTipo',
      'driverEmpresa',
      'driverRucEmpresa',
      'driverAlerta',
      'driverId',
      'driverName',
      'conseguirConductorErrorCode',
      'conseguirConductorMessage',
      'conseguirConductorPlaca',
      'conseguirConductorChofer',
      'conseguirConductorNumTran',
      'conseguirConductorFechaIng',
      'conseguirConductorEstado',
      'conseguirConductorTipoTran',
      'conseguirConductorCodtipo',
      'conseguirConductorCodContenedor',
      'conseguirConductorTara',
      'conseguirConductorPesoIng',
      'conseguirConductorPesoSal',
      'conseguirDataConductorErrorCode',
      'conseguirDataConductorMessage',
      'conseguirDataConductorRuc',
      'conseguirDataConductorEnrollCode',
      'conseguirDataConductorCode',
      'conseguirDataConductorIdentificationNumber',
      'conseguirDataConductorFirstName',
      'conseguirDataConductorLastName',
      'conseguirDataConductorFullName',
      'conseguirDataConductorAccessLevel',
      'conseguirDataConductorTypeId',
      'conseguirDataConductorStatusId',
      'conseguirDataConductorHasLicense',
      'conseguirDataConductorLicenseType',
      'conseguirDataConductorLicenseExpirationDate',
      'conseguirDataConductorState',
      'conseguirDataConductorCompanyRuc',
      'conseguirDataConductorCompanyName',
      'conseguirDataConductorId',
      'conseguirDataConductorIdCompany',
    ],
    'vehiculo': [
      'vehiculoPlaca',
      'vehiculoTipoCarga',
      'vehiculoProducto',
      'vehiculoRefrigerado',
      'vehiculoCargaImo',
      'vehiculoBooking',
      'vehiculoNave',
      'vehiculoObservaciones',
      'vehiculoRfid',
      'vehiculoMarca',
      'vehiculoModelo',
      'vehiculoColor',
      'vehiculoEmpresa',
      'vehiculoEstado',
      'vehiculoMensaje',
    ],
    'importador': ['importador', 'dres', 'contenedor', 'ubicacion', 'turno'],
    'pesos': [
      'pesoIngreso',
      'pesoSalida',
      'pesoTara',
      'pesoPorteo',
      'validarPesoRecibido',
      'validarPesoValidado',
      'validarPesoParseado',
      'validarPesoEsValido',
    ],
    'contenedores': [
      'contenedor1',
      'contenedor2',
      'sello1',
      'sello2',
      'sello3',
      'sello4',
      'sello5',
      'detalle1',
      'detalle2',
      'consCntCodError',
      'consCntDesError',
      'consCntAnoOperacion',
      'consCntCorOperacion',
      'consCntCodSigla',
      'consCntCodNumero',
      'consCntCodDigito',
      'consCntUbicacion',
    ],
    'exportador': [
      'clienteExp',
      'productoExp',
      'bookingExp',
      'naveExp',
      'contenedorExp',
      'sello1Exp',
      'sello2Exp',
      'sello3Exp',
      'sello4Exp',
      'daniosExp',
      'rutaResult',
      'aniodisv',
      'numdisv',
      'idTraslados',
      'mapaUrl',
      'mapaBytes',
    ],
    'ocr': [
      'ocrTransitId',
      'ocrLocation',
      'ocrVehicleType',
      'ocrContainerCount',
      'ocrNote',
      'ocrStatus',
      'ocrContainersJson',
      'ocrRawJson',
      'ocrEmittedAt',
      'ocrPersistenceSaved',
      'ocrPersistenceId',
      'ocrPersistenceError',
      'ocrPersistenceSavedAt',
      'ocrMetaTotalClients',
      'ocrMetaEmittedAt',
      'ocrContainerNumbers',
      'ocrContainer1Index',
      'ocrContainer1Number',
      'ocrContainer1Confidence',
      'ocrContainer1IsoCheckType',
      'ocrContainer1IsoCheckValue',
      'ocrContainer1ImageUrl',
      'ocrContainer1Tare',
      'ocrContainer1TareConfidence',
      'ocrContainer1MaxGrossWeight',
      'ocrContainer1MaxNetWeight',
      'ocrContainer2Index',
      'ocrContainer2Number',
      'ocrContainer2Confidence',
      'ocrContainer2IsoCheckType',
      'ocrContainer2IsoCheckValue',
      'ocrContainer2ImageUrl',
      'ocrContainer2Tare',
      'ocrContainer2TareConfidence',
      'ocrContainer2MaxGrossWeight',
      'ocrContainer2MaxNetWeight',
      'contenedor',
      'pesoTara',
      'isTruckEmpty',
      'ocrFlowType',
    ],
    'expoRepesaje': [
      'expoRepesajeErrorCode',
      'expoRepesajeMessage',
      'expoRepesajeContenedor',
      'expoRepesajeHasActiveSolicitud',
      'expoRepesajeTipoOperacion',
      'expoRepesajeResponse',
      'expoRepesajeSolicitudId',
      'expoRepesajeSolicitudUid',
      'expoRepesajeSolicitudDisv',
      'expoRepesajeSolicitudNuevoDisv',
      'expoRepesajeSolicitudNuevoContenedor',
      'expoRepesajeSolicitudEstado',
      'expoRepesajeSolicitudTipoOperacion',
      'expoRepesajeSolicitudFechaRegistro',
      'expoRepesajeSolicitudUsuarioRegistra',
      'expoRepesajeSolicitudFechaProcesa',
      'expoRepesajeSolicitudFacrurarA',
      'expoRepesajeSolicitudCodigoAutorizacion',
      'expoRepesajeSolicitudCodError',
      'expoRepesajeSolicitudMsgError',
    ],
    'expMuelleRepesaje': [
      'expMuelleNumtrans',
      'expMuelleEstado',
      'expMuelleContenedorDisv',
      'expMuellePanelSalidaVisible',
      'expMuelleValidarContenedorOk',
      'expMuelleContenedorValidado',
      'expMuelleGuardarNumero',
      'expMuelleGuardarOk',
      'expMuelleTerminarEstado',
      'expMuelleTerminarOk',
      'expMuelleInicializarResponse',
      'expMuelleGuardarResponse',
      'expMuelleTerminarResponse',
    ],
  };

  void reset(String category) {
    if (category == 'all') {
      _d.clear();
      _d['pesoActualBascula'] = 0.0;
      _d['hasError'] = false;
      _d['isLoading'] = false;
      _d['transaccionActiva'] = false;
    } else {
      final keys = _categoryKeys[category];
      if (keys == null) throw ArgumentError('Categoría desconocida: $category');
      for (final k in keys) _d.remove(k);
    }
    notifyListeners();
  }

  void resetAllWithDefaults(Map<String, dynamic> defaults) {
    _d.clear();
    _d.addAll({
      'pesoActualBascula': 0.0,
      'hasError': false,
      'isLoading': false,
      'transaccionActiva': false,
      ...defaults,
    });
    notifyListeners();
  }

  void resetDriver() => reset('driver');
  void resetVehiculo() => reset('vehiculo');
  void resetImportador() => reset('importador');
  void resetPesos() => reset('pesos');
  void resetContenedores() => reset('contenedores');
  void resetExportador() => reset('exportador');
  void resetOcr() => reset('ocr');
  void resetExpoRepesaje() => reset('expoRepesaje');
  void resetExpMuelleRepesaje() => reset('expMuelleRepesaje');
  void resetAll() => reset('all');

  // ── Setters nombrados ─────────────────────────────────────────────────────

  void setTituloPantalla(String? v) => set('tituloPantalla', v);
  void setTransactionType(String? v) => set('transactionType', v);
  void setAtkId(String? v) => set('atkId', v);
  void setDriverName(String? v) => set('driverName', v);
  void setDriverPhotoUrl(String? v) => set('driverPhotoUrl', v);
  void setSideGate(String? v) => set('sideGate', v);
  void setDriverCedula(String? v) => set('driverCedula', v);
  void setDriverLicenciaExp(String? v) => set('driverLicenciaExp', v);
  void setDriverLicenciaTipo(String? v) => set('driverLicenciaTipo', v);
  void setDriverEmpresa(String? v) => set('driverEmpresa', v);
  void setDriverRucEmpresa(String? v) => set('driverRucEmpresa', v);
  void setDriverAlerta(String? v) => set('driverAlerta', v);
  void setDriverId(String? v) => set('driverId', v);
  void setVehiculoPlaca(String? v) => set('vehiculoPlaca', v);
  void setVehiculoTipoCarga(String? v) => set('vehiculoTipoCarga', v);
  void setVehiculoProducto(String? v) => set('vehiculoProducto', v);
  void setVehiculoRefrigerado(String? v) => set('vehiculoRefrigerado', v);
  void setVehiculoCargaImo(String? v) => set('vehiculoCargaImo', v);
  void setVehiculoBooking(String? v) => set('vehiculoBooking', v);
  void setVehiculoNave(String? v) => set('vehiculoNave', v);
  void setVehiculoObservaciones(String? v) =>
      set('vehiculoObservaciones', v);
  void setvehiculoRfid(String? v) => set('vehiculoRfid', v);
  void setvehiculoMarca(String? v) => set('vehiculoMarca', v);
  void setvehiculoModelo(String? v) => set('vehiculoModelo', v);
  void setvehiculoColor(String? v) => set('vehiculoColor', v);
  void setvehiculoEmpresa(String? v) => set('vehiculoEmpresa', v);
  void setvehiculoEstado(String? v) => set('vehiculoEstado', v);
  void setvehiculoMensaje(String? v) => set('vehiculoMensaje', v);
  void setImportador(String? v) => set('importador', v);
  void setDres(String? v) => set('dres', v);
  void setContenedor(String? v) => set('contenedor', v);
  void setUbicacion(String? v) => set('ubicacion', v);
  void setTurno(String? v) => set('turno', v);
  void setPesoIngreso(String? v) => set('pesoIngreso', v);
  void setPesoSalida(String? v) => set('pesoSalida', v);
  void setPesoTara(String? v) => set('pesoTara', v);
  void setPesoPorteo(String? v) => set('pesoPorteo', v);
  void setOrigenTrl(String? v) => set('origenTrl', v);
  void setDestinoTrl(String? v) => set('destinoTrl', v);
  void setMapaUbicacion(ImageProvider? v) => set('mapaUbicacion', v);
  void setContenedor1(String? v) => set('contenedor1', v);
  void setContenedor2(String? v) => set('contenedor2', v);
  void setSello1(String? v) => set('sello1', v);
  void setSello2(String? v) => set('sello2', v);
  void setSello3(String? v) => set('sello3', v);
  void setSello4(String? v) => set('sello4', v);
  void setSello5(String? v) => set('sello5', v);
  void setDetalle1(String? v) => set('detalle1', v);
  void setDetalle2(String? v) => set('detalle2', v);
  void setMensajeInferior(String? v) => set('mensajeInferior', v);
  void setClienteExp(String? v) => set('clienteExp', v);
  void setProductoExp(String? v) => set('productoExp', v);
  void setBookingExp(String? v) => set('bookingExp', v);
  void setNaveExp(String? v) => set('naveExp', v);
  void setContenedorExp(String? v) => set('contenedorExp', v);
  void setSello1Exp(String? v) => set('sello1Exp', v);
  void setSello2Exp(String? v) => set('sello2Exp', v);
  void setSello3Exp(String? v) => set('sello3Exp', v);
  void setSello4Exp(String? v) => set('sello4Exp', v);
  void setTipoMovimiento(String? v) => set('transactionType', v);
  void setTipoCarga(String? v) => set('vehiculoTipoCarga', v);
  void setAniodisv(int? v) => set('aniodisv', v);
  void setNumdisv(int? v) => set('numdisv', v);
  void setIdTraslados(int? v) => set('idTraslados', v);
  void setMapaExpUrl(String? v) => set('mapaUrl', v);
  void setMapaExpBytes(Uint8List? v) => set('mapaBytes', v);
  void setDaniosExp(String? v) => set('daniosExp', v);
  void setRutaResult(Map<String, dynamic>? v) => set('rutaResult', v);
  void setIsTruckEmpty(bool v) => set('isTruckEmpty', v);
  void setOcrFlowType(String? v) => set('ocrFlowType', v);
  void setConseguirConductorChofer(String? v) =>
      set('conseguirConductorChofer', v);
  void setConseguirConductorMessage(String? v) =>
      set('conseguirConductorMessage', v);
}