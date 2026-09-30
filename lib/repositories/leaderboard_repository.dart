import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/leaderboard_entry.dart';

abstract class LeaderboardRepository {
  Future<List<LeaderboardEntry>> fetchTop({int limit = 20});
  Future<void> incrementPoints({
    required String uid,
    required String displayName,
  });
  Future<int> fetchUserPoints(String uid);
}

class FirestoreLeaderboardRepository implements LeaderboardRepository {
  FirestoreLeaderboardRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<void> incrementPoints({
    required String uid,
    required String displayName,
  }) {
    return _firestore.collection('leaderboard').doc(uid).set({
      'name': displayName,
      'points': FieldValue.increment(1),
    }, SetOptions(merge: true));
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
