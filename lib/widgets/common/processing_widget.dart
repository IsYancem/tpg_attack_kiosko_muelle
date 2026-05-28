import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

/// 🎨 Widget de procesamiento sofisticado con animaciones impresionantes
/// Muestra un indicador de carga elegante mientras se procesa la transacción
class ProcessingWidget extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color primaryColor;
  final Color secondaryColor;
  final double size;

  const ProcessingWidget({
    super.key,
    this.title = 'Procesando transacción',
    this.subtitle = 'Por favor espere...',
    this.primaryColor = const Color(0xFF2196F3),
    this.secondaryColor = const Color(0xFF64B5F6),
    this.size = 80,
  });

  @override
  State<ProcessingWidget> createState() => _ProcessingWidgetState();
}

class _ProcessingWidgetState extends State<ProcessingWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _dotsController;

  late Animation<double> _pulseAnimation;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();

    // Rotación continua del anillo exterior
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Efecto de pulso del círculo central
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Efecto de onda expansiva
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _waveAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _waveController, curve: Curves.easeOut));

    // Animación de los puntos
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = context.palette.azulCorporativo;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 🎯 Indicador de carga animado
        SizedBox(
          width: widget.size * 1.5,
          height: widget.size * 1.5,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Onda expansiva
              AnimatedBuilder(
                animation: _waveAnimation,
                builder: (context, child) {
                  return Container(
                    width: widget.size * (1 + _waveAnimation.value * 0.5),
                    height: widget.size * (1 + _waveAnimation.value * 0.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.primaryColor.withValues(alpha:
                          1 - _waveAnimation.value,
                        ),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),

              // Segunda onda (desfasada)
              AnimatedBuilder(
                animation: _waveAnimation,
                builder: (context, child) {
                  final phase = (_waveAnimation.value + 0.5) % 1.0;
                  return Container(
                    width: widget.size * (1 + phase * 0.5),
                    height: widget.size * (1 + phase * 0.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: widget.secondaryColor.withValues(alpha:1 - phase),
                        width: 1.5,
                      ),
                    ),
                  );
                },
              ),

              // Anillo exterior giratorio con gradiente
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _rotationController.value * 2 * math.pi,
                    child: CustomPaint(
                      size: Size(widget.size, widget.size),
                      painter: _GradientArcPainter(
                        progress: 0.75,
                        primaryColor: widget.primaryColor,
                        secondaryColor: widget.secondaryColor,
                        strokeWidth: 4,
                      ),
                    ),
                  );
                },
              ),

              // Segundo anillo (rotación inversa)
              AnimatedBuilder(
                animation: _rotationController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: -_rotationController.value * 2 * math.pi * 0.7,
                    child: CustomPaint(
                      size: Size(widget.size * 0.7, widget.size * 0.7),
                      painter: _GradientArcPainter(
                        progress: 0.5,
                        primaryColor: widget.secondaryColor,
                        secondaryColor: widget.primaryColor.withValues(alpha:0.5),
                        strokeWidth: 3,
                      ),
                    ),
                  );
                },
              ),

              // Círculo central con pulso
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: widget.size * 0.35,
                      height: widget.size * 0.35,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            widget.primaryColor,
                            widget.primaryColor.withValues(alpha:0.7),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.primaryColor.withValues(alpha:0.4),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.sync,
                        color: primaryColor,
                        size: widget.size * 0.18,
                      ),
                    ),
                  );
                },
              ),

              // Partículas orbitando
              ...List.generate(6, (index) {
                return AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    final angle =
                        (_rotationController.value * 2 * math.pi) +
                        (index * math.pi / 3);
                    final radius = widget.size * 0.55;
                    final x = math.cos(angle) * radius;
                    final y = math.sin(angle) * radius;
                    final particleSize = 4.0 + (index % 3) * 2;

                    return Transform.translate(
                      offset: Offset(x, y),
                      child: Container(
                        width: particleSize,
                        height: particleSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index % 2 == 0
                              ? widget.primaryColor
                              : widget.secondaryColor,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (index % 2 == 0
                                          ? widget.primaryColor
                                          : widget.secondaryColor)
                                      .withValues(alpha:0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // 📝 Título con shimmer effect
        ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                widget.primaryColor,
                widget.secondaryColor,
                widget.primaryColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              transform: _ShimmerTransform(_rotationController.value),
            ).createShader(bounds);
          },
          child: Text(
            widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primaryColor,
              fontSize: widget.size * 0.22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // 📝 Subtítulo con puntos animados
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.subtitle,
              style: TextStyle(
                color: primaryColor,
                fontSize: widget.size * 0.16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            _AnimatedDots(
              controller: _dotsController,
              color: primaryColor.withValues(alpha:0.8),
              size: widget.size * 0.06,
            ),
          ],
        ),
      ],
    );
  }
}

/// Painter para arcos con gradiente
class _GradientArcPainter extends CustomPainter {
  final double progress;
  final Color primaryColor;
  final Color secondaryColor;
  final double strokeWidth;

  _GradientArcPainter({
    required this.progress,
    required this.primaryColor,
    required this.secondaryColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = SweepGradient(
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: [
        primaryColor.withValues(alpha:0),
        primaryColor,
        secondaryColor,
        secondaryColor.withValues(alpha:0),
      ],
      stops: const [0.0, 0.1, 0.9, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      rect.deflate(strokeWidth / 2),
      -math.pi / 2,
      progress * 2 * math.pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GradientArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Transform para efecto shimmer
class _ShimmerTransform extends GradientTransform {
  final double progress;

  const _ShimmerTransform(this.progress);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0, 0);
  }
}

/// Puntos animados (...)
class _AnimatedDots extends StatelessWidget {
  final AnimationController controller;
  final Color color;
  final double size;

  const _AnimatedDots({
    required this.controller,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final progress = controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.2;
            final animValue = ((progress + delay) % 1.0);
            final opacity = (math.sin(animValue * math.pi)).clamp(0.3, 1.0);

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: size * 0.3),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Widget de éxito animado para mostrar cuando la transacción termina
class SuccessWidget extends StatefulWidget {
  final String message;
  final Color color;
  final double size;

  const SuccessWidget({
    super.key,
    required this.message,
    this.color = const Color(0xFF4CAF50),
    this.size = 60,
  });

  @override
  State<SuccessWidget> createState() => _SuccessWidgetState();
}

class _SuccessWidgetState extends State<SuccessWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = context.palette.azulCorporativo;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha:0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: CustomPaint(
                  painter: _CheckPainter(
                    progress: _checkAnimation.value,
                    color: Colors.white,
                    strokeWidth: 4,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 500),
          opacity: _controller.value > 0.5 ? 1.0 : 0.0,
          child: Text(
            widget.message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: primaryColor.withValues(alpha:0.8),
              fontSize: widget.size * 0.25,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

/// Painter para el check animado
class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CheckPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final startX = size.width * 0.25;
    final startY = size.height * 0.5;
    final midX = size.width * 0.45;
    final midY = size.height * 0.7;
    final endX = size.width * 0.75;
    final endY = size.height * 0.35;

    if (progress <= 0.5) {
      // Primera línea del check
      final lineProgress = progress * 2;
      path.moveTo(startX, startY);
      path.lineTo(
        startX + (midX - startX) * lineProgress,
        startY + (midY - startY) * lineProgress,
      );
    } else {
      // Primera línea completa + segunda línea
      path.moveTo(startX, startY);
      path.lineTo(midX, midY);

      final lineProgress = (progress - 0.5) * 2;
      path.lineTo(
        midX + (endX - midX) * lineProgress,
        midY + (endY - midY) * lineProgress,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
