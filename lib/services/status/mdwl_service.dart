import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:tpg_attack_kiosko_muelle/services/status/status_log_bus.dart';
import 'base_service.dart';

class MdwlService extends BaseService {
  IO.Socket? _io;

  MdwlService({required super.onStatus});

  void connect(String url, {String enginePath = '/socket.io'}) {
    _stopIo();

    _io = IO.io(
      url,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setPath(enginePath)
          .enableReconnection()
          .build(),
    );

    _io!.onConnect((_) {
      setConnected(true);
      StatusLogBus.instance.addStatus('TOS', true);
    });
    _io!.onDisconnect((_) {
      setConnected(false);
      StatusLogBus.instance.addStatus('TOS', false);
    });
    _io!.onError((_) {
      setConnected(false);
      StatusLogBus.instance.addStatus('TOS', false);
    });

    // 👇 cada 5s verificamos si sigue conectado
    startProbeLoop(() async => _io?.connected == true);
  }

  void _stopIo() {
    try {
      _io?.dispose();
    } catch (_) {}
    _io = null;
  }

  @override
  void dispose() {
    super.dispose();
    _stopIo();
  }
}
