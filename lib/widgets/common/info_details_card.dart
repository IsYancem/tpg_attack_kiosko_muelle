import 'package:flutter/material.dart';

class InfoDetailsCard extends StatelessWidget {
  final String dress;
  final String contenedor;
  final String ubicacion;

  final Color? textColor; 
  final Color? borderColor; 
  final Color? surfaceColor; 

  const InfoDetailsCard({
    super.key,
    required this.dress,
    required this.contenedor,
    required this.ubicacion,
    this.textColor,
    this.borderColor,
    this.surfaceColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tColor = textColor ?? scheme.onSurface;
    final bColor = borderColor ?? (scheme.outlineVariant);
    final sColor = surfaceColor ?? scheme.surface;

    final List<Widget> infoTiles = [];

    if (dress.isNotEmpty) {
      infoTiles.add(
        _InfoTile(
          icon: Icons.adf_scanner,
          value: dress,
          textColor: tColor,
          borderColor: bColor,
        ),
      );
    }

    if (contenedor.isNotEmpty) {
      infoTiles.add(
        _InfoTile(
          icon: Icons.blinds_closed_sharp,
          value: contenedor,
          textColor: tColor,
          borderColor: bColor,
        ),
      );
    }

    if (ubicacion.isNotEmpty) {
      infoTiles.add(
        _InfoTile(
          icon: Icons.location_on,
          value: ubicacion,
          textColor: tColor,
          borderColor: bColor,
        ),
      );
    }

    if (infoTiles.isEmpty) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: sColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: bColor, width: 1),
        ),
        padding: const EdgeInsets.all(12),
        child: Center(
          child: Text(
            'Sin información adicional',
            style: TextStyle(
              color: tColor.withValues(alpha:0.7),
              fontSize: 16,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: sColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: bColor, width: 1),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // ← NUEVO: Usar lista dinámica con separadores condicionales
          for (int i = 0; i < infoTiles.length; i++) ...[
            infoTiles[i],
            // Solo agregar SizedBox si no es el último elemento
            if (i < infoTiles.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color textColor;
  final Color borderColor;

  const _InfoTile({
    required this.icon,
    required this.value,
    required this.textColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final circleBg = textColor.withValues(alpha:0.10); 

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icono con círculo sutil
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: circleBg, shape: BoxShape.circle),
            child: Icon(icon, size: 28, color: textColor.withValues(alpha:0.95)),
          ),
          const SizedBox(width: 12),

          // Texto (sin caption; solo valor grande)
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w800,
                fontSize: 36,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
