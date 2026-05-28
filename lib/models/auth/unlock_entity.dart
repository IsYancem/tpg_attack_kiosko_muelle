class UnLockEntity {
  final int code;
  final String msg;

  const UnLockEntity({
    required this.code,
    required this.msg,
  });

  factory UnLockEntity.fromJson(Map<String, dynamic> json) {
    return UnLockEntity(
      code: json['code'] ?? 1,
      msg: json['msg'] ?? 'No data',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'msg': msg,
    };
  }

  @override
  String toString() {
    return 'UnLockEntity(code: $code, msg: $msg)';
  }
}