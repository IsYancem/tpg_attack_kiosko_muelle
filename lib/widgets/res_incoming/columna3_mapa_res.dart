// lib/widgets/exp_incoming/columna3_mapa_exp.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tpg_attack_kiosko_muelle/config/incoming/res_incoming_visibility_config.dart.dart';
import 'package:tpg_attack_kiosko_muelle/services/atk_transaction_manager.dart';
import 'package:tpg_attack_kiosko_muelle/services/print/image_cache_service.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

class Columna3MapaRes extends StatelessWidget {
  const Columna3MapaRes({super.key});

  @override
  Widget build(BuildContext context) {
    if (!(ResIncomingVisibilityConfig.show['col3.visible'] ?? true)) {
      return const SizedBox.shrink();
    }

    final p = context.palette;
    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    // 📏 Escalas adaptativas (versión compacta)
    final padding = (w * 0.012).clamp(8, 18).toDouble();
    final borderRadius = (w * 0.009).clamp(6, 14).toDouble();
    final innerBorderRadius = (w * 0.008).clamp(5, 12).toDouble();
    final spacing = (h * 0.012).clamp(6, 14).toDouble();
    final messageHeight = (h * 0.07).clamp(45, 65).toDouble();
    final messageFontSize = (w * 0.014).clamp(12, 18).toDouble();

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.surfaceBorder, width: 1.2),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 🗺️ Imagen del mapa (dinámico o respaldo)
          if (ResIncomingVisibilityConfig.show['col3.mapa'] ?? true)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: p.panelBg,
                  border: Border.all(color: p.surfaceBorder, width: 1.0),
                  borderRadius: BorderRadius.circular(innerBorderRadius),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildMapaImage(context, innerBorderRadius),
              ),
            ),

          SizedBox(height: spacing),

          // 💬 Mensaje inferior
          if (ResIncomingVisibilityConfig.show['col3.mensajeInferior'] ?? true)
            Selector<AtkTransactionManager, String?>(
              selector: (_, m) => m.mensajeInferior,
              builder: (context, mensajeInferior, _) {
                return Container(
                  constraints: BoxConstraints(
                    minHeight: messageHeight * 1.5,
                    maxHeight: messageHeight * 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: p.panelTitleBlue,
                    borderRadius: BorderRadius.circular(innerBorderRadius),
                  ),
                  alignment: Alignment.center,
                  padding: EdgeInsets.symmetric(
                    horizontal: padding * 0.6,
                    vertical: 12,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOutBack,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(
                            begin: 0.8,
                            end: 1.0,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _buildResultMessage(
                      mensajeInferior,
                      messageFontSize,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// ✅ Widget de resultado (mensaje final)
  Widget _buildResultMessage(String? mensajeInferior, double fontSize) {
    final texto = (mensajeInferior?.isNotEmpty == true)
        ? mensajeInferior!
        : 'Proceso completado correctamente.';

    final lower = texto.toLowerCase();
    final isSuccess =
        lower.contains('bienvenido') ||
        lower.contains('completado') ||
        lower.contains('continúe') ||
        lower.contains('continua') ||
        lower.contains('continúe.');

    return Column(
      key: ValueKey('result_${texto.hashCode}'),
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isSuccess) ...[
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  width: fontSize,
                  height: fontSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.shade400,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha:0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: fontSize,
                  ),
                ),
              );
            },
          ),
          SizedBox(height: fontSize * 0.5),
        ],
        Text(
          texto,
          textAlign: TextAlign.center,
          softWrap: true,
          maxLines: null,
          overflow: TextOverflow.visible,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  /// ✅ Construye la imagen del mapa (desde caché, URL o asset)
  Widget _buildMapaImage(BuildContext context, double borderRadius) {
    // Usar Selector para escuchar solo cambios en mapaBytes y mapaUrl
    return Selector<AtkTransactionManager, _MapaState>(
      selector: (_, m) => _MapaState(m.mapaUrl, m.mapaBytes),
      builder: (context, state, _) {
        // 1) Si tenemos bytes cacheados, mostrar directamente
        if (state.bytes != null && state.bytes!.isNotEmpty) {
          return Image.memory(
            state.bytes!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => _buildFallbackImage(),
          );
        }

        // 2) Si tenemos URL pero no bytes, intentar cargar desde caché del servicio
        if (state.url != null && state.url!.isNotEmpty) {
          return _MapaFromUrl(url: state.url!, borderRadius: borderRadius);
        }

        // 3) Imagen de respaldo
        return _buildFallbackImage();
      },
    );
  }

  Widget _buildFallbackImage() {
    return Image.asset(
      'assets/images/warningValoraTuVida.png',
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      colorBlendMode: BlendMode.modulate,
      opacity: const AlwaysStoppedAnimation(0.85),
    );
  }
}

/// Estado inmutable para el Selector
class _MapaState {
  final String? url;
  final Uint8List? bytes;

  _MapaState(this.url, this.bytes);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _MapaState && other.url == url && other.bytes == bytes;
  }

  @override
  int get hashCode => Object.hash(url, bytes);
}

/// Widget que carga la imagen desde URL con caché
class _MapaFromUrl extends StatefulWidget {
  final String url;
  final double borderRadius;

  const _MapaFromUrl({required this.url, required this.borderRadius});

  @override
  State<_MapaFromUrl> createState() => _MapaFromUrlState();
}

class _MapaFromUrlState extends State<_MapaFromUrl> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(_MapaFromUrl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final bytes = await ImageCacheService.instance.getImage(widget.url);
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _loading = false;
          _error = bytes == null;
        });

        // Guardar en el manager para futura referencia
        if (bytes != null) {
          final manager = context.read<AtkTransactionManager>();
          manager.setManyWithoutNotify({'mapaBytes': bytes});
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 8),
            Text(
              'Cargando mapa...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_error || _bytes == null) {
      return Image.asset(
        'assets/images/warningValoraTuVida.png',
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        colorBlendMode: BlendMode.modulate,
        opacity: const AlwaysStoppedAnimation(0.85),
      );
    }

    return Image.memory(
      _bytes!,
      fit: BoxFit.contain,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/images/warningValoraTuVida.png',
        fit: BoxFit.contain,
      ),
    );
  }
}
