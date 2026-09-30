import 'dart:math' as math;

/// Codifica geohash e calcolo dei range di query per cercare punti entro un
/// raggio su Firestore (porting dell'algoritmo di `geofire-common`).
///
/// Firestore non supporta query geografiche native: ogni documento salva il
/// proprio geohash e una ricerca per raggio diventa un piccolo insieme di
/// range `orderBy('geohash').startAt(start).endAt(end)`. I risultati vanno
/// poi filtrati con la distanza reale, perché i range coprono un'area un po'
/// più grande del cerchio.

const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
const _bitsPerChar = 5;
const _maxBitsPrecision = 22 * _bitsPerChar;
const _earthMeridionalCircumference = 40007860.0; // metri
const _metersPerDegreeLatitude = 110574.0;
const _earthEquatorialRadius = 6378137.0;
const _e2 = 0.00669447819799;
const _epsilon = 1e-12;

/// Precisione salvata sui documenti (10 caratteri ≈ 1 m).
const geohashStoredPrecision = 10;

String geohashForLocation(
  double latitude,
  double longitude, {
  int precision = geohashStoredPrecision,
}) {
  var latMin = -90.0, latMax = 90.0;
  var lngMin = -180.0, lngMax = 180.0;
  final hash = StringBuffer();
  var hashVal = 0;
  var bits = 0;
  var even = true;

  while (hash.length < precision) {
    if (even) {
      final mid = (lngMin + lngMax) / 2;
      if (longitude > mid) {
        hashVal = (hashVal << 1) + 1;
        lngMin = mid;
      } else {
        hashVal = hashVal << 1;
        lngMax = mid;
      }
    } else {
      final mid = (latMin + latMax) / 2;
      if (latitude > mid) {
        hashVal = (hashVal << 1) + 1;
        latMin = mid;
      } else {
        hashVal = hashVal << 1;
        latMax = mid;
      }
    }
    even = !even;
    if (bits < 4) {
      bits++;
    } else {
      bits = 0;
      hash.write(_base32[hashVal]);
      hashVal = 0;
    }
  }
  return hash.toString();
}

/// Range `[start, end]` di geohash che, insieme, coprono il cerchio di
/// [radiusMeters] attorno al centro.
List<(String, String)> geohashQueryBounds(
  double latitude,
  double longitude,
  double radiusMeters,
) {
  final queryBits = math.max(
    1,
    _boundingBoxBits(latitude, longitude, radiusMeters),
  );
  final precision = (queryBits / _bitsPerChar).ceil();
  final seen = <String>{};
  final bounds = <(String, String)>[];
  for (final (lat, lng) in _boundingBoxCoordinates(
    latitude,
    longitude,
    radiusMeters,
  )) {
    final range = _geohashQuery(
      geohashForLocation(lat, lng, precision: precision),
      queryBits,
    );
    if (seen.add('${range.$1}|${range.$2}')) bounds.add(range);
  }
  return bounds;
}

double _log2(double x) => math.log(x) / math.ln2;

double _degToRad(double deg) => deg * math.pi / 180;

double _metersToLongitudeDegrees(double distance, double latitude) {
  final radians = _degToRad(latitude);
  final num = math.cos(radians) * _earthEquatorialRadius * math.pi / 180;
  final denom = 1 / math.sqrt(1 - _e2 * math.sin(radians) * math.sin(radians));
  final deltaDeg = num * denom;
  if (deltaDeg < _epsilon) return distance > 0 ? 360 : 0;
  return math.min(360, distance / deltaDeg);
}

double _latitudeBitsForResolution(double resolution) => math.min(
  _log2(_earthMeridionalCircumference / 2 / resolution),
  _maxBitsPrecision.toDouble(),
);

double _longitudeBitsForResolution(double resolution, double latitude) {
  final degs = _metersToLongitudeDegrees(resolution, latitude);
  return degs.abs() > 0.000001 ? math.max(1, _log2(360 / degs)) : 1;
}

int _boundingBoxBits(double latitude, double longitude, double size) {
  final latDelta = size / _metersPerDegreeLatitude;
  final latNorth = math.min(90.0, latitude + latDelta);
  final latSouth = math.max(-90.0, latitude - latDelta);
  final bitsLat = _latitudeBitsForResolution(size).floor() * 2;
  final bitsLngNorth =
      _longitudeBitsForResolution(size, latNorth).floor() * 2 - 1;
  final bitsLngSouth =
      _longitudeBitsForResolution(size, latSouth).floor() * 2 - 1;
  return [
    bitsLat,
    bitsLngNorth,
    bitsLngSouth,
    _maxBitsPrecision,
  ].reduce(math.min);
}

double _wrapLongitude(double longitude) {
  if (longitude <= 180 && longitude >= -180) return longitude;
  final adjusted = longitude + 180;
  if (adjusted > 0) return (adjusted % 360) - 180;
  return 180 - (-adjusted % 360);
}

List<(double, double)> _boundingBoxCoordinates(
  double latitude,
  double longitude,
  double radius,
) {
  final latDegrees = radius / _metersPerDegreeLatitude;
  final latNorth = math.min(90.0, latitude + latDegrees);
  final latSouth = math.max(-90.0, latitude - latDegrees);
  final lngDegs = math.max(
    _metersToLongitudeDegrees(radius, latNorth),
    _metersToLongitudeDegrees(radius, latSouth),
  );
  final west = _wrapLongitude(longitude - lngDegs);
  final east = _wrapLongitude(longitude + lngDegs);
  return [
    (latitude, longitude),
    (latitude, west),
    (latitude, east),
    (latNorth, longitude),
    (latNorth, west),
    (latNorth, east),
    (latSouth, longitude),
    (latSouth, west),
    (latSouth, east),
  ];
}

(String, String) _geohashQuery(String geohash, int bits) {
  final precision = (bits / _bitsPerChar).ceil();
  if (geohash.length < precision) return (geohash, '$geohash~');
  final hash = geohash.substring(0, precision);
  final base = hash.substring(0, hash.length - 1);
  final lastValue = _base32.indexOf(hash[hash.length - 1]);
  final significantBits = bits - base.length * _bitsPerChar;
  final unusedBits = _bitsPerChar - significantBits;
  final startValue = (lastValue >> unusedBits) << unusedBits;
  final endValue = startValue + (1 << unusedBits);
  if (endValue > 31) return ('$base${_base32[startValue]}', '$base~');
  return ('$base${_base32[startValue]}', '$base${_base32[endValue]}');
}
