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
  String? _reportType;
  String? _address;

  @override
  String get lastErrorFallback => 'Invio segnalazione non riuscito.';

  bool get sending => _sending;
  String? get photoPath => _photoPath;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String? get reportType => _reportType;
  String? get address => _address;

  void setPhotoPath(String? path) {
    _photoPath = path;
    notifyListeners();
  }

  void setLocation({
    required double latitude,
    required double longitude,
    String? address,
  }) {
    _latitude = latitude;
    _longitude = longitude;
    _address = address;
    notifyListeners();
  }

  void clearPhoto() {
    _photoPath = null;
    notifyListeners();
  }

  void clearLocation() {
    _latitude = null;
    _longitude = null;
    _address = null;
    notifyListeners();
  }

  void setReportType(String? type) {
    _reportType = type;
    notifyListeners();
  }

  void clearDraftExtras() {
    _photoPath = null;
    _latitude = null;
    _longitude = null;
    _reportType = null;
    _address = null;
    notifyListeners();
  }

  Future<void> submit({
    required bool firebaseReady,
    required String note,
    String? uid,
    String? displayName,
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
        displayName: displayName,
        photoPath: _photoPath,
        latitude: _latitude,
        longitude: _longitude,
        type: _reportType,
        address: _address,
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
