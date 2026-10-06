import 'package:flutter/widgets.dart';

/// Riduce tutto il testo dell'app di circa un punto (14 → 13) e poi applica
/// la dimensione del testo scelta nelle impostazioni del telefono, così
/// l'interfaccia è meno affollata senza togliere l'ingrandimento a chi lo usa.
class CompactTextScaler extends TextScaler {
  const CompactTextScaler(this.base);

  /// Scala di sistema (impostazioni di accessibilità).
  final TextScaler base;

  static const factor = 13 / 14;

  @override
  double scale(double fontSize) => base.scale(fontSize * factor);

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is CompactTextScaler && other.base == base;

  @override
  int get hashCode => Object.hash(CompactTextScaler, base);

  @override
  String toString() => 'CompactTextScaler($base × $factor)';
}
