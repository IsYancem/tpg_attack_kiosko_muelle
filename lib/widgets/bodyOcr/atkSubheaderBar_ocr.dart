// lib/widgets/bodyOcr/atkSubheaderBar_ocr.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/utils/format/fecha_utils.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/bodyOcr/atkBodyBar_ocr.dart'
    show SensorStatus;

class AtkSubHeaderBarOcr extends StatefulWidget {
  final double height;
  final SensorStatus sensorStatus;

  const AtkSubHeaderBarOcr({
    super.key,
    required this.height,
    required this.sensorStatus,
  });

  @override
  State<AtkSubHeaderBarOcr> createState() => _AtkSubHeaderBarOcrState();
}

class _AtkSubHeaderBarOcrState extends State<AtkSubHeaderBarOcr> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final manager = context.watch<AtkTransactionManager>();

    final peso = manager.pesoActualBascula;
    final pesoOk = peso >= 1;

    final ocrVehicleType = manager.get('ocrVehicleType')?.toString() ?? '';
    final ocrContainerNumbers =
        manager.get('ocrContainerNumbers')?.toString() ?? '';
    final contenedor = manager.contenedor ?? '';

    final ocrOk = ocrVehicleType == 'truck_empty' ||
        ocrContainerNumbers.trim().isNotEmpty ||
        contenedor.trim().isNotEmpty ||
        widget.sensorStatus == SensorStatus.aligned ||
        widget.sensorStatus == SensorStatus.weightOk;

    final placa = manager.get('vehiculoPlaca')?.toString().trim() ?? '';
    final placaOk = placa.isNotEmpty;

    final facialStarted = manager.get('ocrFacialStarted') == true;
    final facialOk = manager.get('ocrFacialOk') == true;

    final allOk = pesoOk && ocrOk && placaOk && facialOk;

    const base = 100.0;
    final s = (widget.height / base).clamp(0.6, 2.0);

    return SizedBox(
      height: widget.height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32 * s),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        allOk
                            ? 'Facial validado, procesando transacción...'
                            : facialStarted
                                ? 'Validando facial del conductor...'
                                : 'Flujo de lectura: Peso / OCR / Placa / Facial',
                        key: ValueKey('$allOk-$facialStarted-$facialOk'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: allOk ? Colors.green : p.textPrimary,
                          fontSize: 25 * s,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 18 * s),
                  _StatusPill(
                    icon: Icons.monitor_weight_outlined,
                    text: pesoOk
                        ? 'Peso ${peso.toStringAsFixed(0)} kg'
                        : 'Esperando peso',
                    color: pesoOk ? Colors.green : Colors.orange,
                    done: pesoOk,
                    s: s,
                  ),
                  SizedBox(width: 10 * s),
                  _StatusPill(
                    icon: Icons.document_scanner_outlined,
                    text: ocrOk ? 'OCR listo' : 'Esperando OCR',
                    color: ocrOk ? Colors.green : p.azulCorporativo,
                    done: ocrOk,
                    s: s,
                  ),
                  SizedBox(width: 10 * s),
                  _StatusPill(
                    icon: Icons.local_shipping_outlined,
                    text: placaOk ? placa : 'Esperando placa',
                    color: placaOk ? Colors.green : Colors.deepPurple,
                    done: placaOk,
                    s: s,
                  ),
                  SizedBox(width: 10 * s),
                  _StatusPill(
                    icon: Icons.face_retouching_natural_outlined,
                    text: facialOk
                        ? 'Facial OK'
                        : facialStarted
                            ? 'Validando facial'
                            : 'Esperando facial',
                    color: facialOk
                        ? Colors.green
                        : facialStarted
                            ? p.azulCorporativo
                            : Colors.blueGrey,
                    done: facialOk,
                    s: s,
                  ),
                ],
              ),
            ),
            SizedBox(width: 24 * s),
            Text(
              _now.toFechaLargaEs(),
              textAlign: TextAlign.right,
              style: TextStyle(
                color: p.textSecondary,
                fontSize: 18 * s,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool done;
  final double s;

  const _StatusPill({
    required this.icon,
    required this.text,
    required this.color,
    required this.done,
    required this.s,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      padding: EdgeInsets.symmetric(horizontal: 15 * s, vertical: 9 * s),
      decoration: BoxDecoration(
        color: color.withValues(alpha: done ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: done ? 2.1 : 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: done ? 0.26 : 0.16),
            blurRadius: done ? 16 : 10,
            spreadRadius: done ? 1.5 : 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              done ? Icons.check_circle_rounded : icon,
              key: ValueKey(done),
              color: color,
              size: 22 * s,
            ),
          ),
          SizedBox(width: 8 * s),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 14 * s,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}