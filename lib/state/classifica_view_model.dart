import 'package:flutter/foundation.dart';

import '../models/leaderboard_entry.dart';
import '../repositories/leaderboard_repository.dart';

class ClassificaViewModel extends ChangeNotifier {
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

  int _errorToken = 0;
  Object? _lastError;
  final String _lastErrorFallback =
      'Classifica non disponibile: mostro dati di esempio.';

  List<LeaderboardEntry> get entries => _entries;
  bool get loading => _loading;

  int get errorToken => _errorToken;
  Object? get lastError => _lastError;
  String get lastErrorFallback => _lastErrorFallback;

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    try {
      final result = await _repository.fetchTop();
      _entries = result.isNotEmpty ? result : fallbackEntries;
    } catch (e) {
      _entries = fallbackEntries;
      _lastError = e;
      _errorToken += 1;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
