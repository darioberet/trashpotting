import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// Segnaposto di caricamento che "pulsa" con la forma del contenuto in
/// arrivo: dà subito l'idea di cosa comparirà, a differenza di una rotellina.
class SkeletonPulse extends StatefulWidget {
  const SkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rispetta "Rimuovi animazioni" dell'accessibilità di Android.
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return FadeTransition(
      opacity: Tween(
        begin: 0.45,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}

/// Blocco grigio arrotondato.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.palette.divider.withAlpha(110),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// Elenco di card finte con miniatura e due righe di testo: per le liste di
/// segnalazioni (Mappa, Le mie segnalazioni) e per la classifica.
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.count = 4,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
    this.thumbSize = 64,
    this.circleThumb = false,
  });

  final int count;
  final EdgeInsets padding;
  final double thumbSize;
  final bool circleThumb;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Caricamento in corso',
      child: SkeletonPulse(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          itemCount: count,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) => Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.palette.surfaceWarm,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SkeletonBox(
                  width: thumbSize,
                  height: thumbSize,
                  radius: circleThumb ? thumbSize / 2 : 8,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Larghezze diverse per riga: sembra testo vero.
                      FractionallySizedBox(
                        widthFactor: i.isEven ? 0.75 : 0.6,
                        child: const SkeletonBox(height: 14),
                      ),
                      const SizedBox(height: 10),
                      FractionallySizedBox(
                        widthFactor: i.isEven ? 0.5 : 0.65,
                        child: const SkeletonBox(height: 10),
                      ),
                    ],
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
