// lib/widgets/bodyOcr/atkBodyBar_ocr.dart
// Autor: Abraham Yance — Actualizado con flutter_animate + shimmer
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

enum SensorStatus {
  idle,
  sensing,
  badPosition,
  goodPosition,
  aligned,
  weightOk,
}

// ─────────────────────────────────────────────────────────────────────────────
class AtkBodyBarOcr extends StatelessWidget {
  final double height;
  final SensorStatus sensorStatus;

  const AtkBodyBarOcr({
    super.key,
    required this.height,
    required this.sensorStatus,
  });

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AtkTransactionManager>();
    final colors = context.palette;
    final size = MediaQuery.sizeOf(context);
    final s = (height / 680.0).clamp(0.6, 1.6);
    final isNarrow = size.width < 1000;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 12 * s),
        child: isNarrow
            ? _buildVertical(context, colors, manager, size, s)
            : _buildHorizontal(context, colors, manager, size, s),
      ),
    );
  }

  // ── Lottie con overlay animado ──────────────────────────────────────────
  Widget _lottieFillHeight({
    required bool isNarrow,
    required Size screenSize,
    required double height,
    required SensorStatus status,
  }) {
    return LayoutBuilder(
      builder: (context, box) {
        final maxH = box.maxHeight.isFinite ? box.maxHeight : height;
        double maxByWidth = double.infinity;

        if (!isNarrow) {
          const h = 24.0 * 2;
          const g = 24.0;
          final half = (screenSize.width - h - g) / 2;
          maxByWidth = half * 0.98;
        }

        final side = math.min(maxH * 0.98, maxByWidth);
        final overlayColor = _ocrColor(status);

        return Center(
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              AnimatedOpacity(
                opacity: status == SensorStatus.idle ? 0.6 : 1.0,
                duration: const Duration(milliseconds: 400),
                child: AnimatedScale(
                  scale: switch (status) {
                    SensorStatus.weightOk => 1.06,
                    SensorStatus.aligned => 1.03,
                    SensorStatus.sensing => 1.0,
                    _ => 0.97,
                  },
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeInOut,
                  child: Lottie.asset(
                    'assets/animations/Truck.json',
                    width: side,
                    height: side,
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                ),
              ),

              // Barra de estado inferior animada
              if (status != SensorStatus.idle)
                Positioned(
                  bottom: side * 0.04,
                  child: _AnimatedStatusBar(
                    color: overlayColor,
                    width: side * 0.55,
                    status: status,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHorizontal(
    BuildContext context,
    AppPalette colors,
    AtkTransactionManager manager,
    Size screenSize,
    double s,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _lottieFillHeight(
            isNarrow: false,
            screenSize: screenSize,
            height: height,
            status: sensorStatus,
          ),
        ),
        SizedBox(width: 24 * s),
        Expanded(
          child: _RightColumn(
            colors: colors,
            manager: manager,
            sensorStatus: sensorStatus,
            s: s,
          ),
        ),
      ],
    );
  }

  Widget _buildVertical(
    BuildContext context,
    AppPalette colors,
    AtkTransactionManager manager,
    Size screenSize,
    double s,
  ) {
    return LayoutBuilder(
      builder: (context, box) {
        final maxH = box.maxHeight.isFinite ? box.maxHeight : height;
        final side = maxH * 0.5;

        return SingleChildScrollView(
          child: Column(
            children: [
              _lottieFillHeight(
                isNarrow: true,
                screenSize: screenSize,
                height: side,
                status: sensorStatus,
              ),
              SizedBox(height: 20 * s),
              _RightColumn(
                colors: colors,
                manager: manager,
                sensorStatus: sensorStatus,
                s: s,
              ),
            ],
          ),
        );
      },
    );
  }

  static Color _ocrColor(SensorStatus status) => switch (status) {
    SensorStatus.idle => Colors.grey,
    SensorStatus.sensing => Colors.blue,
    SensorStatus.badPosition => Colors.orange,
    SensorStatus.goodPosition => Colors.blue,
    SensorStatus.aligned => Colors.green,
    SensorStatus.weightOk => Colors.green.shade800,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Barra de estado con shimmer mientras escanea y fill sólido cuando está OK
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedStatusBar extends StatelessWidget {
  final Color color;
  final double width;
  final SensorStatus status;

  const _AnimatedStatusBar({
    required this.color,
    required this.width,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isScanning =
        status == SensorStatus.sensing || status == SensorStatus.badPosition;

    final bar = AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: width,
      height: 6,
      decoration: BoxDecoration(
        color: isScanning
            ? color.withValues(alpha: 0.3)
            : color.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
    );

    if (isScanning) {
      // Efecto shimmer de izquierda a derecha mientras escanea
      return Shimmer.fromColors(
        baseColor: color.withValues(alpha: 0.3),
        highlightColor: color.withValues(alpha: 0.9),
        period: const Duration(milliseconds: 1200),
        child: bar,
      );
    }

    // Peso OK → barra "llena" con bounce de entrada
    return bar
        .animate()
        .scaleX(begin: 0.2, end: 1, duration: 500.ms, curve: Curves.elasticOut)
        .fadeIn(duration: 300.ms);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _RightColumn extends StatelessWidget {
  final AppPalette colors;
  final AtkTransactionManager manager;
  final SensorStatus sensorStatus;
  final double s;

  const _RightColumn({
    required this.colors,
    required this.manager,
    required this.sensorStatus,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final ocrVehicleType = manager.get('ocrVehicleType')?.toString() ?? '';
    final ocrContainerNumbers =
        manager.get('ocrContainerNumbers')?.toString() ?? '';
    final contenedor = manager.contenedor ?? '';

    final displayContenedor = ocrVehicleType == 'truck_empty'
        ? 'Porteo'
        : (ocrContainerNumbers.isNotEmpty ? ocrContainerNumbers : contenedor);

    final pesoActual = manager.pesoActualBascula;
    final pesoFueLeido = pesoActual >= 0;
    final ocrListo =
        sensorStatus == SensorStatus.aligned ||
        sensorStatus == SensorStatus.weightOk;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _OcrSteps(status: sensorStatus, s: s, colors: colors),
        SizedBox(height: 28 * s),
        _WeightCard(
          pesoActual: pesoActual,
          pesoEsValido: pesoFueLeido,
          ocrListo: ocrListo,
          s: s,
        ),
        if (displayContenedor.isNotEmpty) ...[
          SizedBox(height: 24 * s),
          _ContenedorCard(
            displayContenedor: displayContenedor,
            colors: colors,
            s: s,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pasos OCR con animaciones por estado
// ─────────────────────────────────────────────────────────────────────────────
class _OcrSteps extends StatelessWidget {
  final SensorStatus status;
  final double s;
  final AppPalette colors;

  const _OcrSteps({
    required this.status,
    required this.s,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AtkTransactionManager>();

    final placa = manager.get('vehiculoPlaca')?.toString().trim() ?? '';
    final placaOk = placa.isNotEmpty;

    final ocrVehicleType = manager.get('ocrVehicleType')?.toString() ?? '';
    final ocrContainerNumbers =
        manager.get('ocrContainerNumbers')?.toString() ?? '';
    final contenedor = manager.contenedor ?? '';

    final ocrOk =
        ocrVehicleType == 'truck_empty' ||
        ocrContainerNumbers.trim().isNotEmpty ||
        contenedor.trim().isNotEmpty ||
        status == SensorStatus.aligned ||
        status == SensorStatus.weightOk;

    final pesoOk = manager.pesoActualBascula >= 1;

    final facialStarted = manager.get('ocrFacialStarted') == true;
    final facialOk = manager.get('ocrFacialOk') == true;

    final readyForFacial = pesoOk && ocrOk && placaOk;

    final steps = [
      (
        icon: Icons.monitor_weight_outlined,
        label: 'Peso',
        active: true,
        done: pesoOk,
      ),
      (
        icon: Icons.document_scanner,
        label: 'OCR',
        active: pesoOk || status.index >= SensorStatus.sensing.index,
        done: ocrOk,
      ),
      (
        icon: Icons.local_shipping_outlined,
        label: 'Placa',
        active: ocrOk,
        done: placaOk,
      ),
      (
        icon: Icons.face_retouching_natural_outlined,
        label: 'Facial',
        active: readyForFacial || facialStarted,
        done: facialOk,
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _StepDot(
            icon: steps[i].icon,
            label: steps[i].label,
            active: steps[i].active,
            done: steps[i].done,
            s: s,
            colors: colors,
          ),
          if (i < steps.length - 1)
            Expanded(
              child: _AnimatedConnector(done: steps[i].done, colors: colors),
            ),
        ],
      ],
    );
  }
}

// Línea conectora que se "llena" con shimmer o solid ─────────────────────────
class _AnimatedConnector extends StatelessWidget {
  final bool done;
  final AppPalette colors;

  const _AnimatedConnector({required this.done, required this.colors});

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Container(
        height: 3,
        color: Colors.green.withValues(alpha: 0.85),
      ).animate().scaleX(
        begin: 0,
        end: 1,
        duration: 600.ms,
        curve: Curves.easeOut,
        alignment: Alignment.centerLeft,
      );
    }

    return Shimmer.fromColors(
      baseColor: colors.textSecondary.withValues(alpha: 0.15),
      highlightColor: colors.textSecondary.withValues(alpha: 0.4),
      period: const Duration(milliseconds: 1500),
      child: Container(
        height: 3,
        color: colors.textSecondary.withValues(alpha: 0.18),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dot de paso — usa flutter_animate para bounce + shimmer + checkmark
// ─────────────────────────────────────────────────────────────────────────────
class _StepDot extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool done;
  final double s;
  final AppPalette colors;

  const _StepDot({
    required this.icon,
    required this.label,
    required this.active,
    required this.done,
    required this.s,
    required this.colors,
  });

  Color get _dotColor {
    if (done) return Colors.green;
    if (active) return colors.azulCorporativo;
    return colors.textSecondary.withValues(alpha: 0.3);
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = _dotColor;

    // Ícono con AnimatedSwitcher nativo — sin flutter_animate aquí
    final iconWidget = AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => ScaleTransition(
        scale: anim,
        child: RotationTransition(
          turns: Tween(
            begin: 0.15,
            end: 0.0,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.elasticOut)),
          child: child,
        ),
      ),
      child: Icon(
        done ? Icons.check_rounded : icon,
        key: ValueKey('${label}_$done'),
        size: 22 * s,
        color: dotColor,
      ),
    );

    // Círculo con AnimatedContainer nativo
    Widget dot = AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: 44 * s,
      height: 44 * s,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: dotColor.withValues(
          alpha: done
              ? 0.18
              : active
              ? 0.14
              : 0.06,
        ),
        border: Border.all(color: dotColor, width: done || active ? 2.3 : 1.2),
        boxShadow: active && !done
            ? [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.4),
                  blurRadius: 14,
                  spreadRadius: 3,
                ),
              ]
            : [],
      ),
      child: iconWidget,
    );

    // Shimmer solo mientras está activo — no cambia el tamaño del widget
    if (active && !done) {
      dot = Shimmer.fromColors(
        baseColor: dotColor.withValues(alpha: 0.7),
        highlightColor: dotColor,
        period: const Duration(milliseconds: 1100),
        child: dot,
      );
    }

    // ✅ SizedBox fijo para que la Row nunca desborde
    return SizedBox(
      width: 60 * s,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          SizedBox(height: 6 * s),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: 11 * s,
              fontWeight: active || done ? FontWeight.w800 : FontWeight.w400,
              color: active || done
                  ? dotColor
                  : colors.textSecondary.withValues(alpha: 0.5),
            ),
            child: Text(label, textAlign: TextAlign.center, maxLines: 1),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de peso — slide-up + pulso cuando el valor cambia
// ─────────────────────────────────────────────────────────────────────────────
class _WeightCard extends StatelessWidget {
  final double pesoActual;
  final bool pesoEsValido;
  final bool ocrListo;
  final double s;

  const _WeightCard({
    required this.pesoActual,
    required this.pesoEsValido,
    required this.ocrListo,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final Color cardColor = pesoEsValido
        ? Colors.green
        : ocrListo
        ? Colors.blue
        : Colors.orange;

    final String label = '${pesoActual.toStringAsFixed(0)} kg';

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 420 * s),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 20 * s),
        decoration: BoxDecoration(
          color: cardColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(24 * s),
          border: Border.all(color: cardColor, width: 2.4),
          // Glow verde cuando el peso es válido
          boxShadow: pesoEsValido
              ? [
                  BoxShadow(
                    color: cardColor.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícono con rotación cuando cambia de estado
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (child, anim) => RotationTransition(
                turns: Tween(begin: 0.1, end: 0.0).animate(
                  CurvedAnimation(parent: anim, curve: Curves.elasticOut),
                ),
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: Container(
                key: ValueKey(pesoEsValido),
                width: 62 * s,
                height: 62 * s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cardColor.withValues(alpha: 0.12),
                ),
                child: Icon(
                  pesoEsValido ? Icons.monitor_weight : Icons.hourglass_top,
                  size: 38 * s,
                  color: cardColor,
                ),
              ),
            ),
            SizedBox(width: 16 * s),
            // Número del peso: cada cambio hace slideUp + fade
            AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  transitionBuilder: (child, anim) => SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: const Offset(0, 0.4),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(parent: anim, curve: Curves.easeOut),
                        ),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Text(
                    label,
                    key: ValueKey(label),
                    style: TextStyle(
                      fontSize: pesoEsValido ? 46 * s : 22 * s,
                      fontWeight: FontWeight.bold,
                      color: cardColor,
                    ),
                  ),
                )
                .animate(key: ValueKey('${label}_glow'))
                .shimmer(
                  duration: 800.ms,
                  delay: 100.ms,
                  color: cardColor.withValues(alpha: 0.4),
                ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tarjeta de contenedor — flip de entrada al aparecer
// ─────────────────────────────────────────────────────────────────────────────
class _ContenedorCard extends StatelessWidget {
  final String displayContenedor;
  final AppPalette colors;
  final double s;

  const _ContenedorCard({
    required this.displayContenedor,
    required this.colors,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    final isPorteo = displayContenedor == 'Porteo';

    return Column(
      children: [
        Text(
          isPorteo ? 'Tipo de atención' : 'Contenedor',
          style: TextStyle(
            fontSize: 18 * s,
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0),
        SizedBox(height: 4 * s),
        // Número de contenedor con flipH de entrada
        Text(
              displayContenedor,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 52 * s,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
                color: colors.textPrimary,
              ),
            )
            .animate(key: ValueKey(displayContenedor))
            .flipH(duration: 500.ms, curve: Curves.easeOut)
            .fadeIn(duration: 300.ms)
            .shimmer(duration: 900.ms, delay: 300.ms),
      ],
    );
  }
}
