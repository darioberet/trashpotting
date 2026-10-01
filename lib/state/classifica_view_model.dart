import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../models/leaderboard_entry.dart';
import '../repositories/leaderboard_repository.dart';
import '../repositories/report_repository.dart';
import 'notifier_message_mixin.dart';

class ClassificaViewModel extends ChangeNotifier with NotifierMessageMixin {
  ClassificaViewModel({
    required LeaderboardRepository repository,
    ReportRepository? reportRepository,
  }) : _repository = repository,
       _reportRepository = reportRepository ?? FirestoreReportRepository();

  final LeaderboardRepository _repository;
  final ReportRepository _reportRepository;

  List<LeaderboardEntry> _entries = const [];
  Map<String, int> _reportCounts = const {};
  bool _loading = false;
  bool _loaded = false;

  @override
  String get lastErrorFallback =>
      'Classifica non disponibile. Riprova più tardi.';

  List<LeaderboardEntry> get entries => _entries;
  bool get loading => _loading;
  bool get loaded => _loaded;

  /// Numero di segnalazioni dell'utente [uid], o null se non ancora caricato.
  int? reportCountFor(String uid) => _reportCounts[uid];

  Future<void> load() async {
    _loading = true;
    notifyListeners();

    try {
      _entries = await _repository.fetchTop();
      _loaded = true;
      notifyListeners();
      await _loadReportCounts();
    } catch (e) {
      setError(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _loadReportCounts() async {
    try {
      final counts = await Future.wait(
        _entries.map(
          (e) async =>
              MapEntry(e.uid, await _reportRepository.countByUser(e.uid)),
        ),
      );
      _reportCounts = Map.fromEntries(counts);
      notifyListeners();
    } catch (_) {
      // Il conteggio segnalazioni è un dettaglio secondario: se fallisce,
      // la classifica resta comunque utilizzabile senza quel dato.
    }
  }
}
