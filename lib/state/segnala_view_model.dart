import 'package:flutter/foundation.dart';

import '../services/report_service.dart';

class SegnalaViewModel extends ChangeNotifier {
  SegnalaViewModel({required ReportService reportService})
      : _reportService = reportService;

  final ReportService _reportService;

  bool _sending = false;
  String? _photoPath;
  double? _latitude;
  double? _longitude;

  int _infoToken = 0;
  String? _lastInfo;

  int _errorToken = 0;
  Object? _lastError;
  final String _lastErrorFallback = 'Invio segnalazione non riuscito.';

  bool get sending => _sending;
  String? get photoPath => _photoPath;
  double? get latitude => _latitude;
  double? get longitude => _longitude;

  int get infoToken => _infoToken;
  String? get lastInfo => _lastInfo;

  int get errorToken => _errorToken;
  Object? get lastError => _lastError;
  String get lastErrorFallback => _lastErrorFallback;

  void setPhotoPath(String? path) {
    _photoPath = path;
    notifyListeners();
  }

  void setLocation({required double latitude, required double longitude}) {
    _latitude = latitude;
    _longitude = longitude;
    notifyListeners();
  }

  void clearPhoto() {
    _photoPath = null;
    notifyListeners();
  }

  void clearLocation() {
    _latitude = null;
    _longitude = null;
    notifyListeners();
  }

  void clearDraftExtras() {
    _photoPath = null;
    _latitude = null;
    _longitude = null;
    notifyListeners();
  }

  Future<void> submit({
    required bool firebaseReady,
    required String note,
    String? uid,
  }) async {
    if (_sending) return;

    if (!firebaseReady) {
      _lastInfo = 'Backend non disponibile: verifica Firebase e riprova.';
      _infoToken += 1;
      notifyListeners();
      return;
    }

    _sending = true;
    notifyListeners();

    try {
      await _reportService.submit(
        note: note,
        uid: uid,
        photoPath: _photoPath,
        latitude: _latitude,
        longitude: _longitude,
      );
      _lastInfo = 'Segnalazione inviata correttamente.';
      _infoToken += 1;
    } catch (e) {
      _lastError = e;
      _errorToken += 1;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }
}
