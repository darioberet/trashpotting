import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// Illustrazione su un cerchio verde chiaro, con qualche foglia sparsa.
class IllustrationCircle extends StatelessWidget {
  const IllustrationCircle({
    super.key,
    required this.size,
    required this.child,
  });

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    Widget leaf(double x, double y, double s, double turns, Color c) =>
        Positioned(
          left: x * size,
          top: y * size,
          child: Transform.rotate(
            angle: turns * 2 * math.pi,
            child: Icon(AppIcons.leaf, size: s * size, color: c),
          ),
        );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              left: size * 0.04,
              right: size * 0.04,
              top: size * 0.04,
              bottom: size * 0.04,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.greenLight,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned.fill(
              left: size * 0.08,
              right: size * 0.08,
              top: size * 0.06,
              bottom: size * 0.1,
              child: child,
            ),
            leaf(-0.04, 0.12, 0.1, 0.1, const Color(0xFF8ED9C0)),
            leaf(0.9, 0.04, 0.08, -0.2, AppColors.yellow),
            leaf(0.92, 0.66, 0.11, 0.3, const Color(0xFF8ED9C0)),
            leaf(0.02, 0.78, 0.07, 0.45, AppColors.yellow),
          ],
        ),
      ),
    );
  }
}

/// Disegna un'immagine dal fondo bianco "moltiplicandola" sul cerchio
/// verde: il bianco prende il colore del cerchio, come nel mockup.
class MultiplyImage extends StatefulWidget {
  const MultiplyImage({super.key, required this.asset});

  final String asset;

  @override
  State<MultiplyImage> createState() => _MultiplyImageState();
}

class _MultiplyImageState extends State<MultiplyImage> {
  ui.Image? _image;
  ImageStream? _stream;
  late final _listener = ImageStreamListener((info, _) {
    if (mounted) setState(() => _image = info.image);
  });

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _stream?.removeListener(_listener);
    _stream = AssetImage(
      widget.asset,
    ).resolve(createLocalImageConfiguration(context));
    _stream!.addListener(_listener);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MultiplyPainter(_image));
  }
}

class _MultiplyPainter extends CustomPainter {
  const _MultiplyPainter(this.image);

  final ui.Image? image;

  @override
  void paint(Canvas canvas, Size size) {
    final img = image;
    if (img == null) return;
    final src = Rect.fromLTWH(
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );
    final dst = Alignment.center.inscribe(
      applyBoxFit(BoxFit.contain, src.size, size).destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(
      img,
      src,
      dst,
      Paint()
        ..blendMode = BlendMode.multiply
        ..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_MultiplyPainter oldDelegate) =>
      oldDelegate.image != image;
}

/// Riquadro informativo sotto il testo di [IllustratedMessage].
class IllustratedNote {
  const IllustratedNote({
    required this.icon,
    required this.text,
    required this.bg,
    required this.fg,
    this.iconBg = Colors.white,
    this.iconFg,
    this.boldLead,
  });

  final IconData icon;
  final String text;

  /// Prima riga in grassetto, opzionale.
  final String? boldLead;
  final Color bg;
  final Color fg;
  final Color iconBg;
  final Color? iconFg;
}

/// Schermata a tutta pagina con illustrazione, titolo, testo e azioni in
/// fondo: blocchi (posizione, account sospeso) e stati vuoti.
class IllustratedMessage extends StatelessWidget {
  const IllustratedMessage({
    super.key,
    required this.illustration,
    required this.title,
    required this.message,
    this.badge,
    this.note,
    this.primary,
    this.secondary = const [],
    this.header,
  });

  final Widget illustration;
  final String title;
  final String message;

  /// Pillola sopra il titolo, es. "Posizione disattivata".
  final ({IconData icon, String label, Color bg, Color fg})? badge;
  final IllustratedNote? note;
  final Widget? primary;

  /// Pulsanti di testo sotto quello principale.
  final List<Widget> secondary;

  /// Riga in alto (es. pulsante indietro e titolo della pagina).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final n = note;
    final b = badge;
    return SafeArea(
      child: Column(
        children: [
          ?header,
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = math.min(
                  (constraints.maxHeight * 0.48).clamp(140.0, 300.0),
                  constraints.maxWidth - 48,
                );
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IllustrationCircle(size: size, child: illustration),
                        const SizedBox(height: 18),
                        if (b != null) ...[
                          Container(
                            height: 30,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: b.bg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(b.icon, size: 16, color: b.fg),
                                const SizedBox(width: 6),
                                Text(
                                  b.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: b.fg,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Semantics(
                          header: true,
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              height: 32 / 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.9,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 22 / 15,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (n != null) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: n.bg,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: n.iconBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    n.icon,
                                    size: 18,
                                    color: n.iconFg ?? n.fg,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Text.rich(
                                    TextSpan(
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 18 / 13,
                                        color: n.fg,
                                      ),
                                      children: [
                                        if (n.boldLead != null)
                                          TextSpan(
                                            text: '${n.boldLead}\n',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        TextSpan(text: n.text),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (primary != null || secondary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?primary,
                  if (secondary.isNotEmpty)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: secondary,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
