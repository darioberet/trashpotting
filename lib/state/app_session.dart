import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../core/error_mapper.dart';

class AppUiMessage {
  const AppUiMessage({required this.text, required this.isError, required this.token});

  final String text;
  final bool isError;
  final int token;
}

class AppSession extends ChangeNotifier {
  AppSession({
    required bool firebaseReady,
    Object? firebaseError,
    FirebaseAuth? auth,
    String? initialUserId,
    bool bindAuthStream = true,
  })  : _firebaseReady = firebaseReady,
        _firebaseError = firebaseError,
        _auth = auth,
        _currentUserId = initialUserId,
        _bindAuthStream = bindAuthStream {
    _startAuthBindingIfNeeded();
  }

  final FirebaseAuth? _auth;
  final bool _bindAuthStream;
  StreamSubscription<User?>? _authSub;

  bool _firebaseReady;
  Object? _firebaseError;
  User? _currentUser;
  String? _currentUserId;
  int _messageCounter = 0;
  AppUiMessage? _message;

  bool get firebaseReady => _firebaseReady;
  Object? get firebaseError => _firebaseError;
  User? get currentUser => _currentUser;
  String? get currentUserId => _currentUser?.uid ?? _currentUserId;
  AppUiMessage? get message => _message;

  void updateFirebaseState({required bool ready, Object? error}) {
    final changed = ready != _firebaseReady || error != _firebaseError;
    _firebaseReady = ready;
    _firebaseError = error;
    if (_firebaseReady) {
      _startAuthBindingIfNeeded();
    } else {
      _authSub?.cancel();
      _authSub = null;
      _currentUser = null;
      _currentUserId = null;
    }
    if (changed) notifyListeners();
  }

  void publishError(Object error, {String fallback = 'Operazione non riuscita.'}) {
    _publishMessage(
      text: mapAppError(error, fallback: fallback),
      isError: true,
    );
  }

  void publishInfo(String text) {
    _publishMessage(text: text, isError: false);
  }

  void _publishMessage({required String text, required bool isError}) {
    _messageCounter += 1;
    _message = AppUiMessage(text: text, isError: isError, token: _messageCounter);
    notifyListeners();
  }

  void _startAuthBindingIfNeeded() {
    if (!_firebaseReady || _authSub != null || !_bindAuthStream) return;
    final auth = _auth ?? FirebaseAuth.instance;
    _currentUser = auth.currentUser;
    _currentUserId = _currentUser?.uid;
    _authSub = auth.authStateChanges().listen((user) {
      _currentUser = user;
      _currentUserId = user?.uid;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

class AppSessionScope extends InheritedNotifier<AppSession> {
  const AppSessionScope({
    super.key,
    required AppSession session,
    required super.child,
  }) : super(notifier: session);

  static AppSession watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppSessionScope>();
    assert(scope != null, 'AppSessionScope non trovato nel widget tree.');
    return scope!.notifier!;
  }

  static AppSession of(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AppSessionScope>();
    final scope = element?.widget as AppSessionScope?;
    assert(scope != null, 'AppSessionScope non trovato nel widget tree.');
    return scope!.notifier!;
  }
}
