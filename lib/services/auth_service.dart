import 'package:firebase_auth/firebase_auth.dart';

import 'push_service.dart';

class AuthService {
  AuthService({FirebaseAuth? auth}) : _authOverride = auth;

  // Risolto al primo uso: la schermata di login viene costruita anche
  // quando Firebase non è inizializzato.
  final FirebaseAuth? _authOverride;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  Future<UserCredential> signInAnonymously() {
    return _auth.signInAnonymously();
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Prima del logout il dispositivo smette di ricevere le notifiche di
  /// questo account (dopo il logout le regole non lo permetterebbero più).
  Future<void> signOut() async {
    await PushService.instance.unregister();
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  Future<void> reloadCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.reload();
    // Le regole Firestore leggono `email_verified` dal token: senza
    // rinnovarlo, subito dopo la verifica le scritture verrebbero rifiutate
    // fino alla scadenza del token (1 ora).
    if (user.emailVerified) await user.getIdToken(true);
  }

  /// Custom claim `admin` (impostata con tool/set_admin.js). Rinnova il
  /// token per vedere subito una claim appena aggiunta o rimossa.
  Future<bool> currentUserIsAdmin({bool forceRefresh = false}) async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final result = await user.getIdTokenResult(forceRefresh);
    return result.claims?['admin'] == true;
  }

  bool get currentUserEmailVerified =>
      _auth.currentUser?.emailVerified ?? false;

  Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
  }

  /// Firebase richiede un login recente per operazioni sensibili come
  /// l'eliminazione dell'account (`requires-recent-login`).
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('Utente non autenticato.');
    }
    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: email, password: password),
    );
  }

  /// Sincronizza nome/foto su Firebase Auth (oggi scritti solo su Firestore
  /// in fase di registrazione) — usato dall'onboarding per allineare le due
  /// fonti, così `profilo_screen.dart` (che legge da `User.photoURL`) le vede.
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (displayName != null) await user.updateDisplayName(displayName);
    if (photoURL != null) await user.updatePhotoURL(photoURL);
    await user.reload();
  }
}
