class StaapisacFotoRow {
  final int? codeError;
  final String? message;
  final String? img; // base64

  StaapisacFotoRow({this.codeError, this.message, this.img});

  factory StaapisacFotoRow.fromJson(Map<String, dynamic> j) {
    return StaapisacFotoRow(
      codeError: (j['code_error'] is num)
          ? (j['code_error'] as num).toInt()
          : int.tryParse('${j['code_error']}'),
      message: j['message']?.toString(),
      img: j['img']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'code_error': codeError,
    'message': message,
    'img': img,
  };
}
