import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/config/incoming/psc_incoming_visibility_config.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

class Columna1DriverPsc extends StatelessWidget {
  const Columna1DriverPsc({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(PscIncomingVisibilityConfig.show['col1.visible'] ?? true)) {
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

    final photoBase64 =
        manager.get('driverPhotoBase64')?.toString() ?? manager.driverPhotoUrl;

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
          if (PscIncomingVisibilityConfig.show['col1.fotoConductor'] ?? true)
            AspectRatio(
              aspectRatio: aspectRatio,
              child: Container(
                decoration: BoxDecoration(
                  color: p.panelBg,
                  border: Border.all(color: p.surfaceBorder, width: 1.2),
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
                child: _DriverPhotoBase64(
                  imgB64: photoBase64,
                  radius: borderRadius,
                  iconSize: iconSize,
                ),
              ),
            ),

          SizedBox(height: spacing),

          if (PscIncomingVisibilityConfig.show['col1.nombreConductor'] ?? true)
            _DriverNamePanel(
              value: manager.driverName,
              fontSize: (w * 0.012).clamp(13, 18).toDouble(),
              borderRadius: borderRadius,
            ),

          if ((manager.driverAlerta ?? '').trim().isNotEmpty) ...[
            SizedBox(height: spacing),
            _DriverAlertPanel(
              value: manager.driverAlerta,
              fontSize: (w * 0.010).clamp(11, 15).toDouble(),
              borderRadius: borderRadius,
            ),
          ],
        ],
      ),
    );
  }
}

class _DriverPhotoBase64 extends StatelessWidget {
  final String? imgB64;
  final double radius;
  final double iconSize;

  const _DriverPhotoBase64({
    required this.imgB64,
    required this.radius,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final bytes = _decodeBase64(imgB64);

    if (bytes == null || bytes.isEmpty) {
      return Center(
        child: Icon(
          Icons.person,
          size: iconSize,
          color: Colors.grey[400],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.memory(
        bytes,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) {
          return Image.asset(
            'assets/images/tpg_logo.png',
            fit: BoxFit.contain,
          );
        },
      ),
    );
  }

  Uint8List? _decodeBase64(String? value) {
    final raw = value?.trim();

    if (raw == null || raw.isEmpty) return null;

    try {
      var clean = raw;

      final idx = clean.indexOf('base64,');
      if (idx >= 0) {
        clean = clean.substring(idx + 'base64,'.length);
      }

      clean = clean.replaceAll(RegExp(r'\s+'), '');

      return base64Decode(clean);
    } catch (_) {
      return null;
    }
  }
}

class _DriverNamePanel extends StatelessWidget {
  final String? value;
  final double fontSize;
  final double borderRadius;

  const _DriverNamePanel({
    required this.value,
    required this.fontSize,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cleanValue = value?.trim().isNotEmpty == true ? value!.trim() : '---';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: p.panelBg,
        border: Border.all(color: p.surfaceBorder, width: 1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Column(
        children: [
          Text(
            'NOMBRE',
            style: TextStyle(
              color: p.textSecondary,
              fontSize: fontSize * 0.85,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            cleanValue,
            textAlign: TextAlign.center,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: p.textPrimary,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              height: 1.12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DriverAlertPanel extends StatelessWidget {
  final String? value;
  final double fontSize;
  final double borderRadius;

  const _DriverAlertPanel({
    required this.value,
    required this.fontSize,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cleanValue = value?.trim().isNotEmpty == true ? value!.trim() : '';

    if (cleanValue.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.10),
        border: Border.all(color: Colors.orange, width: 1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Text(
        cleanValue,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: p.textPrimary,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}