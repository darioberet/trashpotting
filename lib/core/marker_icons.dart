import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';

/// Rasterizza i marker della mappa (pin a goccia con icona, o anello
/// colorato con il numero per i gruppi) in [BitmapDescriptor], con una cache
/// in memoria per non ridisegnare la stessa combinazione più volte.
abstract final class MarkerIconFactory {
  static final Map<String, BitmapDescriptor> _cache = {};

  static double get _devicePixelRatio =>
      ui.PlatformDispatcher.instance.views.first.devicePixelRatio;

  // Pin: goccia 36×44 dp del redesign, su una tela con margine per l'ombra.
  static const _pinW = 36.0;
  static const _pinH = 44.0;
  static const _pinPadX = 4.0;
  static const _pinPadTop = 2.0;
  static const _pinCanvasW = _pinW + _pinPadX * 2;
  static const _pinCanvasH = _pinH + _pinPadTop + 6;

  /// Punto della bitmap che tocca la posizione sulla mappa: la punta della
  /// goccia (da passare a `Marker.anchor`).
  static const pinAnchor = Offset(0.5, (_pinPadTop + 42) / _pinCanvasH);

  static Future<BitmapDescriptor> pin({
    required Color color,
    IconData icon = AppIcons.delete,
    Color iconColor = Colors.white,
  }) {
    final key =
        'pin_${color.toARGB32()}_${icon.codePoint}_${iconColor.toARGB32()}';
    return _cached(key, () async {
      final dpr = _devicePixelRatio;
      return _rasterize(
        Size(_pinCanvasW * dpr, _pinCanvasH * dpr),
        imagePixelRatio: dpr,
        (canvas) {
          canvas.scale(dpr);
          canvas.translate(_pinPadX, _pinPadTop);
          final drop = _dropPath();

          // Ombra morbida sotto la goccia.
          canvas.drawPath(
            drop.shift(const Offset(0, 3)),
            Paint()
              ..color = AppColors.textPrimary.withAlpha(70)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
          );
          canvas.drawPath(drop, Paint()..color = color);
          canvas.drawPath(
            drop,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5,
          );
          _paintIcon(canvas, icon, const Offset(18, 16.5), 17, iconColor);
        },
      );
    });
  }

  /// Goccia del mockup: `M18 2C9.7 2 3 8.6 3 16.8c0 10 12.6 23.2 14.1 24.7
  /// a1.3 1.3 0 0 0 1.8 0C20.4 40 33 26.8 33 16.8 33 8.6 26.3 2 18 2Z`.
  static Path _dropPath() {
    return Path()
      ..moveTo(18, 2)
      ..cubicTo(9.7, 2, 3, 8.6, 3, 16.8)
      ..cubicTo(3, 26.8, 15.6, 40, 17.1, 41.5)
      ..quadraticBezierTo(18, 42.3, 18.9, 41.5)
      ..cubicTo(20.4, 40, 33, 26.8, 33, 16.8)
      ..cubicTo(33, 8.6, 26.3, 2, 18, 2)
      ..close();
  }

  /// Gruppo di segnalazioni vicine: cerchio bianco con il numero e un anello
  /// diviso nei colori degli stati, in proporzione a quante sono per stato.
  static Future<BitmapDescriptor> cluster({
    required Map<Color, int> countsByColor,
    double size = 50,
  }) {
    final entries = countsByColor.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    final key =
        'cluster_${entries.map((e) => '${e.key.toARGB32()}:${e.value}').join(',')}';
    return _cached(key, () async {
      final dpr = _devicePixelRatio;
      const pad = 6.0;
      final canvasSize = size + pad * 2;
      return _rasterize(
        Size(canvasSize * dpr, canvasSize * dpr),
        imagePixelRatio: dpr,
        (canvas) {
          canvas.scale(dpr);
          final center = Offset(canvasSize / 2, canvasSize / 2);
          final radius = size / 2;

          canvas.drawCircle(
            center.translate(0, 3),
            radius,
            Paint()
              ..color = AppColors.textPrimary.withAlpha(50)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
          canvas.drawCircle(center, radius, Paint()..color = Colors.white);

          // Anello: uno spicchio per stato, con un piccolo stacco tra l'uno
          // e l'altro quando sono più di uno.
          const ringWidth = 5.0;
          final ringRect = Rect.fromCircle(
            center: center,
            radius: radius - ringWidth / 2,
          );
          final gap = entries.length > 1 ? 0.06 : 0.0;
          var start = -math.pi / 2;
          for (final e in entries) {
            final sweep = 2 * math.pi * e.value / total;
            canvas.drawArc(
              ringRect,
              start + gap / 2,
              sweep - gap,
              false,
              Paint()
                ..color = e.key
                ..style = PaintingStyle.stroke
                ..strokeWidth = ringWidth,
            );
            start += sweep;
          }

          final textPainter = TextPainter(
            text: TextSpan(
              text: '$total',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(
            canvas,
            center - Offset(textPainter.width / 2, textPainter.height / 2),
          );
        },
      );
    });
  }

  static Future<BitmapDescriptor> _cached(
    String key,
    Future<BitmapDescriptor> Function() build,
  ) async {
    final cached = _cache[key];
    if (cached != null) return cached;
    final descriptor = await build();
    _cache[key] = descriptor;
    return descriptor;
  }

  static Future<BitmapDescriptor> _rasterize(
    Size pixelSize,
    void Function(Canvas canvas) paint, {
    required double imagePixelRatio,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paint(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      pixelSize.width.round(),
      pixelSize.height.round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: imagePixelRatio,
    );
  }

  static void _paintIcon(
    Canvas canvas,
    IconData icon,
    Offset center,
    double size,
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }
}
