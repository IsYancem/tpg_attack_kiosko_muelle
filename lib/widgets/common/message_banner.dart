import 'package:flutter/material.dart';

class MessageBanner extends StatelessWidget {
  final String mensaje;
  final Color fallbackSurface;
  final Color fallbackBorder;

  const MessageBanner({
    super.key,
    required this.mensaje,
    required this.fallbackSurface,
    required this.fallbackBorder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = _resolveMessageTheme(mensaje);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.bg ?? fallbackSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border ?? fallbackBorder, width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Ícono grande expresivo
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.iconBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: theme.border ?? fallbackBorder,
                width: 1,
              ),
            ),
            child: Icon(theme.icon, size: 30, color: theme.iconColor),
          ),
          const SizedBox(width: 12),

          // Texto del mensaje
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  (mensaje.isEmpty) ? '—' : mensaje,
                  textAlign: TextAlign.left,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 22, // grande y legible en kiosk
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tema de mensaje según palabras clave simples
_MessageTheme _resolveMessageTheme(String msg) {
  final s = msg.toLowerCase();

  final isError = [
    'error',
    'alerta',
    'falla',
    'rechaz',
    'bloque',
    'deneg',
  ].any(s.contains);
  final isWarn = [
    'pendiente',
    'atención',
    'revisar',
    'espera',
    'cuidado',
  ].any(s.contains);
  final isOk = [
    'listo',
    'éxito',
    'completo',
    'aprobado',
    'ok',
    'libre',
  ].any(s.contains);

  if (isError) {
    return _MessageTheme(
      icon: Icons.error_rounded,
      iconColor: const Color(0xFFB00020),
      iconBg: const Color(0xFFFFEBEE),
      textColor: const Color(0xFF7F0000),
      bg: const Color(0xFFFFEBEE),
      border: const Color(0xFFFFCDD2),
    );
  } else if (isWarn) {
    return _MessageTheme(
      icon: Icons.warning_amber_rounded,
      iconColor: const Color(0xFF9A6B00),
      iconBg: const Color(0xFFFFF8E1),
      textColor: const Color(0xFF5D4300),
      bg: const Color(0xFFFFF8E1),
      border: const Color(0xFFFFECB3),
    );
  } else if (isOk) {
    return _MessageTheme(
      icon: Icons.check_circle_rounded,
      iconColor: const Color(0xFF1B5E20),
      iconBg: const Color(0xFFE8F5E9),
      textColor: const Color(0xFF1B5E20),
      bg: const Color(0xFFE8F5E9),
      border: const Color(0xFFC8E6C9),
    );
  } else {
    return _MessageTheme(
      icon: Icons.info_rounded,
      iconColor: const Color(0xFF01579B),
      iconBg: const Color(0xFFE1F5FE),
      textColor: const Color(0xFF003B6A),
      bg: const Color(0xFFE1F5FE),
      border: const Color(0xFFB3E5FC),
    );
  }
}

class _MessageTheme {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color textColor;
  final Color? bg;
  final Color? border;

  _MessageTheme({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.textColor,
    this.bg,
    this.border,
  });
}
