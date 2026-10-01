import 'package:flutter/foundation.dart';

import '../repositories/leaderboard_repository.dart';
import '../repositories/user_profile_repository.dart';

/// Salva lo username su Firestore (`users/{uid}.username`, unica fonte del
/// nome) e allinea la copia mostrata in classifica.
class UsernameService {
  UsernameService({
    UserProfileRepository? userProfileRepository,
    LeaderboardRepository? leaderboardRepository,
  }) : _userProfileRepository =
           userProfileRepository ?? UserProfileRepository(),
       _leaderboardRepository = leaderboardRepository;

  final UserProfileRepository _userProfileRepository;
  // Creato al primo uso: FirestoreLeaderboardRepository legge
  // FirebaseFirestore.instance già nel costruttore.
  LeaderboardRepository? _leaderboardRepository;

  Future<void> save({required String uid, required String username}) async {
    await _userProfileRepository.setUsername(uid, username);
    try {
      await (_leaderboardRepository ??= FirestoreLeaderboardRepository())
          .updateUsername(uid: uid, username: username);
    } catch (e) {
      // Il nome in classifica si riallinea comunque al prossimo punto.
      debugPrint('Aggiornamento username in classifica non riuscito: $e');
    }
  }
}
