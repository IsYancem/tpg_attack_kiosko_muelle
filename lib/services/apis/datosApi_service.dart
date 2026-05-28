import 'package:tpg_attack_kiosko_muelle/models/datos/conseguir_conductor_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/datos/conseguir_data_conductor_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/datos/consultar_placa_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/datos/consultar_transaccion_model.dart';
import 'package:tpg_attack_kiosko_muelle/models/datos/expo-repesaje.dart';
import 'package:tpg_attack_kiosko_muelle/services/apis/baseApi_service.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';

class DatosApiService extends BaseApiService {
  DatosApiService();

  Future<ApiEnvelope<T>> _callLogged<T>({
    required String tag,
    required String path,
    required HttpMethod method,
    required Map<String, dynamic> body,
    required T Function(Map<String, dynamic>) decoder,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final sw = Stopwatch()..start();

    await LogService.instance.logRequest('${tag}_FULL_REQUEST', {
      'path': path,
      'method': method.name,
      'timeoutMs': timeout.inMilliseconds,
      'body': body,
    });

    try {
      final res = await call<T>(
        spec: RequestSpec(
          path: path,
          method: method,
          tag: tag,
          timeout: timeout,
          body: body,
        ),
        decoder: decoder,
      );

      sw.stop();

      await LogService.instance.logRequest('${tag}_FULL_RESPONSE', {
        'elapsedMs': sw.elapsedMilliseconds,
        'errorCode': res.errorCode,
        'message': res.message,
        'isOk': res.isOk,
        'data': _safeJson(res.data),
      });

      return res;
    } catch (e, st) {
      sw.stop();

      await LogService.instance.logError('${tag}_FULL_EXCEPTION', e, st);

      await LogService.instance.logRequest('${tag}_FULL_EXCEPTION_CONTEXT', {
        'elapsedMs': sw.elapsedMilliseconds,
        'path': path,
        'method': method.name,
        'body': body,
        'error': e.toString(),
      });

      rethrow;
    }
  }

  dynamic _safeJson(dynamic value) {
    if (value == null) return null;

    try {
      return (value as dynamic).toJson();
    } catch (_) {
      return value.toString();
    }
  }

  // ---------------------------------------------------------------------------
  // CONSEGUIR CONDUCTOR POR PLACA
  // POST /kiosk/api/datos/conseguir-conductor
  // ---------------------------------------------------------------------------
  Future<ApiEnvelope<ConseguirConductorResponse>> conseguirConductor({
    required String placa,
  }) {
    final normalizedPlaca = placa.trim().toUpperCase();

    return _callLogged<ConseguirConductorResponse>(
      tag: 'CONSEGUIR_CONDUCTOR',
      path: 'kiosk/api/datos/conseguir-conductor',
      method: HttpMethod.post,
      timeout: const Duration(seconds: 30),
      body: ConseguirConductorRequest(placa: normalizedPlaca).toJson(),
      decoder: ConseguirConductorResponse.fromJson,
    );
  }

  Future<ConseguirConductorResponse?> conseguirYGuardarEnManager({
    required String placa,
    required AtkTransactionManager manager,
  }) async {
    final normalizedPlaca = placa.trim().toUpperCase();

    if (normalizedPlaca.isEmpty) {
      await LogService.instance.logWarning('CONSEGUIR_CONDUCTOR_SKIP', {
        'reason': 'placa vacía',
      });
      return null;
    }

    await LogService.instance.logRequest('CONSEGUIR_CONDUCTOR_REQUEST', {
      'placa': normalizedPlaca,
    });

    final res = await conseguirConductor(placa: normalizedPlaca);
    final data = res.data;
    final conductor = data?.conductor;
    final chofer = conductor?.chofer?.trim();

    await LogService.instance.logRequest('CONSEGUIR_CONDUCTOR_RESPONSE', {
      'errorCode': res.errorCode,
      'message': res.message,
      'placa': data?.placa,
      'spCodError': conductor?.codError,
      'spMessage': conductor?.desError,
      'chofer': chofer,
      'numTran': conductor?.numTran,
      'fechaIng': conductor?.fechaIng,
    });

    if (!res.isOk || data == null || conductor == null) {
      manager.setMany({
        'conseguirConductorErrorCode': res.errorCode,
        'conseguirConductorMessage': res.message,
        'driverCedula': '',
      });
      return data;
    }

    if (!conductor.isOk || chofer == null || chofer.isEmpty) {
      manager.setMany({
        'conseguirConductorErrorCode': conductor.codError,
        'conseguirConductorMessage': conductor.desError,
        'driverCedula': '',
      });
      return data;
    }

    manager.setMany({
      'driverCedula': chofer,
      'driverId': chofer,
      'conseguirConductorErrorCode': conductor.codError,
      'conseguirConductorMessage': conductor.desError,
      'conseguirConductorPlaca': conductor.numPlaca ?? normalizedPlaca,
      'conseguirConductorChofer': chofer,
      'conseguirConductorNumTran': conductor.numTran?.toString(),
      'conseguirConductorFechaIng': conductor.fechaIng,
      'conseguirConductorEstado': conductor.estado,
      'conseguirConductorTipoTran': conductor.tipoTran,
      'conseguirConductorCodtipo': conductor.codtipo,
      'conseguirConductorCodContenedor': conductor.codContenedor,
      'conseguirConductorTara': conductor.tara?.toString(),
      'conseguirConductorPesoIng': conductor.pesoing?.toString(),
      'conseguirConductorPesoSal': conductor.pesosal?.toString(),
    });

    await LogService.instance.logRequest('CONSEGUIR_CONDUCTOR_MANAGER_OK', {
      'placa': normalizedPlaca,
      'driverCedula': chofer,
      'numTran': conductor.numTran,
      'fechaIng': conductor.fechaIng,
    });

    return data;
  }

  // ---------------------------------------------------------------------------
  // CONSEGUIR DATA COMPLETA DEL CONDUCTOR POR RUC/CÉDULA
  // POST /kiosk/api/datos/conseguir-data-conductor
  // ---------------------------------------------------------------------------
  Future<ApiEnvelope<ConseguirDataConductorResponse>> conseguirDataConductor({
    required String ruc,
  }) {
    final normalizedRuc = ruc.trim().toUpperCase();

    return _callLogged<ConseguirDataConductorResponse>(
      tag: 'CONSEGUIR_DATA_CONDUCTOR',
      path: 'kiosk/api/datos/conseguir-data-conductor',
      method: HttpMethod.post,
      timeout: const Duration(seconds: 30),
      body: ConseguirDataConductorRequest(ruc: normalizedRuc).toJson(),
      decoder: ConseguirDataConductorResponse.fromJson,
    );
  }

  Future<ConseguirDataConductorResponse?> conseguirDataYGuardarEnManager({
    required String ruc,
    required AtkTransactionManager manager,
  }) async {
    final normalizedRuc = ruc.trim().toUpperCase();

    if (normalizedRuc.isEmpty) {
      await LogService.instance.logWarning('CONSEGUIR_DATA_CONDUCTOR_SKIP', {
        'reason': 'ruc vacío',
      });
      return null;
    }

    await LogService.instance.logRequest('CONSEGUIR_DATA_CONDUCTOR_REQUEST', {
      'ruc': normalizedRuc,
    });

    final res = await conseguirDataConductor(ruc: normalizedRuc);
    final data = res.data;
    final conductor = data?.conductor;

    await LogService.instance.logRequest('CONSEGUIR_DATA_CONDUCTOR_RESPONSE', {
      'errorCode': res.errorCode,
      'message': res.message,
      'ruc': data?.ruc,
      'spErrorCode': conductor?.errorCode,
      'spErrorMsg': conductor?.errorMsg,
      'identificationNumber': conductor?.identificationNumber,
      'fullName': conductor?.fullName,
      'id': conductor?.id,
      'idCompany': conductor?.idCompany,
    });

    if (!res.isOk || data == null || conductor == null) {
      manager.setMany({
        'conseguirDataConductorErrorCode': res.errorCode,
        'conseguirDataConductorMessage': res.message,
        'conseguirDataConductorRuc': normalizedRuc,
      });
      return data;
    }

    if (!conductor.isOk) {
      manager.setMany({
        'conseguirDataConductorErrorCode': conductor.errorCode,
        'conseguirDataConductorMessage': conductor.errorMsg,
        'conseguirDataConductorRuc': normalizedRuc,
      });
      return data;
    }

    manager.setMany({
      'driverCedula': conductor.identificationNumber ?? normalizedRuc,
      'driverId': conductor.id?.toString(),
      'driverName': conductor.fullName,
      'driverLicenciaTipo': conductor.licenseType,
      'driverLicenciaExp': conductor.licenseExpirationDate,
      'driverEmpresa': conductor.companyName,
      'driverRucEmpresa': conductor.ruc,
      'driverAlerta': conductor.errorMsg,
      'conseguirDataConductorErrorCode': conductor.errorCode,
      'conseguirDataConductorMessage': conductor.errorMsg,
      'conseguirDataConductorRuc': data.ruc ?? normalizedRuc,
      'conseguirDataConductorEnrollCode': conductor.enrollCode,
      'conseguirDataConductorCode': conductor.code,
      'conseguirDataConductorIdentificationNumber':
          conductor.identificationNumber,
      'conseguirDataConductorFirstName': conductor.firstName,
      'conseguirDataConductorLastName': conductor.lastName,
      'conseguirDataConductorFullName': conductor.fullName,
      'conseguirDataConductorAccessLevel': conductor.accessLevel?.toString(),
      'conseguirDataConductorTypeId': conductor.typeId?.toString(),
      'conseguirDataConductorStatusId': conductor.statusId?.toString(),
      'conseguirDataConductorHasLicense': conductor.hasLicense?.toString(),
      'conseguirDataConductorLicenseType': conductor.licenseType,
      'conseguirDataConductorLicenseExpirationDate':
          conductor.licenseExpirationDate,
      'conseguirDataConductorState': conductor.state?.toString(),
      'conseguirDataConductorCompanyRuc': conductor.ruc,
      'conseguirDataConductorCompanyName': conductor.companyName,
      'conseguirDataConductorId': conductor.id?.toString(),
      'conseguirDataConductorIdCompany': conductor.idCompany?.toString(),
    });

    await LogService.instance
        .logRequest('CONSEGUIR_DATA_CONDUCTOR_MANAGER_OK', {
          'ruc': normalizedRuc,
          'driverCedula': conductor.identificationNumber,
          'driverName': conductor.fullName,
          'driverEmpresa': conductor.companyName,
          'driverId': conductor.id,
        });

    return data;
  }

  // ---------------------------------------------------------------------------
  // CONSULTAR PLACA (MUELLE)
  // POST /kiosk/api/datos-muelle/consultar-placa
  // ---------------------------------------------------------------------------
  Future<ApiEnvelope<ConsultarPlacaRow>> consultarPlacaMuelle({
    required ConsultarPlacaRequest input,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return _callLogged<ConsultarPlacaRow>(
      tag: 'CONSULTAR_PLACA_MUELLE',
      path: 'kiosk/api/datos-muelle/consultar-placa',
      method: HttpMethod.post,
      timeout: timeout,
      body: input.toJson(),
      decoder: ConsultarPlacaRow.fromJson,
    );
  }

  // ---------------------------------------------------------------------------
  // CONSULTAR TRANSACCION (MUELLE)
  // POST /kiosk/api/datos-muelle/consultar-transaccion
  // ---------------------------------------------------------------------------
  Future<ApiEnvelope<ConsultarPlacaRow>> consultarTransaccionMuelle({
    required ConsultarTransaccionRequest input,
    Duration timeout = const Duration(seconds: 15),
  }) {
    return _callLogged<ConsultarPlacaRow>(
      tag: 'CONSULTAR_TRANSACCION_MUELLE',
      path: 'kiosk/api/datos-muelle/consultar-transaccion',
      method: HttpMethod.post,
      timeout: timeout,
      body: input.toJson(),
      decoder: ConsultarPlacaRow.fromJson,
    );
  }

  // ---------------------------------------------------------------------------
  // EXPO REPESAJE
  // POST /kiosk/api/datos-muelle/expo-repesaje
  // ---------------------------------------------------------------------------

  /// Llama al endpoint expo-repesaje y retorna el envelope crudo.
  Future<ApiEnvelope<ExpoRepesajeData>> expoRepesaje({
    required String contenedor,
  }) {
    final normalizedContenedor = contenedor.trim().toUpperCase();

    return _callLogged<ExpoRepesajeData>(
      tag: 'EXPO_REPESAJE',
      path: 'kiosk/api/datos-muelle/expo-repesaje',
      method: HttpMethod.post,
      timeout: const Duration(seconds: 15),
      body: ExpoRepesajeRequest(contenedor: normalizedContenedor).toJson(),
      decoder: ExpoRepesajeData.fromJson,
    );
  }

  /// Llama a expo-repesaje y persiste todos los campos en el manager.
  /// Retorna [ExpoRepesajeData] o null si el contenedor estaba vacío.
  Future<ExpoRepesajeData?> expoRepesajeYGuardarEnManager({
    required String contenedor,
    required AtkTransactionManager manager,
  }) async {
    final normalized = contenedor.trim().toUpperCase();

    if (normalized.isEmpty) {
      await LogService.instance.logWarning('EXPO_REPESAJE_SKIP', {
        'reason': 'contenedor vacío',
      });
      return null;
    }

    await LogService.instance.logRequest('EXPO_REPESAJE_REQUEST', {
      'contenedor': normalized,
    });

    final res = await expoRepesaje(contenedor: normalized);
    final data = res.data;
    final solicitud = data?.solicitudUpdateDisv;

    await LogService.instance.logRequest('EXPO_REPESAJE_RESPONSE', {
      'errorCode': res.errorCode,
      'message': res.message,
      'contenedor': data?.contenedor,
      'hasActiveSolicitud': data?.hasActiveSolicitud,
      'tipoOperacion': data?.tipoOperacion,
      'solicitudId': solicitud?.id,
      'solicitudEstado': solicitud?.estado,
      'solicitudDisv': solicitud?.disv,
      'solicitudNuevoDisv': solicitud?.nuevoDisv,
      'solicitudCodError': solicitud?.codError,
      'solicitudMsgError': solicitud?.msgError,
    });

    // Siempre guardamos para trazabilidad completa en el manager.
    manager.setManyWithoutNotify({
      'expoRepesajeErrorCode': res.errorCode,
      'expoRepesajeMessage': res.message,
      'expoRepesajeContenedor': data?.contenedor ?? normalized,
      'expoRepesajeHasActiveSolicitud': data?.hasActiveSolicitud ?? false,
      'expoRepesajeTipoOperacion': data?.tipoOperacion ?? '',
      'expoRepesajeResponse': data?.toJson(),

      // Campos planos de la solicitud para acceso directo desde el manager.
      'expoRepesajeSolicitudId': solicitud?.id?.toString(),
      'expoRepesajeSolicitudUid': solicitud?.uid,
      'expoRepesajeSolicitudDisv': solicitud?.disv?.toString(),
      'expoRepesajeSolicitudNuevoDisv': solicitud?.nuevoDisv?.toString(),
      'expoRepesajeSolicitudNuevoContenedor': solicitud?.nuevoContenedor,
      'expoRepesajeSolicitudEstado': solicitud?.estado?.toString(),
      'expoRepesajeSolicitudTipoOperacion': solicitud?.tipoOperacion,
      'expoRepesajeSolicitudFechaRegistro': solicitud?.fechaRegistro,
      'expoRepesajeSolicitudUsuarioRegistra': solicitud?.usuarioRegistra,
      'expoRepesajeSolicitudFechaProcesa': solicitud?.fechaProcesa,
      'expoRepesajeSolicitudFacrurarA': solicitud?.facturarA,
      'expoRepesajeSolicitudCodigoAutorizacion': solicitud?.codigoAutorizacion,
      'expoRepesajeSolicitudCodError': solicitud?.codError?.toString(),
      'expoRepesajeSolicitudMsgError': solicitud?.msgError,
    });

    await LogService.instance.logRequest('EXPO_REPESAJE_MANAGER_OK', {
      'contenedor': normalized,
      'hasActiveSolicitud': data?.hasActiveSolicitud,
      'tipoOperacion': data?.tipoOperacion,
      'solicitudId': solicitud?.id,
      'estado': solicitud?.estado,
    });

    return data;
  }
}

// ---------------------------------------------------------------------------

extension FirstOrNullExtension<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

// ---------------------------------------------------------------------------
// ConseguirConductorService
// ---------------------------------------------------------------------------
class ConseguirConductorService extends BaseApiService {
  ConseguirConductorService();

  Future<ApiEnvelope<ConseguirConductorResponse>> conseguirConductor({
    required String placa,
  }) {
    final normalizedPlaca = placa.trim().toUpperCase();

    return call<ConseguirConductorResponse>(
      spec: RequestSpec(
        path: 'kiosk/api/datos/conseguir-conductor',
        method: HttpMethod.post,
        tag: 'CONSEGUIR_CONDUCTOR',
        timeout: const Duration(seconds: 30),
        body: ConseguirConductorRequest(placa: normalizedPlaca).toJson(),
      ),
      decoder: ConseguirConductorResponse.fromJson,
    );
  }

  Future<ConseguirConductorResponse?> conseguirYGuardarEnManager({
    required String placa,
    required AtkTransactionManager manager,
  }) async {
    final normalizedPlaca = placa.trim().toUpperCase();

    if (normalizedPlaca.isEmpty) {
      await LogService.instance.logWarning('CONSEGUIR_CONDUCTOR_SKIP', {
        'reason': 'placa vacía',
      });
      return null;
    }

    await LogService.instance.logRequest('CONSEGUIR_CONDUCTOR_REQUEST', {
      'placa': normalizedPlaca,
    });

    final res = await conseguirConductor(placa: normalizedPlaca);
    final data = res.data;
    final conductor = data?.conductor;
    final chofer = conductor?.chofer?.trim();

    await LogService.instance.logRequest('CONSEGUIR_CONDUCTOR_RESPONSE', {
      'errorCode': res.errorCode,
      'message': res.message,
      'placa': data?.placa,
      'spCodError': conductor?.codError,
      'spMessage': conductor?.desError,
      'chofer': chofer,
      'numTran': conductor?.numTran,
      'fechaIng': conductor?.fechaIng,
    });

    if (!res.isOk || data == null || conductor == null) {
      manager.setMany({
        'conseguirConductorErrorCode': res.errorCode,
        'conseguirConductorMessage': res.message,
        'driverCedula': '',
      });
      return data;
    }

    if (!conductor.isOk || chofer == null || chofer.isEmpty) {
      manager.setMany({
        'conseguirConductorErrorCode': conductor.codError,
        'conseguirConductorMessage': conductor.desError,
        'driverCedula': '',
      });
      return data;
    }

    manager.setMany({
      'driverCedula': chofer,
      'driverId': chofer,
      'conseguirConductorErrorCode': conductor.codError,
      'conseguirConductorMessage': conductor.desError,
      'conseguirConductorPlaca': conductor.numPlaca ?? normalizedPlaca,
      'conseguirConductorChofer': chofer,
      'conseguirConductorNumTran': conductor.numTran?.toString(),
      'conseguirConductorFechaIng': conductor.fechaIng,
      'conseguirConductorEstado': conductor.estado,
      'conseguirConductorTipoTran': conductor.tipoTran,
      'conseguirConductorCodtipo': conductor.codtipo,
      'conseguirConductorCodContenedor': conductor.codContenedor,
      'conseguirConductorTara': conductor.tara?.toString(),
      'conseguirConductorPesoIng': conductor.pesoing?.toString(),
      'conseguirConductorPesoSal': conductor.pesosal?.toString(),
    });

    await LogService.instance.logRequest('CONSEGUIR_CONDUCTOR_MANAGER_OK', {
      'placa': normalizedPlaca,
      'driverCedula': chofer,
      'numTran': conductor.numTran,
      'fechaIng': conductor.fechaIng,
    });

    return data;
  }
}
