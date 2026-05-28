import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tpg_attack_kiosko_muelle/screens/auth/rfidScanner_screen.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

class AtkHeaderTransaction extends StatefulWidget {
  final String title;
  final String? assetImagePath;
  final int initialCountdownSeconds;
  final ValueChanged<bool>? onModeChanged;

  /// Alto a ocupar (se manda desde fuera)
  final double height;

  const AtkHeaderTransaction({
    super.key,
    required this.title,
    required this.height,
    this.assetImagePath,
    this.initialCountdownSeconds = 0,
    this.onModeChanged,
  });

  @override
  State<AtkHeaderTransaction> createState() => _AtkHeaderTransactionState();
}

class _AtkHeaderTransactionState extends State<AtkHeaderTransaction>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  late DateTime _now;
  late int _remaining;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _remaining = widget.initialCountdownSeconds < 0
        ? 0
        : widget.initialCountdownSeconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _now = DateTime.now();

        if (_remaining > 0) {
          _remaining -= 1;
        } else if (_remaining == 0) {
          _remaining = -1; // evita múltiples ejecuciones

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const RfidScreen()),
                (route) => false,
              );
            }
          });
        }
      });
    });

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String _formatCountdown(int seconds) {
    final d = Duration(seconds: seconds < 0 ? 0 : seconds);
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final secs = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fechaHora = DateFormat(
      "EEEE, d 'de' MMMM 'de' yyyy HH:mm:ss",
    ).format(_now);

    final headerH = widget.height; // <- viene desde fuera
    const base = 112.0;
    final s = (headerH / base).clamp(0.5, 3.0); // escalado

    final logoH = 80.0 * s;
    final padV = 8.0 * s;
    final gapH = 16.0 * s;
    final subFont = 18.0 * s;
    final titleFont = 40.0 * s;
    final dtFont = 20.0 * s;
    final countdownFont = 28.0 * s;

    final underlineOpacity = _pulse.drive(
      Tween(begin: 0.65, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)),
    );

    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: headerH,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: padV, horizontal: gapH),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.assetImagePath != null)
                Image.asset(widget.assetImagePath!, height: logoH),
              if (widget.assetImagePath != null) SizedBox(width: gapH / 2),
              SizedBox(width: gapH),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Attack Kiosk",
                    style: TextStyle(
                      fontSize: subFont,
                      color: p.headerSubtitle,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final titleStyle = TextStyle(
                        fontSize: titleFont,
                        fontWeight: FontWeight.w700,
                        color: p.headerTitle,
                        letterSpacing: 0.5 * s,
                      );

                      final tp = TextPainter(
                        text: TextSpan(text: widget.title, style: titleStyle),
                        maxLines: 1,
                        ellipsis: '…',
                        textDirection: Directionality.of(context),
                      )..layout(minWidth: 0, maxWidth: constraints.maxWidth);

                      final underlineW = tp.size.width;

                      return AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: titleStyle,
                              ),
                              SizedBox(height: 6 * s),
                              FadeTransition(
                                opacity: underlineOpacity,
                                child: Container(
                                  width: underlineW,
                                  height: 3 * s,
                                  decoration: BoxDecoration(
                                    color: p.buttonBg,
                                    borderRadius: BorderRadius.circular(2 * s),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fechaHora,
                    style: TextStyle(fontSize: dtFont, color: p.headerDateTime),
                  ),
                  Text(
                    _formatCountdown(_remaining),
                    style: TextStyle(
                      fontSize: countdownFont,
                      fontWeight: FontWeight.bold,
                      color: p.headerCountdown,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
