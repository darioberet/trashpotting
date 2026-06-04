import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/leaderboard_entry.dart';

abstract class LeaderboardRepository {
  Future<List<LeaderboardEntry>> fetchTop({int limit = 20});
}

class FirestoreLeaderboardRepository implements LeaderboardRepository {
  FirestoreLeaderboardRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
          name: snap.docs[i].data()['name'] as String? ?? 'Sconosciuto',
          points: snap.docs[i].data()['points'] as int? ?? 0,
        ),
    ];
  }
}
