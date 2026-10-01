import 'package:cloud_firestore/cloud_firestore.dart';

/// Profilo pubblico di un utente: `users/{uid}` su Firestore e la copia
/// incorporata nei documenti `reports` (evento, partecipanti, chi pulisce).
///
/// Contiene solo dati che chiunque può vedere: l'email resta in Firebase
/// Auth e non viene mai scritta su Firestore.
class AppUserProfile {
  const AppUserProfile({required this.uid, this.username});

  final String uid;
  final String? username;

  /// Nome da mostrare agli altri utenti.
  String get label {
    final name = username?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return 'Utente';
  }

  Map<String, dynamic> toMap() {
    return {'uid': uid, 'username': username};
  }

  factory AppUserProfile.fromMap(Map<String, dynamic> data) {
    return AppUserProfile(
      uid: data['uid'] as String? ?? '',
      username: _usernameFrom(data),
    );
  }

  factory AppUserProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    return AppUserProfile(uid: doc.id, username: _usernameFrom(data));
  }

  /// `displayName` è il nome del campo prima della migrazione a `username`
  /// (tool/migrate_username.js): letto finché ci sono dati non migrati.
  static String? _usernameFrom(Map<String, dynamic> data) {
    final value = data['username'] ?? data['displayName'];
    return value is String ? value : null;
  }
}
