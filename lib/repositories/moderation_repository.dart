import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import '../models/trashpot_report.dart';

/// Motivi proposti quando un utente segnala un contenuto.
const flagReasons = [
  'Foto o testo inappropriati',
  'Spam o segnalazione falsa',
  'Dati personali visibili',
  'Altro',
];

/// Contenuto segnalato da un utente (`flags/{reportId}_{uid}`).
class ContentFlag {
  const ContentFlag({
    required this.id,
    required this.reportId,
    required this.reporterUid,
    required this.reason,
    this.reportAuthorUid,
    this.createdAt,
  });

  final String id;
  final String reportId;
  final String reporterUid;
  final String? reportAuthorUid;
  final String reason;
  final DateTime? createdAt;

  factory ContentFlag.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final created = data['createdAt'];
    return ContentFlag(
      id: doc.id,
      reportId: data['reportId'] as String? ?? '',
      reporterUid: data['reporterUid'] as String? ?? '',
      reportAuthorUid: data['reportAuthorUid'] as String?,
      reason: data['reason'] as String? ?? '',
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

class BlockedUser {
  const BlockedUser({required this.uid, this.username, this.blockedAt});

  final String uid;
  final String? username;
  final DateTime? blockedAt;
}

/// Azioni di moderazione. Le operazioni "admin" sono consentite dalle regole
/// Firestore/Storage solo a chi ha la custom claim `admin`.
class ModerationRepository {
  ModerationRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _firestoreOverride = firestore,
      _storageOverride = storage;

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseStorage? _storageOverride;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  // ── Utenti ────────────────────────────────────────────────────────────────

  String _flagId(String reportId, String uid) => '${reportId}_$uid';

  Future<bool> hasFlagged({
    required String reportId,
    required String uid,
  }) async {
    final doc = await _firestore
        .collection('flags')
        .doc(_flagId(reportId, uid))
        .get();
    return doc.exists;
  }

  Future<void> flagReport({
    required TrashpotReport report,
    required String reporterUid,
    required String reason,
  }) {
    return _firestore
        .collection('flags')
        .doc(_flagId(report.id, reporterUid))
        .set({
          'reportId': report.id,
          'reporterUid': reporterUid,
          'reportAuthorUid': report.reporterUid,
          'reason': reason,
          'status': 'open',
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  // ── Admin ─────────────────────────────────────────────────────────────────

  Stream<List<ContentFlag>> watchOpenFlags() {
    return _firestore
        .collection('flags')
        .where('status', isEqualTo: 'open')
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs.map(ContentFlag.fromDoc).toList());
  }

  /// Archivia il report in `removedReports` (traccia di cosa è stato tolto,
  /// da chi e perché), lo elimina, chiude le relative segnalazioni e cancella
  /// le foto da Storage.
  Future<void> removeReport({
    required String reportId,
    required String adminUid,
    String? reason,
  }) async {
    final ref = _firestore.collection('reports').doc(reportId);
    final snap = await ref.get();
    if (!snap.exists) return;
    final data = snap.data() ?? const <String, dynamic>{};

    final batch = _firestore.batch()
      ..set(_firestore.collection('removedReports').doc(reportId), {
        ...data,
        'removedBy': adminUid,
        'removedAt': FieldValue.serverTimestamp(),
        'removalReason': ?reason,
      })
      ..delete(ref);
    await _resolveFlags(reportId, status: 'removed', batch: batch);
    await batch.commit();

    for (final key in ['photoUrl', 'cleanupPhotoUrl']) {
      final url = data[key];
      if (url is! String || url.isEmpty) continue;
      try {
        await _storage.refFromURL(url).delete();
      } catch (e) {
        // La foto può essere già stata rimossa: il report è comunque tolto.
        debugPrint('Eliminazione foto $key non riuscita: $e');
      }
    }
  }

  /// Chiude le segnalazioni di un report ritenuto a posto.
  Future<void> dismissFlags(String reportId) async {
    final batch = _firestore.batch();
    await _resolveFlags(reportId, status: 'dismissed', batch: batch);
    await batch.commit();
  }

  Future<void> _resolveFlags(
    String reportId, {
    required String status,
    required WriteBatch batch,
  }) async {
    final flags = await _firestore
        .collection('flags')
        .where('reportId', isEqualTo: reportId)
        .where('status', isEqualTo: 'open')
        .get();
    for (final doc in flags.docs) {
      batch.update(doc.reference, {'status': status});
    }
  }

  Future<void> setBlocked({
    required String uid,
    required bool blocked,
    required String adminUid,
  }) {
    return _firestore.collection('users').doc(uid).update({
      'blocked': blocked,
      'blockedAt': blocked ? FieldValue.serverTimestamp() : null,
      'blockedBy': blocked ? adminUid : null,
    });
  }

  Stream<List<BlockedUser>> watchBlockedUsers() {
    return _firestore
        .collection('users')
        .where('blocked', isEqualTo: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final data = doc.data();
            final at = data['blockedAt'];
            return BlockedUser(
              uid: doc.id,
              username: data['username'] as String?,
              blockedAt: at is Timestamp ? at.toDate() : null,
            );
          }).toList(),
        );
  }
}
