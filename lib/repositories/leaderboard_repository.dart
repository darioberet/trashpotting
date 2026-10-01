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
    required String displayName,
    int amount = pointsPerReport,
  });
  Future<int> fetchUserPoints(String uid);

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
    required String displayName,
    int amount = pointsPerReport,
  }) {
    return _firestore.collection('leaderboard').doc(uid).set({
      'name': displayName,
      'points': FieldValue.increment(amount),
    }, SetOptions(merge: true));
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
          name: snap.docs[i].data()['name'] as String? ?? 'Sconosciuto',
          points: snap.docs[i].data()['points'] as int? ?? 0,
        ),
    ];
  }
}
