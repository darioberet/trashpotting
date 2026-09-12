import 'package:flutter/foundation.dart';

import '../models/leaderboard_entry.dart';
import '../repositories/leaderboard_repository.dart';
import 'notifier_message_mixin.dart';

class ClassificaViewModel extends ChangeNotifier with NotifierMessageMixin {
  ClassificaViewModel({required LeaderboardRepository repository})
      : _repository = repository;

  final LeaderboardRepository _repository;

  List<LeaderboardEntry> _entries = const [];
  bool _loading = false;
  bool _loaded = false;

  @override
  String get lastErrorFallback => 'Classifica non disponibile. Riprova più tardi.';

  List<LeaderboardEntry> get entries => _entries;
  bool get loading => _loading;
  bool get loaded => _loaded;

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    try {
      _entries = await _repository.fetchTop();
      _loaded = true;
    } catch (e) {
      setError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
