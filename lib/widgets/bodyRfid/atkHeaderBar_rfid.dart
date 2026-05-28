import 'package:flutter/material.dart';
import 'package:tpg_attack_kiosko_muelle/utils/theme/app_colors.dart';

class AtkHeaderRfid extends StatefulWidget {
  final String title;
  final String? assetImagePath;
  final ValueChanged<bool>? onModeChanged;

  /// Alto a ocupar (se manda desde fuera)
  final double height;

  const AtkHeaderRfid({
    super.key,
    required this.title,
    required this.height,
    this.assetImagePath,
    this.onModeChanged,
  });

  @override
  State<AtkHeaderRfid> createState() => _AtkHeaderRfidState();
}

class _AtkHeaderRfidState extends State<AtkHeaderRfid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final headerH = widget.height;
    const base = 112.0;
    final s = (headerH / base).clamp(0.5, 3.0);

    final logoH = 80.0 * s;
    final padV = 8.0 * s;
    final gapH = 16.0 * s;
    final titleFont = 40.0 * s;
    final subFont = 36.0 * s;

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

              // Título centrado con subrayado animado
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Attack Kiosko",
                    style: TextStyle(
                      fontSize: subFont,
                      color: p.headerSubtitle,
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
