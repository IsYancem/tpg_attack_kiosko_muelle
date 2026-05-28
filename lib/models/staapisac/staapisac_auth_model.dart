class StaapisacAuthResponse {
  final String? id;
  final String? username;
  final String? computerName;
  final String? accessToken;
  final String? refreshToken;

  StaapisacAuthResponse({
    this.id,
    this.username,
    this.computerName,
    this.accessToken,
    this.refreshToken,
  });

  factory StaapisacAuthResponse.fromJson(Map<String, dynamic> j) {
    return StaapisacAuthResponse(
      id: j['id']?.toString(),
      username: j['username']?.toString(),
      computerName: j['computerName']?.toString(),
      accessToken: j['accessToken']?.toString(),
      refreshToken: j['refreshToken']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'computerName': computerName,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
  };
}
