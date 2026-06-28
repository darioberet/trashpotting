import 'package:flutter/foundation.dart';

import '../services/report_service.dart';
import 'notifier_message_mixin.dart';

class SegnalaViewModel extends ChangeNotifier with NotifierMessageMixin {
  SegnalaViewModel({required ReportService reportService})
      : _reportService = reportService;

  final ReportService _reportService;

  bool _sending = false;
  String? _photoPath;
  double? _latitude;
  double? _longitude;

  @override
  String get lastErrorFallback => 'Invio segnalazione non riuscito.';

  bool get sending => _sending;
  String? get photoPath => _photoPath;
  double? get latitude => _latitude;
  double? get longitude => _longitude;

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
      setInfo('Backend non disponibile: verifica Firebase e riprova.');
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
      setInfo('Segnalazione inviata correttamente.');
    } catch (e) {
      setError(e);
    } finally {
      _sending = false;
      notifyListeners();
    }
  }
}
