import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:trashpotting_v3/core/geo_utils.dart';
import 'package:trashpotting_v3/core/geohash.dart';

bool _inBounds(String hash, List<(String, String)> bounds) =>
    bounds.any((b) => hash.compareTo(b.$1) >= 0 && hash.compareTo(b.$2) <= 0);

void main() {
  test('geohashForLocation produce i valori di riferimento', () {
    expect(
      geohashForLocation(57.64911, 10.40744, precision: 11),
      'u4pruydqqvj',
    );
    expect(geohashForLocation(45.4642, 9.1900, precision: 5), 'u0nd9');
  });

  test('i range coprono tutti i punti entro il raggio', () {
    const centers = [(45.4642, 9.1900), (41.9028, 12.4964), (0.0, 179.99)];
    final rnd = math.Random(42);
    for (final (lat, lng) in centers) {
      for (final radiusKm in [1.0, 10.0, 50.0]) {
        final bounds = geohashQueryBounds(lat, lng, radiusKm * 1000);
        expect(bounds.length, lessThanOrEqualTo(9));
        for (var i = 0; i < 300; i++) {
          // Punto casuale nel quadrato attorno al centro; si verificano solo
          // quelli che cadono davvero dentro il cerchio.
          final pLat = lat + (rnd.nextDouble() * 2 - 1) * radiusKm / 111;
          var pLng = lng + (rnd.nextDouble() * 2 - 1) * radiusKm / 50;
          if (pLng > 180) pLng -= 360;
          if (haversineKm(lat, lng, pLat, pLng) > radiusKm) continue;
          final hash = geohashForLocation(pLat, pLng);
          expect(
            _inBounds(hash, bounds),
            isTrue,
            reason: '($pLat, $pLng) a $radiusKm km da ($lat, $lng)',
          );
        }
      }
    }
  });
}
