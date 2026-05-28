import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

class AtkRfidWaitingPanel extends StatefulWidget {
  final double height;
  final EdgeInsetsGeometry padding;
  final String? placaLeida;
  final String? contenedorLeido;
  final bool isMuelle;

  const AtkRfidWaitingPanel({
    super.key,
    required this.height,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.placaLeida,
    this.contenedorLeido,
    required this.isMuelle,
  });

  @override
  State<AtkRfidWaitingPanel> createState() => _AtkRfidWaitingPanelState();
}

class _AtkRfidWaitingPanelState extends State<AtkRfidWaitingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final h = widget.height;
    final s = (h / 280).clamp(0.8, 2.0);

    return Padding(
      padding: widget.padding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo
          Image.asset(
            'assets/images/tpg_logo.png',
            height: (h * 0.35).clamp(120, 200),
            fit: BoxFit.contain,
          ),
          SizedBox(height: 12 * s),

          // Título principal
          Text(
            'Esperando Vehículo',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24 * s,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: p.textPrimary,
            ),
          ),

          SizedBox(height: 16 * s),

          // // ═══════════════════════════════════════════════════════════════
          // // INDICADOR DE PLACA
          // // ═══════════════════════════════════════════════════════════════
          // _StatusIndicator(
          //   label: 'Placa',
          //   value: widget.placaLeida,
          //   icon: Icons.local_shipping,
          //   scale: s,
          // ),

          // // ═══════════════════════════════════════════════════════════════
          // // INDICADOR DE CONTENEDOR (solo en modo muelle)
          // // ═══════════════════════════════════════════════════════════════
          // if (widget.isMuelle) ...[
          //   SizedBox(height: 12 * s),
          //   _StatusIndicator(
          //     label: 'Contenedor',
          //     value: widget.contenedorLeido,
          //     icon: Icons.inventory_2,
          //     scale: s,
          //   ),
          // ],

          SizedBox(height: 16 * s),

          // Loader tipo wave dots (solo si aún falta algo)
          if (_shouldShowLoader()) ...[
            _NeonProgressBar(
              controller: _ctrl,
              height: (12 * s).clamp(8, 14),
              backgroundColor: p.surfaceBorder.withValues(alpha:0.35),
              glowColor: p.buttonBg,
            ),
          ],
        ],
      ),
    );
  }

  /// Mostrar loader solo si aún falta algo por leer
  bool _shouldShowLoader() {
    if (widget.isMuelle) {
      return widget.placaLeida == null || widget.contenedorLeido == null;
    } else {
      return widget.placaLeida == null;
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// WIDGET: INDICADOR DE ESTADO (PLACA/CONTENEDOR)
// ═══════════════════════════════════════════════════════════════
// class _StatusIndicator extends StatelessWidget {
//   final String label;
//   final String? value;
//   final IconData icon;
//   final double scale;

//   const _StatusIndicator({
//     required this.label,
//     required this.value,
//     required this.icon,
//     required this.scale,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final p = context.palette;
//     final isComplete = value != null;

//     final bgColor = isComplete
//         ? const Color(0xFF22C55E).withValues(alpha:0.15)
//         : p.surfaceBorder.withValues(alpha:0.2);

//     final borderColor = isComplete ? const Color(0xFF22C55E) : p.surfaceBorder;

//     final iconColor = isComplete ? const Color(0xFF22C55E) : p.textSecondary;

//     final textColor = isComplete ? p.textPrimary : p.textSecondary;

//     return Container(
//       padding: EdgeInsets.symmetric(
//         horizontal: 20 * scale,
//         vertical: 12 * scale,
//       ),
//       decoration: BoxDecoration(
//         color: bgColor,
//         borderRadius: BorderRadius.circular(12 * scale),
//         border: Border.all(color: borderColor, width: 2),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // Icono
//           Icon(
//             isComplete ? Icons.check_circle : icon,
//             color: iconColor,
//             size: 32 * scale,
//           ),
//           SizedBox(width: 12 * scale),

//           // Label + Valor
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text(
//                 label,
//                 style: TextStyle(
//                   fontSize: 14 * scale,
//                   fontWeight: FontWeight.w600,
//                   color: textColor.withValues(alpha:0.7),
//                   letterSpacing: 0.5,
//                 ),
//               ),
//               SizedBox(height: 4 * scale),
//               Text(
//                 value ?? 'Esperando...',
//                 style: TextStyle(
//                   fontSize: 20 * scale,
//                   fontWeight: FontWeight.w800,
//                   color: textColor,
//                   letterSpacing: 0.8,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// ═══════════════════════════════════════════════════════════════
// WIDGET: BARRA DE PROGRESO NEÓN (sin cambios)
// ═══════════════════════════════════════════════════════════════
class _NeonProgressBar extends StatelessWidget {
  final Animation<double> controller;
  final double height;
  final Color backgroundColor;
  final Color glowColor;

  const _NeonProgressBar({
    required this.controller,
    required this.height,
    required this.backgroundColor,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final w = c.maxWidth;
        final knobW = w * 0.35;
        return ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: Stack(
            children: [
              // Fondo
              Container(
                height: height,
                width: double.infinity,
                color: backgroundColor,
              ),
              // "Knob" que se desplaza (gradiente neón)
              AnimatedBuilder(
                animation: controller,
                builder: (_, __) {
                  final x = (w + knobW) * controller.value - knobW;
                  return Transform.translate(
                    offset: Offset(x, 0),
                    child: Container(
                      height: height,
                      width: knobW,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            glowColor.withValues(alpha:0.0),
                            glowColor.withValues(alpha:0.7),
                            glowColor.withValues(alpha:0.0),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: glowColor.withValues(alpha:0.45),
                            blurRadius: 12,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
