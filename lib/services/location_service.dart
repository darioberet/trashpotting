import 'package:geolocator/geolocator.dart';

class GpsPosition {
  const GpsPosition({
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });

  final double latitude;
  final double longitude;

  /// Precisione della rilevazione GPS in metri, quando disponibile.
  final double? accuracy;
}

class LocationService {
  Future<GpsPosition> getCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw StateError(
        'Servizi di localizzazione disattivati sul dispositivo.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Se Android annulla la richiesta (es. due richieste insieme) il plugin
      // non risponde più: meglio considerarlo un rifiuto che restare appesi.
      permission = await Geolocator.requestPermission().timeout(
        const Duration(seconds: 60),
        onTimeout: () => LocationPermission.denied,
      );
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Permesso posizione negato.');
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    return GpsPosition(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
    );
  }
}
