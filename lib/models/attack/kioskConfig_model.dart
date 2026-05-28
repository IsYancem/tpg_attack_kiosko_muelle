class KioskConfigModel {
  final String id;
  final String group;
  final String patio;
  final String bascula;
  final String gate;
  final String gateLetter;
  final String rucTpg;
  final bool useSerial;
  final String? serialCom;
  final int timerStop;
  final String fotobeamUrl;
  final String fotobeamIp;
  final String faceService;
  final String faceDeviceSn; 
  final String weightService;
  final String readWeight;
  final String rfidService;
  final String kioskServer;
  final int kioskServerPort;
  final String publicKey;
  final String controlGateService;
  final String ocrService;
  final String createdAt;
  final String updatedAt;

  KioskConfigModel({
    required this.id,
    required this.group,
    required this.patio,
    required this.bascula,
    required this.gate,
    required this.gateLetter,
    required this.rucTpg,
    required this.useSerial,
    this.serialCom,
    required this.timerStop,
    required this.fotobeamUrl,
    required this.fotobeamIp,
    required this.faceService,
    required this.faceDeviceSn, 
    required this.weightService,
    required this.readWeight,
    required this.rfidService,
    required this.kioskServer,
    required this.kioskServerPort,
    required this.publicKey,
    required this.controlGateService,
    required this.ocrService,
    required this.createdAt,
    required this.updatedAt,
  });

  factory KioskConfigModel.fromJson(Map<String, dynamic> json) {
    final rawUseSerial = json['use_serial'];
    bool useSerialValue;

    if (rawUseSerial is bool) {
      useSerialValue = rawUseSerial;
    } else if (rawUseSerial is String) {
      useSerialValue =
          rawUseSerial.toUpperCase().trim() == 'S' || rawUseSerial == 'true';
    } else {
      useSerialValue = false;
    }

    return KioskConfigModel(
      id: json['id']?.toString() ?? '',
      group: json['group']?.toString() ?? '',
      patio: json['patio']?.toString() ?? '',
      bascula: json['bascula']?.toString() ?? '',
      gate: json['gate']?.toString() ?? '',
      gateLetter: json['gate_letter']?.toString() ?? '',
      rucTpg: json['ruc_tpg']?.toString() ?? '',
      useSerial: useSerialValue,
      serialCom: json['serial_com']?.toString(),
      timerStop: int.tryParse(json['timer_stop']?.toString() ?? '0') ?? 0,
      fotobeamUrl: json['fotobeam_url']?.toString() ?? '',
      fotobeamIp: json['fotobeam_ip']?.toString() ?? '',
      faceService: json['face_service']?.toString() ?? '',

      faceDeviceSn:
          json['FACE_DEVICE_SN']?.toString() ??
          json['face_device_sn']?.toString() ??
          '',

      weightService: json['weight_service']?.toString() ?? '',
      readWeight: json['read_weight']?.toString() ?? '',
      rfidService: json['rfid_service']?.toString() ?? '',
      kioskServer: json['kiosk_server']?.toString() ?? '',
      kioskServerPort:
          int.tryParse(json['kiosk_server_port']?.toString() ?? '0') ?? 0,
      publicKey: json['public_key']?.toString() ?? '',
      controlGateService: json['gate_service']?.toString() ?? '',
      ocrService: json['ocr_service']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}