import 'package:flutter/foundation.dart';

/// Mixin for ChangeNotifier subclasses that need to emit one-time info/error
/// messages to the UI via an incrementing token. The UI compares the current
/// token with the last seen token to detect new messages without re-firing.
mixin NotifierMessageMixin on ChangeNotifier {
  int _infoToken = 0;
  String? _lastInfo;

  int _errorToken = 0;
  Object? _lastError;

  /// Subclasses must provide a human-readable fallback for unknown errors.
  String get lastErrorFallback;

  int get infoToken => _infoToken;
  String? get lastInfo => _lastInfo;

  int get errorToken => _errorToken;
  Object? get lastError => _lastError;

  @protected
  void setInfo(String message) {
    _lastInfo = message;
    _infoToken += 1;
  }

  @protected
  void setError(Object error) {
    _lastError = error;
    _errorToken += 1;
  }
}
