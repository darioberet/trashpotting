import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user_profile.dart';

class UserProfileRepository {
  UserProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> deleteProfile(String uid) {
    return _firestore.collection('users').doc(uid).delete();
  }

  Future<AppUserProfile?> fetchProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUserProfile.fromDoc(doc);
  }

  Future<void> ensureProfile(AppUserProfile profile) {
    return _firestore.collection('users').doc(profile.uid).set({
      'email': profile.email,
      'displayName': profile.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
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
