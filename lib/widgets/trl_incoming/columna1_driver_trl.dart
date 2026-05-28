// lib/widgets/trl_incoming/columna1_driver_trl.dart
// Autor: Abraham Yance
// Columna 1 — Datos del Conductor (versión TRL con soporte de URL de foto)

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/config/incoming/trl_incoming_visibility_config.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';
import 'package:tpg_attack_kiosko_muelle/widgets/common/atk_info_panel.dart';

class Columna1DriverTrl extends StatelessWidget {
  const Columna1DriverTrl({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(TrlIncomingVisibilityConfig.show['col1.visible'] ?? true)) {
      return const SizedBox.shrink();
    }

    final p = context.palette;
    final manager = context.watch<AtkTransactionManager>();

    final screenSize = MediaQuery.of(context).size;
    final h = screenSize.height;
    final w = screenSize.width;

    final padding = (w * 0.008).clamp(6, 14).toDouble();
    final borderRadius = (w * 0.009).clamp(6, 14).toDouble();
    final spacing = (h * 0.01).clamp(4, 10).toDouble();
    final iconSize = (w * 0.07).clamp(60, 90).toDouble();

    final aspectRatio = h > 800 ? 3 / 4 : 4 / 5;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.surfaceBorder, width: 1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ─────────────── FOTO DEL CONDUCTOR ───────────────
          if (TrlIncomingVisibilityConfig.show['col1.fotoConductor'] ?? true)
            AspectRatio(
              aspectRatio: aspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  color: p.panelBg,
                  border: Border.all(color: p.surfaceBorder, width: 1.2),
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: _buildDriverPhoto(
                  manager.driverPhotoUrl,
                  borderRadius,
                  iconSize,
                ),
              ),
            ),

          SizedBox(height: spacing),

          // ─────────────── CÉDULA ───────────────
          if (TrlIncomingVisibilityConfig.show['col1.cedula'] ?? true)
            AtkInfoPanel(
              title: 'CÉDULA',
              value: manager.driverCedula,
              fontSize: w * 0.012,
            ),
        ],
      ),
    );
  }

  /// Construye la imagen del conductor desde URL o usa fallback visual
  Widget _buildDriverPhoto(String? imgB64, double radius, double iconSize) {
    return _DriverPhotoBase64(
      imgB64: imgB64,
      radius: radius,
      iconSize: iconSize,
    );
  }
}

class _DriverPhotoBase64 extends StatefulWidget {
  final String? imgB64;
  final double radius;
  final double iconSize;

  const _DriverPhotoBase64({
    required this.imgB64,
    required this.radius,
    required this.iconSize,
  });

  @override
  State<_DriverPhotoBase64> createState() => _DriverPhotoBase64State();
}

class _DriverPhotoBase64State extends State<_DriverPhotoBase64> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _decode(next: widget.imgB64);
  }

  @override
  void didUpdateWidget(covariant _DriverPhotoBase64 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imgB64 != widget.imgB64) {
      _decode(next: widget.imgB64);
    }
  }

  void _decode({required String? next}) {
    if (next == null || next.trim().isEmpty) {
      _bytes = null;
      return;
    }

    try {
      var s = next.trim();

      // ✅ Soporta: "data:image/png;base64,AAAA..."
      final idx = s.indexOf('base64,');
      if (idx >= 0) {
        s = s.substring(idx + 'base64,'.length);
      }

      _bytes = base64Decode(s);
    } catch (_) {
      _bytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) {
      return Center(
        child: Icon(
          Icons.person,
          size: widget.iconSize,
          color: Colors.grey[400],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.radius),
      child: Image.memory(
        _bytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) =>
            Image.asset('assets/images/tpg_logo.png', fit: BoxFit.contain),
      ),
    );
  }
}
