import 'package:flutter/foundation.dart';

import '../models/leaderboard_entry.dart';
import '../repositories/leaderboard_repository.dart';
import 'notifier_message_mixin.dart';

class ClassificaViewModel extends ChangeNotifier with NotifierMessageMixin {
  ClassificaViewModel({required LeaderboardRepository repository})
      : _repository = repository;

  final LeaderboardRepository _repository;

  static const fallbackEntries = <LeaderboardEntry>[
    LeaderboardEntry(rank: 1, name: 'Tu (placeholder)', points: 120),
    LeaderboardEntry(rank: 2, name: 'EcoTeam Nord', points: 98),
    LeaderboardEntry(rank: 3, name: 'Raccolta_2026', points: 76),
    LeaderboardEntry(rank: 4, name: 'VerdeStrada', points: 54),
    LeaderboardEntry(rank: 5, name: 'PuliamoIlParco', points: 41),
  ];

  List<LeaderboardEntry> _entries = fallbackEntries;
  bool _loading = false;

  @override
  String get lastErrorFallback =>
      'Classifica non disponibile: mostro dati di esempio.';

  List<LeaderboardEntry> get entries => _entries;
  bool get loading => _loading;

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    try {
      final result = await _repository.fetchTop();
      _entries = result.isNotEmpty ? result : fallbackEntries;
    } catch (e) {
      _entries = fallbackEntries;
      setError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
