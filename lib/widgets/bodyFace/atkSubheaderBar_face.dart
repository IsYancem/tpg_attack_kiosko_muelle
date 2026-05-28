import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/utils/format/fecha_utils.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

enum FlowType { entrada, salida }

class AtkSubHeaderBarFace extends StatefulWidget {
  final double height;

  const AtkSubHeaderBarFace({super.key, required this.height});

  @override
  State<AtkSubHeaderBarFace> createState() => _AtkSubHeaderBarFaceState();
}

class _AtkSubHeaderBarFaceState extends State<AtkSubHeaderBarFace> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    const base = 100.0;
    final s = (widget.height / base).clamp(0.6, 2.0);

    return SizedBox(
      height: widget.height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32 * s),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(vertical: 4 * s),
              child: Text(
                'Acérquese al lector para verificar su rostro',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 36 * s,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),

            const Expanded(child: SizedBox.shrink()),

            Container(
              padding: EdgeInsets.symmetric(vertical: 6 * s),
              child: Text(
                _now.toFechaLargaEs(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 24 * s,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
