import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user_profile.dart';

class UserProfileRepository {
  UserProfileRepository({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  // Risolto al primo uso: AppSession crea il repository anche quando
  // Firebase non è inizializzato (firebaseReady == false).
  final FirebaseFirestore? _firestoreOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  Future<void> deleteProfile(String uid) {
    return _firestore.collection('users').doc(uid).delete();
  }

  Future<AppUserProfile?> fetchProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUserProfile.fromDoc(doc);
  }

  /// Upsert chiamato a ogni login e alla registrazione: non deve cancellare
  /// dati già salvati. Lo username si scrive solo se noto (un `null` in merge
  /// cancellerebbe quello esistente), `createdAt` solo alla prima creazione.
  ///
  /// `users/{uid}` è leggibile dagli altri utenti (nome in segnalazioni e
  /// classifica), quindi non contiene mai l'email: quella resta in
  /// Firebase Auth.
  Future<void> ensureProfile(String uid, {String? username}) async {
    final ref = _firestore.collection('users').doc(uid);
    final snap = await ref.get();
    final name = username?.trim();
    return ref.set({
      if (name != null && name.isNotEmpty) 'username': name,
      'updatedAt': FieldValue.serverTimestamp(),
      if (!snap.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setUsername(String uid, String username) {
    return _firestore.collection('users').doc(uid).set({
      'username': username,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Legge il flag di onboarding: assente = account preesistente alla
  /// feature, quindi trattato come già onboardato (non forziamo utenti
  /// esistenti nel flusso). Volutamente non è un campo di [AppUserProfile]:
  /// [ensureProfile] fa un upsert cieco ad ogni login, e se il flag fosse
  /// nella mappa verrebbe resettato a ogni accesso.
  Future<bool> hasCompletedOnboarding(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return (doc.data()?['onboardingComplete'] as bool?) ?? true;
  }

  Future<void> setOnboardingComplete(String uid, bool value) {
    return _firestore.collection('users').doc(uid).set({
      'onboardingComplete': value,
    }, SetOptions(merge: true));
  }
}
