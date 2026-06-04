import 'package:flutter/foundation.dart';

import '../services/report_service.dart';

class SegnalaViewModel extends ChangeNotifier {
  SegnalaViewModel({required ReportService reportService})
      : _reportService = reportService;

  final ReportService _reportService;

  bool _sending = false;

  int _infoToken = 0;
  String? _lastInfo;

  int _errorToken = 0;
  Object? _lastError;
  final String _lastErrorFallback = 'Invio segnalazione non riuscito.';

  bool get sending => _sending;

  int get infoToken => _infoToken;
  String? get lastInfo => _lastInfo;

  int get errorToken => _errorToken;
  Object? get lastError => _lastError;
  String get lastErrorFallback => _lastErrorFallback;

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
      await _reportService.submit(note: note, uid: uid);
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
