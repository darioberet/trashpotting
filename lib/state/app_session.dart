import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../core/error_mapper.dart';
import '../models/app_user_profile.dart';
import '../repositories/user_profile_repository.dart';

class AppUiMessage {
  const AppUiMessage({
    required this.text,
    required this.isError,
    required this.token,
  });

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
    UserProfileRepository? userProfileRepository,
  }) : _firebaseReady = firebaseReady,
       _firebaseError = firebaseError,
       _auth = auth,
       _currentUserId = initialUserId,
       _bindAuthStream = bindAuthStream,
       _userProfileRepository =
           userProfileRepository ?? UserProfileRepository() {
    _startAuthBindingIfNeeded();
  }

  final FirebaseAuth? _auth;
  final bool _bindAuthStream;
  final UserProfileRepository _userProfileRepository;
  StreamSubscription<User?>? _authSub;

  bool _firebaseReady;
  Object? _firebaseError;
  User? _currentUser;
  String? _currentUserId;
  int _messageCounter = 0;
  AppUiMessage? _message;
  // Ottimistico finché non verificato: evita di bloccare un utente già
  // onboardato mentre la lettura Firestore è in corso.
  bool _onboardingComplete = true;
  // Username dell'utente corrente, letto da `users/{uid}` su Firestore
  // (unica fonte del nome: non si usa User.displayName di Firebase Auth).
  String? _username;

  bool get firebaseReady => _firebaseReady;
  Object? get firebaseError => _firebaseError;
  User? get currentUser => _currentUser;
  String? get currentUserId => _currentUser?.uid ?? _currentUserId;
  bool get emailVerified => _currentUser?.emailVerified ?? false;
  bool get onboardingComplete => _onboardingComplete;
  String? get username => _username;
  AppUiMessage? get message => _message;

  /// Profilo pubblico dell'utente corrente, da incorporare nei report
  /// (evento, partecipanti, chi pulisce) o da passare alla classifica.
  AppUserProfile? get currentProfile {
    final uid = currentUserId;
    return uid == null ? null : AppUserProfile(uid: uid, username: _username);
  }

  /// Aggiorna lo username in sessione dopo averlo salvato su Firestore.
  void setUsername(String? username) {
    if (username == _username) return;
    _username = username;
    notifyListeners();
  }

  /// Segna l'onboarding come completato (chiamato dalla schermata di
  /// onboarding) e sblocca subito il redirect del router.
  Future<void> markOnboardingComplete() async {
    final uid = currentUserId;
    if (uid == null) return;
    await _userProfileRepository.setOnboardingComplete(uid, true);
    if (!_onboardingComplete) {
      _onboardingComplete = true;
      notifyListeners();
    }
  }

  /// Backstop per i casi limite (utente che chiude l'app a metà onboarding):
  /// rieseguito ad ogni cambio di stato auth, non solo al primo login —
  /// la navigazione "vera" avviene esplicitamente da login/verifica email.
  Future<void> _refreshOnboardingStatus(String uid) async {
    try {
      final done = await _userProfileRepository.hasCompletedOnboarding(uid);
      final profile = await _userProfileRepository.fetchProfile(uid);
      if (currentUserId != uid) return; // utente cambiato nel frattempo
      final username = profile?.username;
      if (done != _onboardingComplete || username != _username) {
        _onboardingComplete = done;
        _username = username;
        notifyListeners();
      }
    } catch (_) {
      // Rete assente/errore: resta sul valore ottimistico corrente.
    }
  }

  /// Rilegge da Firestore flag di onboarding e username. Va chiamato dopo la
  /// verifica email e il login: il valore letto alla registrazione può
  /// essere precedente alla scrittura di `onboardingComplete: false`.
  Future<void> refreshOnboardingStatus() async {
    final uid = currentUserId;
    if (uid != null) await _refreshOnboardingStatus(uid);
  }

  /// Riallinea [currentUser] dopo un `reload()` o un `updateProfile`:
  /// l'oggetto [User] ricevuto da authStateChanges è uno snapshot e non vede
  /// cambi come la verifica dell'email, il nome o la foto, che quello stream
  /// non notifica. Senza questo il router continuerebbe a leggere
  /// emailVerified == false e Profilo/segnalazioni un nome vuoto.
  void refreshCurrentUser() {
    if (!_firebaseReady) return;
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user?.uid != _currentUser?.uid ||
        user?.emailVerified != _currentUser?.emailVerified ||
        user?.photoURL != _currentUser?.photoURL) {
      _currentUser = user;
      _currentUserId = user?.uid;
      notifyListeners();
    }
  }

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

  void publishError(
    Object error, {
    String fallback = 'Operazione non riuscita.',
  }) {
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
    _message = AppUiMessage(
      text: text,
      isError: isError,
      token: _messageCounter,
    );
    notifyListeners();
  }

  void _startAuthBindingIfNeeded() {
    if (!_firebaseReady || _authSub != null || !_bindAuthStream) return;
    final auth = _auth ?? FirebaseAuth.instance;
    _currentUser = auth.currentUser;
    _currentUserId = _currentUser?.uid;
    if (_currentUserId != null) {
      unawaited(_refreshOnboardingStatus(_currentUserId!));
    }
    _authSub = auth.authStateChanges().listen((user) {
      _currentUser = user;
      _currentUserId = user?.uid;
      if (user == null) {
        _onboardingComplete = true; // reset all'uscita
        _username = null;
      } else {
        unawaited(_refreshOnboardingStatus(user.uid));
      }
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
    final element = context
        .getElementForInheritedWidgetOfExactType<AppSessionScope>();
    final scope = element?.widget as AppSessionScope?;
    assert(scope != null, 'AppSessionScope non trovato nel widget tree.');
    return scope!.notifier!;
  }
}
