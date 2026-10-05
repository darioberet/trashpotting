import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/leaderboard_entry.dart';

/// Punti assegnati in classifica: una pulizia completata vale più di una
/// segnalazione perché richiede più impegno.
const pointsPerReport = 1;
const pointsPerCleanup = 2;

abstract class LeaderboardRepository {
  Future<List<LeaderboardEntry>> fetchTop({int limit = 20});
  Future<void> incrementPoints({
    required String uid,
    required String username,
    int amount = pointsPerReport,
  });
  Future<int> fetchUserPoints(String uid);

  /// Posizione in classifica di chi ha [points] punti: 1 + quanti ne hanno
  /// di più (a pari punti si condivide la posizione).
  Future<int> fetchRankForPoints(int points);

  /// Allinea il nome mostrato in classifica quando l'utente cambia
  /// username (registrazione, onboarding).
  Future<void> updateUsername({required String uid, required String username});

  /// Rimuove l'utente dalla classifica (eliminazione account).
  Future<void> deleteEntry(String uid);
}

class FirestoreLeaderboardRepository implements LeaderboardRepository {
  FirestoreLeaderboardRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<void> incrementPoints({
    required String uid,
    required String username,
    int amount = pointsPerReport,
  }) {
    return _firestore.collection('leaderboard').doc(uid).set({
      'username': username,
      'points': FieldValue.increment(amount),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> updateUsername({
    required String uid,
    required String username,
  }) async {
    final ref = _firestore.collection('leaderboard').doc(uid);
    // Solo se l'utente è già in classifica: un documento senza punti
    // non serve e verrebbe creato vuoto.
    if (!(await ref.get()).exists) return;
    await ref.update({'username': username});
  }

  @override
  Future<void> deleteEntry(String uid) {
    return _firestore.collection('leaderboard').doc(uid).delete();
  }

  @override
  Future<int> fetchUserPoints(String uid) async {
    final doc = await _firestore.collection('leaderboard').doc(uid).get();
    return doc.data()?['points'] as int? ?? 0;
  }

  @override
  Future<int> fetchRankForPoints(int points) async {
    // Query di conteggio: costa una lettura ogni 1000 documenti contati.
    final snap = await _firestore
        .collection('leaderboard')
        .where('points', isGreaterThan: points)
        .count()
        .get();
    return (snap.count ?? 0) + 1;
  }

  /// Punti dell'utente aggiornati in tempo reale (pillola nell'header).
  Stream<int> watchUserPoints(String uid) {
    return _firestore
        .collection('leaderboard')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data()?['points'] as int? ?? 0);
  }

  @override
  Future<List<LeaderboardEntry>> fetchTop({int limit = 20}) async {
    final snap = await _firestore
        .collection('leaderboard')
        .orderBy('points', descending: true)
        .limit(limit)
        .get();

    return [
      for (var i = 0; i < snap.docs.length; i++)
        LeaderboardEntry(
          rank: i + 1,
          uid: snap.docs[i].id,
          name: snap.docs[i].data()['username'] as String? ?? 'Utente',
          points: snap.docs[i].data()['points'] as int? ?? 0,
        ),
    ];
  }
}
