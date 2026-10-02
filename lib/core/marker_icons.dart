import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/app_icons.dart';

/// Rasterizza marker personalizzati (cerchio colorato con icona, o badge
/// numerico per i cluster) in [BitmapDescriptor], con una cache in memoria
/// per evitare di ridisegnare la stessa combinazione più volte.
abstract final class MarkerIconFactory {
  static final Map<String, BitmapDescriptor> _cache = {};

  static double get _devicePixelRatio =>
      ui.PlatformDispatcher.instance.views.first.devicePixelRatio;

  static Future<BitmapDescriptor> pin({
    required Color color,
    IconData icon = AppIcons.delete,
    double size = 40, // dp — cerchio ~36px + bordo bianco, da design brief
  }) {
    final key = 'pin_${color.toString()}_${icon.codePoint}_$size';
    return _cached(key, () async {
      final dpr = _devicePixelRatio;
      final pixelSize = size * dpr;
      return _rasterize(pixelSize, imagePixelRatio: dpr, (canvas) {
        final radius = pixelSize / 2;
        final center = Offset(radius, radius);

        canvas.drawCircle(center, radius, Paint()..color = Colors.white);
        canvas.drawCircle(
          center,
          radius - pixelSize * 0.07,
          Paint()..color = color,
        );
        _paintIcon(canvas, icon, center, pixelSize * 0.5, Colors.white);
      });
    });
  }

  static Future<BitmapDescriptor> cluster({
    required int count,
    Color color = const Color(0xFF1D9E75),
    double size = 44, // dp
  }) {
    final key = 'cluster_${color.toString()}_$count';
    return _cached(key, () async {
      final dpr = _devicePixelRatio;
      final pixelSize = size * dpr;
      return _rasterize(pixelSize, imagePixelRatio: dpr, (canvas) {
        final radius = pixelSize / 2;
        final center = Offset(radius, radius);

        canvas.drawCircle(center, radius, Paint()..color = Colors.white);
        canvas.drawCircle(
          center,
          radius - pixelSize * 0.07,
          Paint()..color = color,
        );

        final textPainter = TextPainter(
          text: TextSpan(
            text: '$count',
            style: TextStyle(
              color: Colors.white,
              fontSize: pixelSize * 0.36,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          center - Offset(textPainter.width / 2, textPainter.height / 2),
        );
      });
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
    double pixelSize,
    void Function(Canvas canvas) paint, {
    required double imagePixelRatio,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paint(canvas);
    final picture = recorder.endRecording();
    final image = await picture.toImage(pixelSize.round(), pixelSize.round());
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
