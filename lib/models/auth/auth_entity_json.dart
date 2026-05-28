import 'auth_entity.dart';

class AuthEntityJson {
  int code;
  String msg;
  List<AuthEntity> records;

  AuthEntityJson({this.code = 1, this.msg = '', this.records = const []});

  factory AuthEntityJson.fromJson(Map<String, dynamic> json) => AuthEntityJson(
        code: json['code'] ?? 1,
        msg: json['msg'] ?? '',
        records: (json['records'] as List<dynamic>?)?.map((e) => AuthEntity.fromJson(e)).toList() ?? [],
      );

  int countRecords() => records.length;
}