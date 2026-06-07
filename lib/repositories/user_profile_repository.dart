import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user_profile.dart';

class UserProfileRepository {
  UserProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> ensureProfile(AppUserProfile profile) {
    return _firestore.collection('users').doc(profile.uid).set({
      'email': profile.email,
      'displayName': profile.displayName,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
