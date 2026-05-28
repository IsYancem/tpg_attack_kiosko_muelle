import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/utils/format/fecha_utils.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

enum FlowType { entrada, salida }

class AtkSubHeaderBarRfid extends StatefulWidget {
  final double height;
  final String personName; // se ignora (queda vacío)
  final FlowType flowType; // ya no se usa para el badge

  const AtkSubHeaderBarRfid({
    super.key,
    required this.height,
    required this.personName,
    required this.flowType,
  });

  @override
  State<AtkSubHeaderBarRfid> createState() => _AtkSubHeaderBarRfidState();
}

class _AtkSubHeaderBarRfidState extends State<AtkSubHeaderBarRfid> {
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

    const base = 80.0;
    final s = (widget.height / base).clamp(0.6, 2.0);

    return SizedBox(
      height: widget.height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Card(
          color: p.surface,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32 * s),
            child: Row(
              children: [
                const Expanded(child: SizedBox.shrink()),
                Container(
                  padding: EdgeInsets.symmetric(vertical: 6 * s),
                  child: Text(
                    _now.toFechaLargaEs(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 36 * s,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
