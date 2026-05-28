// lib/utils/format/fecha_utils.dart
import 'package:flutter/foundation.dart';

@immutable
class FechaUtils {
  const FechaUtils._(); // no instanciable

  static const List<String> _dias = <String>[
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static const List<String> _meses = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  /// 2 dígitos (00..59)
  static String two(int v) => v.toString().padLeft(2, '0');

  /// Capitaliza sólo la primera letra, manteniendo acentos tal cual.
  static String capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Formato largo español:
  /// `Miércoles, 30 de Julio del 2025 14:40:15`
  ///
  /// - [incluirHora] para incluir HH:mm:ss.
  /// - [usarDel] para usar "del 2025" en lugar de "de 2025".
  static String fechaLargaEs(
    DateTime d, {
    bool incluirHora = true,
    bool usarDel = true,
  }) {
    final dia = capitalize(_dias[d.weekday - 1]);
    final mes = capitalize(_meses[d.month - 1]);

    final base = '$dia, ${d.day} de $mes ${usarDel ? "del" : "de"} ${d.year}';
    if (!incluirHora) return base;

    final hora = '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
    return '$base $hora';
  }

  /// Sólo hora: `HH:mm:ss`
  static String horaHms(DateTime d) =>
      '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

/// Azúcar sintáctico como extensión
extension FechaExtensions on DateTime {
  String toFechaLargaEs({bool incluirHora = true, bool usarDel = true}) =>
      FechaUtils.fechaLargaEs(this, incluirHora: incluirHora, usarDel: usarDel);

  String toHoraHms() => FechaUtils.horaHms(this);
}
