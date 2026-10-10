import 'package:flutter/widgets.dart';

/// Proporzioni del testo stile "Too Good To Go": il testo corrente resta alla
/// sua dimensione, i titoli oltre [_threshold] crescono solo a metà, così le
/// intestazioni non schiacciano il resto. Poi si applica la dimensione scelta
/// nelle impostazioni del telefono, senza togliere l'ingrandimento a chi lo usa.
class CompactTextScaler extends TextScaler {
  const CompactTextScaler(this.base);

  /// Scala di sistema (impostazioni di accessibilità).
  final TextScaler base;

  static const _threshold = 16.0;

  /// 26 → 21, 22 → 19, 34 → 25; fino a 16 invariato.
  static double compress(double fontSize) => fontSize <= _threshold
      ? fontSize
      : _threshold + (fontSize - _threshold) / 2;

  @override
  double scale(double fontSize) => base.scale(compress(fontSize));

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor;

  @override
  bool operator ==(Object other) =>
      other is CompactTextScaler && other.base == base;

  @override
  int get hashCode => Object.hash(CompactTextScaler, base);

  @override
  String toString() => 'CompactTextScaler($base, titoli compressi)';
}
