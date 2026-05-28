import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Si ya tienes tu propio GlassCard, reemplaza por tu import.
class GlassCard extends StatelessWidget {
  final Widget child;
  const GlassCard({super.key, required this.child});
  @override
  Widget build(BuildContext context) => child;
}

class MapCard extends StatelessWidget {
  final String? mapUrl;
  final String? ubicacion;
  final String? gate;
  final bool noError;

  const MapCard({
    super.key,
    this.mapUrl,
    this.ubicacion,
    this.gate,
    this.noError = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final txtTheme = Theme.of(context).textTheme;

    // ← NUEVA LÓGICA: Detectar caso específico
    final isSpecificDefaultCase =
        mapUrl == 'https://www.tpg.com.ec/MapaTPG/not_found.png' &&
        (ubicacion == null || ubicacion!.isEmpty);

    // 1️⃣ "default" O "not_found" → usa imagen por defecto
    final isDefaultMap =
        mapUrl == null ||
        mapUrl!.isEmpty ||
        mapUrl!.contains('default.png') ||
        mapUrl!.contains('not_found.png');

    // Terminal y Área (solo si ubicación no está vacía)
    String terminal = 'N/A';
    String area = 'N/A';
    if (ubicacion != null && ubicacion!.isNotEmpty && ubicacion!.length >= 5) {
      terminal = ubicacion!.substring(0, 2);
      area = ubicacion!.substring(3, 5);
    }

    // ← MODIFICADO: No mostrar mensaje en el caso específico
    final mensaje = (isDefaultMap && !isSpecificDefaultCase)
        ? '  Mapa no asignado\n'
              'Terminal: $terminal\n'
              'Área: $area\n'
              'Ubicación "$ubicacion"\n'
              'Báscula "$gate"'
        : '';

    // 🎨 Colores según tema (y estado error/noError)
    // ← MODIFICADO: No considerar error en el caso específico
    final isError = isDefaultMap && noError == false && !isSpecificDefaultCase;

    final bgColor = isError ? scheme.errorContainer : scheme.surface;
    final borderColor = isError ? scheme.error : (scheme.outlineVariant);
    final overlayColor = isError
        ? scheme.error.withValues(alpha:0.22)
        : Colors.transparent;
    final iconColor = isError ? scheme.error : (scheme.onSurfaceVariant);
    final placeholderBg = scheme.surfaceVariant.withValues(alpha:0.4);
    final placeholderFg = scheme.onSurfaceVariant;

    return GlassCard(
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1),
        ),
        padding: const EdgeInsets.all(1),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagen optimizada
            Expanded(
              child: (isDefaultMap && noError) || isSpecificDefaultCase
                  // ← MODIFICADO: Caso NO error O caso específico: muestra imagen según corresponda
                  ? Center(
                      child: isSpecificDefaultCase
                          // Caso específico: mostrar la imagen default.png desde la URL
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl:
                                    'https://www.tpg.com.ec/MapaTPG/default.png',
                                fit: BoxFit.contain,
                                fadeInDuration: const Duration(
                                  milliseconds: 200,
                                ),
                                fadeOutDuration: const Duration(
                                  milliseconds: 100,
                                ),
                                placeholder: (_, __) => Container(
                                  color: placeholderBg,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  placeholderFg,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Cargando mapa...',
                                          style: txtTheme.bodySmall?.copyWith(
                                            color: placeholderFg,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: placeholderBg,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.map_outlined,
                                        size: 40,
                                        color: placeholderFg,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Mapa no disponible',
                                        style: txtTheme.bodySmall?.copyWith(
                                          color: placeholderFg,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          // Caso normal sin error: mostrar asset local
                          : Image.asset(
                              'assets/images/warningValoraTuVida.png',
                              fit: BoxFit.contain,
                            ),
                    )
                  : Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox.expand(
                            child: CachedNetworkImage(
                              imageUrl: isError
                                  ? 'https://www.tpg.com.ec/MapaTPG/default.png'
                                  : mapUrl!,
                              fit: isError ? BoxFit.cover : BoxFit.contain,
                              fadeInDuration: const Duration(milliseconds: 200),
                              fadeOutDuration: const Duration(
                                milliseconds: 100,
                              ),
                              placeholder: (_, __) => Container(
                                color: placeholderBg,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                placeholderFg,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Cargando mapa...',
                                        style: txtTheme.bodySmall?.copyWith(
                                          color: placeholderFg,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: placeholderBg,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.map_outlined,
                                      size: 40,
                                      color: placeholderFg,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Mapa no disponible',
                                      style: txtTheme.bodySmall?.copyWith(
                                        color: placeholderFg,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (overlayColor != Colors.transparent)
                          Positioned.fill(
                            child: Container(color: overlayColor),
                          ),
                      ],
                    ),
            ),

            // ← MODIFICADO: No mostrar mensaje en el caso específico
            if (mensaje.isNotEmpty && !noError && !isSpecificDefaultCase) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, color: iconColor, size: 32),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mensaje,
                      style: txtTheme.bodyMedium?.copyWith(
                        color: iconColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}