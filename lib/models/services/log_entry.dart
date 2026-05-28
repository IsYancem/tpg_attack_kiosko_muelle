class LogEntry {
  final String time;
  final String rawMessage;
  final LogType type;
  final String source;
  final Map<String, dynamic>? jsonData;

  LogEntry({
    required this.time,
    required this.rawMessage,
    required this.type,
    required this.source,
    this.jsonData,
  });
}

enum LogType { info, success, warning, error, json, handshake }
