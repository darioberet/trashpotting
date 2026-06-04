import 'package:geolocator/geolocator.dart';

class GpsPosition {
  const GpsPosition({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class LocationService {
  Future<GpsPosition> getCurrentPosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw StateError('Servizi di localizzazione disattivati sul dispositivo.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
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

    return GpsPosition(latitude: pos.latitude, longitude: pos.longitude);
  }
}
