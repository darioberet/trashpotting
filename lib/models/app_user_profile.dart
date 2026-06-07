import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppUserProfile {
  const AppUserProfile({
    required this.uid,
    required this.email,
    this.displayName,
  });

  final String uid;
  final String email;
  final String? displayName;

  String get label {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return email;
  }

  Map<String, dynamic> toMap() {
    return {'uid': uid, 'email': email, 'displayName': displayName};
  }

  factory AppUserProfile.fromMap(Map<String, dynamic> data) {
    return AppUserProfile(
      uid: data['uid'] as String? ?? '',
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String?,
    );
  }

  factory AppUserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppUserProfile(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String?,
    );
  }

  factory AppUserProfile.fromAuthUser(User user, {String? displayName}) {
    return AppUserProfile(
      uid: user.uid,
      email: user.email ?? '',
      displayName: displayName ?? user.displayName,
    );
  }
}
