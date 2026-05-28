// lib/widgets/bodyFace/atkBodyBar_face.dart
// Autor: Abraham Yance
// Actualizado: 2025-11-11
// 💡 Ya no usa widget.transaction, sino que obtiene placa desde AtkTransactionManager

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/rfidScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/logger/log_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

class AtkBodyBarFace extends StatefulWidget {
  final double height;

  const AtkBodyBarFace({super.key, required this.height});

  @override
  State<AtkBodyBarFace> createState() => _AtkBodyBarFaceState();
}

class _AtkBodyBarFaceState extends State<AtkBodyBarFace> {
  late Duration _remainingTime;
  Timer? _timer;
  Timer? _clockTimer;
  late String _currentTime;

  static const _initialSeconds = 80;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _remainingTime = const Duration(seconds: _initialSeconds);
    _currentTime = _deriveCurrentTime();

    // 👉 Guardar el valor inicial en AppStateManager
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = context.read<AtkTransactionManager>();
      appState.setFlowRemainingSeconds(_remainingTime.inSeconds);
    });

    _startCountdown();
    _startClock();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  String _deriveCurrentTime() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(now.hour)}:${two(now.minute)}:${two(now.second)} – ${two(now.day)}/${two(now.month)}/${now.year}";
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _currentTime = _deriveCurrentTime());
    });
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _timer?.cancel();
        return;
      }

      final manager = context.read<AtkTransactionManager>();

      if (_remainingTime.inSeconds <= 0) {
        _handleTimeout();
      } else {
        setState(() {
          _remainingTime = _remainingTime - const Duration(seconds: 1);
        });

        // 👉 Actualizar el tiempo restante global
        manager.setFlowRemainingSeconds(_remainingTime.inSeconds);

        // 🔎 NUEVA LÓGICA:
        // Cuando queden exactamente 50 segundos, validamos el peso en báscula
        if (_remainingTime.inSeconds == 50 && !_navigated) {
          final peso = manager.pesoActualBascula;

          final pesoInvalido =
              peso.isNaN || peso <= 0; // cero, negativo, null, NaN, etc.

          if (pesoInvalido) {
            // Log opcional para trazabilidad
            LogService.instance.logRequest('FACE_NO_WEIGHT_TIMEOUT', {
              'pesoActualBascula': peso,
              'remainingSeconds': _remainingTime.inSeconds,
              'reason':
                  'Sin peso válido al llegar a 50 segundos — se asume que el vehículo no entró',
            });

            // 👇 Reutilizamos el mismo flujo de timeout:
            _handleTimeout();
          }
        }
      }
    });
  }

  void _handleTimeout() {
    if (_navigated) return;
    _navigated = true;

    _timer?.cancel();
    _clockTimer?.cancel();

    if (!mounted) return;
    setState(() => _remainingTime = Duration.zero);

    // 👉 limpiar contador global
    final appState = context.read<AtkTransactionManager>();
    appState.setFlowRemainingSeconds(0);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RfidScreen()),
    );
  }

  void _reiniciarTimer() {
    setState(() {
      _remainingTime += const Duration(seconds: 60);
    });

    // 👉 Reflejar el nuevo tiempo en AppStateManager
    final appState = context.read<AtkTransactionManager>();
    appState.setFlowRemainingSeconds(_remainingTime.inSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AtkTransactionManager>();
    final regNumber = manager.vehiculoPlaca ?? '';
    final colors = context.palette;
    final height = widget.height;
    final size = MediaQuery.sizeOf(context);
    final s = (height / 680.0).clamp(0.6, 1.6);
    final isNarrow = size.width < 1000;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24 * s, vertical: 12 * s),
        child: isNarrow
            ? _buildVertical(colors, regNumber, size, s)
            : _buildHorizontal(colors, regNumber, size, s),
      ),
    );
  }

  Widget _lottieFillHeight({required bool isNarrow, required Size screenSize}) {
    return LayoutBuilder(
      builder: (context, box) {
        final maxH = box.maxHeight.isFinite ? box.maxHeight : widget.height;
        double maxByWidth = double.infinity;
        if (!isNarrow) {
          const horizontalPadding = 24.0 * 2;
          const gapBetweenCols = 24.0;
          final availableHalf =
              (screenSize.width - horizontalPadding - gapBetweenCols) / 2;
          maxByWidth = availableHalf * 0.98;
        }
        final side = math.min(maxH * 0.98, maxByWidth);
        return Center(
          child: Lottie.asset(
            'assets/animations/face_animation.json',
            width: side,
            height: side,
            fit: BoxFit.contain,
            repeat: true,
          ),
        );
      },
    );
  }

  Widget _buildHorizontal(
    AppPalette colors,
    String regNumber,
    Size screenSize,
    double s,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 1,
          child: _lottieFillHeight(isNarrow: false, screenSize: screenSize),
        ),
        SizedBox(width: 24 * s),
        Expanded(
          flex: 1,
          child: _RightColumn(
            colors: colors,
            currentTime: _currentTime,
            remaining: _remainingTime,
            onMoreTime: _reiniciarTimer,
            regNumber: regNumber,
            s: s,
          ),
        ),
      ],
    );
  }

  Widget _buildVertical(
    AppPalette colors,
    String regNumber,
    Size screenSize,
    double s,
  ) {
    return LayoutBuilder(
      builder: (context, box) {
        final maxH = box.maxHeight.isFinite ? box.maxHeight : widget.height;
        final side = maxH * 0.9;
        return SingleChildScrollView(
          child: Column(
            children: [
              Center(
                child: Lottie.asset(
                  'assets/animations/face_animation.json',
                  width: side,
                  height: side,
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
              SizedBox(height: 20 * s),
              _RightColumn(
                colors: colors,
                currentTime: _currentTime,
                remaining: _remainingTime,
                onMoreTime: _reiniciarTimer,
                regNumber: regNumber,
                s: s,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RightColumn extends StatelessWidget {
  final AppPalette colors;
  final String currentTime;
  final Duration remaining;
  final VoidCallback onMoreTime;
  final String regNumber;
  final double s;

  const _RightColumn({
    required this.colors,
    required this.currentTime,
    required this.remaining,
    required this.onMoreTime,
    required this.regNumber,
    required this.s,
  });

  String _formatDuration(Duration duration) {
    String two(int n) => n.toString().padLeft(2, '0');
    final m = duration.inMinutes;
    final s = duration.inSeconds.remainder(60);
    return "${two(m)}:${two(s)}";
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<AtkTransactionManager>();
    final pesoActual = manager.pesoActualBascula;

    final isAlert = remaining.inSeconds <= 40;
    final alertColor = colors.headerCountdown;
    final cardColor = !isAlert
        ? colors.surface.withValues(alpha:0.90)
        : alertColor.withValues(alpha:0.12);
    final borderColor = isAlert ? alertColor : colors.surfaceBorder;
    final titleColor = isAlert ? alertColor : colors.textPrimary;
    final timeColor = isAlert ? alertColor : colors.textPrimary;
    final double maxCardWidth = 420 * s;

    final pesoEsValido = pesoActual > 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxCardWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ═══════════════════════════════════════════════════════════
              // ⚖️ CARD DE PESO - ÍCONO GRANDE Y CENTRADO
              // ═══════════════════════════════════════════════════════════
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 24 * s,
                  vertical: 20 * s,
                ),
                decoration: BoxDecoration(
                  color: pesoEsValido
                      ? Colors.green.withValues(alpha:0.14)
                      : Colors.orange.withValues(alpha:0.14),
                  borderRadius: BorderRadius.circular(24 * s),
                  border: Border.all(
                    color: pesoEsValido ? Colors.green : Colors.orange,
                    width: 2.4,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Ícono grande dentro de un círculo
                        Container(
                          width: 86 * s,
                          height: 86 * s,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (pesoEsValido ? Colors.green : Colors.orange)
                                .withValues(alpha:0.12),
                          ),
                          child: Icon(
                            Icons.monitor_weight, // ícono más “de báscula”
                            size: 52 * s,
                            color: pesoEsValido
                                ? Colors.green[700]
                                : Colors.orange[700],
                          ),
                        ),
                        SizedBox(width: 12 * s),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: animation,
                                  child: child,
                                ),
                              ),
                          child: Text(
                            pesoEsValido
                                ? '${pesoActual.toStringAsFixed(0)} kg'
                                : '...',
                            key: ValueKey<bool>(pesoEsValido),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 50 * s,
                              fontWeight: FontWeight.bold,
                              color: pesoEsValido
                                  ? Colors.green[800]
                                  : Colors.orange[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 20 * s),

              // ═══════════════════════════════════════════════════════════
              // 🕒 CARD DE TIEMPO RESTANTE
              // ═══════════════════════════════════════════════════════════
              AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(
                  horizontal: 24 * s,
                  vertical: 16 * s,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(22 * s),
                  border: Border.all(color: borderColor, width: 1.3),
                ),
                child: Column(
                  children: [
                    Text(
                      'Tiempo restante',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28 * s,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    SizedBox(height: 6 * s),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 1.0,
                        end: isAlert ? 1.06 : 1.0,
                      ),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOut,
                      builder: (context, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: Text(
                        _formatDuration(remaining),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 56 * s,
                          fontWeight: FontWeight.bold,
                          color: timeColor,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 22 * s),

              // ═══════════════════════════════════════════════════════════
              // 🔁 BOTÓN "MÁS TIEMPO"
              // ═══════════════════════════════════════════════════════════
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onMoreTime,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colors.textPrimary, width: 2),
                    foregroundColor: colors.textPrimary,
                    padding: EdgeInsets.symmetric(
                      vertical: 18 * s,
                      horizontal: 28 * s,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16 * s),
                    ),
                    textStyle: TextStyle(
                      fontSize: 26 * s,
                      fontWeight: FontWeight.bold,
                    ),
                    minimumSize: Size.fromHeight(60 * s),
                  ),
                  icon: Icon(Icons.refresh, size: 32 * s),
                  label: const Text('Más tiempo'),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: 24 * s),

        // ═══════════════════════════════════════════════════════════════
        // 🚛 Placa atendida
        // ═══════════════════════════════════════════════════════════════
        Text(
          'Atendiendo a:',
          style: TextStyle(fontSize: 26 * s, color: colors.textSecondary),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 6 * s),
        Text(
          regNumber.isNotEmpty ? regNumber : '---',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 64 * s,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.0,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}
