class AuthEntity {
  int letra;
  String descripcion;
  String privateKey;
  int code;
  String msg;

  AuthEntity({
    this.letra = 0,
    this.descripcion = '',
    this.privateKey = '',
    this.code = 1,
    this.msg = 'Default',
  });

  factory AuthEntity.fromJson(Map<String, dynamic> json) => AuthEntity(
    letra: json['letra'] ?? 0,
    descripcion: json['descripcion'] ?? '',
    privateKey: json['private_key'] ?? '',
    code: json['code'] ?? 1,
    msg: json['msg'] ?? 'Default',
  );

  Map<String, dynamic> toJson() => {
    'letra': letra,
    'descripcion': descripcion,
    'private_key': privateKey,
    'code': code,
    'msg': msg,
  };

  @override
  String toString() {
    return 'AuthEntity(letra: $letra, descripcion: $descripcion, privateKey: $privateKey, code: $code, msg: $msg)';
  }
}
